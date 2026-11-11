# Buckshot Roulette NX — notes

Bring-your-own-copy port: a Switch build of Godot 4.1.1 runs the original game pack.
No game files are committed (`extracted/`, `pck/`, `third_party/` stay local).

## Facts (2026-11-09)
- Game: Godot **4.1.1** (custom build), v2.2.0.6. PCK v2 is embedded in `Buckshot Roulette.exe`
  (starts at 57826816, size 738498644), **not encrypted**, 3572 files.
- Scripts: **195 plain-text `.gd`**, no GDExtension or native libs. Renderer set to **Forward Plus**.
- Only engine change found: **GodotSteam** compiled in. It's used through the `Steam` singleton
  (wrapped by autoload `GlobalSteam` = `res://scripts/Steam.gd`).

## Steps done
1. `tools/pck_extract.py <exe> extracted --raw-pck pck/BuckshotRoulette.pck`
2. `patch/steam_stub/SteamStub.gd`: GDScript stand-in for GodotSteam, offline, with all
   signals/constants/methods the game uses. Registered through `override.cfg`:
   ```
   [autoload]
   Steam="*res://nx/SteamStub.gd"
   ```
3. **Stock official Godot 4.1.1 runs the game to the main menu with no script errors**,
   on both Forward+ (Vulkan) and `--rendering-method gl_compatibility` (OpenGL 3.3).
   So the custom engine only matters for Steam.

## Switch plan
- Add `platform/switch` to Godot 4.1.1 (devkitPro/libnx): EGL window through mesa (`libEGL`,
  `libGLESv2`, `libdrm_nouveau` are installed in portlibs), HID gamepad and touch → InputEventJoypad,
  audout/audren audio driver, threads/semaphores, file access on `sdmc:`. Start with the
  **gl_compatibility** renderer; try Vulkan through `nxvk` later.
- Godot 3.x community Switch ports can serve as a reference for the OS/display layer.
- Data on the SD card: `BuckshotRoulette.pck` + a patch pck containing `nx/SteamStub.gd`, plus
  `override.cfg` (autoload + `rendering/renderer/rendering_method="gl_compatibility"`).
- Disable the multiplayer menu entry, or make it show a "not available" message.

## Switch build (2026-11-09)
- Godot 4.1.1 source in `godot/` (tag 4.1.1-stable) + `platform/switch/` (detect.py, OS, DisplayServer
  with EGL/GLES3 + HID pad/touch, audout audio driver, compat headers, POSIX stubs). Engine patches:
  SConstruct (GNU tools for p=switch), drivers/unix (rlimit, arpa/inet, IPv6 multicast), and a debug
  `[nx]` printf in core/register_core_types.cpp.
- Build: `cd godot; py -3 -m SCons platform=switch target=template_release -j12` (Windows Python + scons).
- Data: `python tools/make_switch_pck.py "<Steam>/Buckshot Roulette.exe" out/buckshot_roulette.pck`.
- SD: `sdmc:/switch/buckshot_roulette/{buckshot_roulette.nro, buckshot_roulette.pck}`; log goes to
  `godot_log.txt` there (or nxlink). Run in full-RAM (title takeover) mode on hardware.
- Eden: `bash tools/run_eden.sh [seconds]`. **Reaches the main menu at 60 fps (OpenGL ES 3.2 Mesa).**
- Not tested on hardware yet (consoles offline). Next: menu text visibility, a virtual mouse cursor
  (the game is mouse-driven; only touch→mouse emulation exists now), docked resolution, perf.

## Renderer decision (2026-11-10): OpenGL
- Builds are exclusive (two Mesa copies clash): default `opengl3=yes` (Compatibility, Mesa GL); `vulkan=yes opengl3=no`
  builds the nxvk/Mobile variant (needs `sdmc:/switch/buckshot_roulette/override.cfg` with `rendering_method="mobile"`).
- OLED, max OC, same spot at the table: **GL 35-45 fps and matches the PC reference**; nxvk/Mobile ~19 fps, wrong image
  (pink blotches, extra mat text/objects lit). Menu: GL 60, nxvk 42. GL docked clocks: 21-29 fps. GPU-bound (fps tracks GPU clock).
- nxvk findings: **Environment fog hangs nxvk** (main scene pass never completes; repro: `tools/make_nxvk_test.py` stage 5).
  Texture uploads, memory layout (VMA dedicated), coherent/flush/cpu_wait/no_zcull flags ruled out.
  Engine debug hooks kept (off unless files exist on SD): `nvk_debug.txt` (NVK_DEBUG), `nx_sync_uploads`, `nx_sync_passes`.
- lsfg (frame gen, as pt-pc) needs Vulkan: later options are Zink over nxvk, or native GL + nxvk only for lsfg/present.
  Only worth it once GL holds a steady 30.
- Profiling: `nx_debug.txt` = `prof` cycles base/halfres/noretro/noshadow/nolight/unshaded/halfmesh at the table (8 s each,
  vsync off) and logs `[nx prof]` lines. `profany` runs it in any scene. Eden caps at 60, so profile on hardware.

## OpenGL tuning and port UI (2026-11-10)
- **3D render scale** added to the GLES3 renderer (4.1 ignored `rendering/scaling_3d/*`): drivers/gles3 RenderSceneBuffersGLES3
  renders the 3D scene into a smaller FBO and blits it up to the render target before 2D/UI is drawn (UI stays 960x540).
- **30 fps lock**: `[nx] swap_interval=2` (eglSwapInterval), set at runtime by the menu.
- Measured, same view, uncapped (ms): scale 1.0/0.9/0.8/0.7 = max OC 26.4/22.5/18.7/15.4, docked 41.5/35.2/29.2/23.9.
  Default: 0.7 + 30 lock (docked: steady 30, GPU ~72%).
- **Minus menu** (patch/nx/NxMenu.gd, "BUCKSHOT ROULETTE NX", L/R tabs): GRAPHICS (lock, dynamic resolution, scale slider,
  fps overlay), SOUND (volume per audio bus), CHEATS (shell reveal, item spawn/fill, health, next/all shells, game speed,
  double damage, cuff dealer). Settings in sdmc:/switch/buckshot_roulette/nx_settings.cfg. Minus = JoyButton BACK (unused by the game).
- **Patch pack**: the engine loads sdmc:/switch/buckshot_roulette/nx_patch.pck after the main pack (replace files), so the port
  scripts can be updated with `python tools/make_nx_patch.py` (~25 KB) instead of the 738 MB pack. Autoload list/override.cfg
  still come from the main pack.
- **Per-object fade** (`GeometryInstance3D.transparency`) is ignored by 4.1 GLES3: blood splatter plane and the "DEALER"/"YOU"
  shot texts never faded. patch/nx/NxCompat.gd maps it to Label3D modulate alpha / StandardMaterial3D albedo alpha.
  GPU particles DO work in 4.1 GLES3 (smoke); the blood is a camera plane, not particles.
- Text server switched to `text_server_adv` (HarfBuzz) after "YOU" rendered as "OU Y" (may have been the unfaded shot text).
- Script check without a console: `Godot_v4.1.1-stable_win64_console.exe --headless --main-pack out/buckshot_roulette.pck
  --check-only --script res://nx/NxMenu.gd` (pack must contain the script; the "Steam not declared" errors are PC-only noise).

## Release renderer: GL on Zink + LSFG frame generation (2026-11-11)
- Default build `zink=yes lsfg=yes`: Godot GL (Compatibility) on nxvk's Zink (Mesa 26.2, GLES 3.2 over NVK), statically
  linked from the nxvk GL package (`make gl`; default location `../nxvk-pkg-gl`, or set `NXVK_GL_PKG`).
  `zink=no` still builds the devkitPro Mesa 20.1 nouveau variant (no frame generation).
- `platform/switch/nx_zink_hook.cpp`: Zink's two Vulkan entry symbols are renamed to `nx_hook_*` with objcopy
  (`libnvk_gl_hooked.a`, see `nxvk/wsi_swapchain_images.sh`), so the hook sees the device, queue, swapchain and presents.
  - No frame generation: FIFO + a sleep before present for the 30 lock (`nx_zink_swap_interval`, from `[nx] swap_interval`).
  - Frame generation: lsfg-vk runs on Zink's own device. Each present copies Zink's image into lsfg's source (1:1 copy at
    720p), records lsfg, writes the generated frame into Zink's image and presents it, then acquires the next image,
    copies the real frame in and presents that. nxvk allows only ONE checked-out swapchain image, which is why the
    generated frame goes into Zink's image first. nxvk WSI changed to 3..5 images.
  - On by default; the menu creates `nx_lsfg_off` to disable. Needs `Lossless.dll` in `sdmc:/switch/buckshot_roulette/`,
    `sdmc:/switch/pt/lsfg/` or the SD root.
- Measured, OLED handheld 720p, docked clocks (GPU 768): table locked 30 with ~98% of generated frames shown, GPU ~70%;
  walkway ~16.5 fps (19 omni lights: Zink/NAK's per-pixel light loop is slow; no-specular +13%, ZINK_DESCRIPTORS=lazy
  no change, an 8-light cap visibly darkens the walls). At max OC the walkway is ~26.
- **NVK diagonal seam**: implicit-LOD `texture()` derivatives are wrong along the shared diagonal of a quad's two
  triangles, giving a dotted line top-left to bottom-right (also seen in the P.T. port). The retro screen shaders read
  SCREEN_TEXTURE with mipmap filtering; `servers/rendering/shader_compiler.cpp` rewrites those reads to `textureLod(.., 0)`
  on Horizon. Ruled out first: the scaled blits, the screen stretch, the canvas vertex array.
- **Multiplayer** is hidden by NxCompat.gd: offline the game only shows "no connection" (after clearing the save), and
  loading `mp_lobby.tscn` crashes on Switch (not investigated).
- Dead ends, removed from the tree: nouveau GL + readback into a private nxvk for LSFG (Mesa 20.1 readback always waits for
  the frame; its EGL has no image/fence-sync extensions and share groups don't share objects); the Vulkan-driver debug
  hooks (fog hang hunt). The `vulkan=yes` (Mobile renderer) path is still in detect.py but unmaintained.

## Release packaging
- `tools/package_release.ps1` builds `dist/BuckshotRouletteNX-<ver>.zip`: `switch/buckshot_roulette/buckshot_roulette.nro`,
  `build_pack.bat` + `pc/` (pack builder and the port scripts), README, LICENSES. Users build the game pack themselves.
- Engine changes live on branch `switch-port` of `godot/` (on top of tag 4.1.1-stable), exported to
  `engine/godot-4.1.1-switch.patch`. Re-export after engine changes:
  `git -C godot diff 4.1.1-stable switch-port --binary > engine/godot-4.1.1-switch.patch`.
