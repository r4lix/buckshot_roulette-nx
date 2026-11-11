# buckshot_roulette-nx: advanced notes

## How it works

The game is a Godot 4.1.1 project with plain-text GDScript and no native plugins except GodotSteam. So the port is a
Switch build of Godot 4.1.1 that runs the game's own pack:

- `engine/godot-4.1.1-switch.patch` adds `platform/switch` to Godot 4.1.1-stable (libnx OS layer, display server with
  EGL, Joy-Con/touch input and a virtual mouse, audout audio) plus a few renderer changes.
- Rendering uses Godot's **Compatibility (OpenGL)** renderer on **Zink** from [nxvk](https://github.com/PalindromicBreadLoaf/nxvk)
  (OpenGL ES 3.2 over Mesa's NVK Vulkan driver), linked statically.
- **Frame generation:** `platform/switch/nx_zink_hook.cpp` sits between Zink and NVK. On each present it runs
  [lsfg-vk](https://github.com/PancakeTAS/lsfg-vk) on Zink's own frame (no readback) and shows a generated frame between
  each pair of real frames. Its shaders are read from your own `Lossless.dll`.
- The 3D scene renders at a lower scale (default 0.7) and is upscaled with a CAS sharpening pass; the UI stays sharp.
- `tools/make_switch_pck.py` (run by `build_pack.bat`) copies the game pack out of `Buckshot Roulette.exe` and adds:
  - `nx/SteamStub.gd`: an offline stand-in for the `Steam` singleton;
  - `nx/NxMenu.gd`: the Minus menu;
  - `nx/NxCursor.gd`: draws the game's cursor;
  - `nx/NxCompat.gd`: renderer workarounds (per-object fade, dark lights, hidden multiplayer entry);
  - `nx/NxDebug.gd`: debug switches and a profiler, off unless `nx_debug.txt` exists;
  - an `override.cfg` that registers these and selects the Compatibility renderer.

## SD layout

```
sdmc:/switch/buckshot_roulette/
  buckshot_roulette.nro
  buckshot_roulette.pck   built from your Steam copy
  Lossless.dll            optional (also found in sdmc:/switch/pt/lsfg/ or the SD root)
  nx_settings.cfg         Minus menu settings
  nx_patch.pck            optional: newer port scripts, loaded over the main pack
  nx_lsfg_off             created by the menu when frame generation is off
  userdata/               the game's saves
  godot_log.txt           last run's log
```

## Minus menu

L / R switch tabs, D-pad moves, A selects.

- **GRAPHICS**:
  - 30 fps lock
  - 3D render scale (default 0.7)
  - dynamic resolution (off by default: raising the scale costs the generated frames)
  - sharpening
  - fps overlay
  - frame generation (applied after a restart)
- **SOUND**: volume per audio bus.
- **CHEATS**:
  - show the shells
  - spawn an item or fill your side
  - restore health, put the dealer down to 1
  - set the next shell, or make every shell live
  - game speed, double damage, handcuff the dealer

## Performance

Tested on a Switch OLED in handheld mode (720p) at docked clocks (GPU 768 MHz):

- **Main menu and the table:** steady 30 fps, plus the generated frames (60 on screen).
- **Corridor into the club:** drops to about 17 fps for a few seconds. It has about 20 lights, and Zink's per-pixel
  light loop on NVK is slow.
- **First appearances:** some effects hitch briefly the first time, while their shaders compile.
- **TV:** docked play on a TV (1080p) is not tested much. Frame generation there runs at 960x540.

## Building

You need:

- devkitPro (devkitA64, libnx) and Python 3 with SCons.
- Godot 4.1.1-stable in `godot/`, with the engine patch applied:
  `git -C godot apply ../engine/godot-4.1.1-switch.patch`.
- The nxvk GL package (`make gl` in nxvk), with the swapchain change from `nxvk/wsi_swapchain_images.sh`. Then the
  objcopy step described there, which makes `lib/libnvk_gl_hooked.a`. Put the package next to this repo as
  `nxvk-pkg-gl/`, or set `NXVK_GL_PKG`.
- lsfg-vk sources in `third_party/lsfg-vk`, and libexpat for the Switch in `third_party/nxvk`.

Then:

```
cd godot
py -3 -m SCons platform=switch target=template_release      # zink=yes lsfg=yes by default
powershell -File ../tools/package_release.ps1 -Version 1.0.0  # dist/BuckshotRouletteNX-1.0.0.zip
```

`zink=no` builds on devkitPro's Mesa nouveau GL instead, with no frame generation.

`tools/make_nx_patch.py` builds `nx_patch.pck` from `patch/nx`. Copy it next to the NRO to test script changes
without rebuilding the 740 MB pack.

Port history, measurements and dead ends: [NOTES.md](../NOTES.md).

## Licenses

- The port code is GPL-3.0-or-later, because the build links lsfg-vk.
- Godot is MIT. Mesa / nxvk are MIT, with some GPL-2.0-or-later parts. See [LICENSES](../LICENSES).
- Buckshot Roulette is © Mike Klubnika. This port is not affiliated with him.
