# Buckshot Roulette NX

A Nintendo Switch homebrew port of **Buckshot Roulette** (Mike Klubnika). It runs the game from **your own Steam copy**:
no game files are included or distributed. A Switch build of Godot 4.1.1 runs the original game pack, with a few
port scripts on top (menu, cursor, renderer workarounds).

## What you need
- A Switch running custom firmware (Atmosphère) and the homebrew menu.
- Buckshot Roulette on Steam (Windows version 2.2.x), installed on a PC.
- Python 3 on that PC, to build the game pack (https://www.python.org/downloads/).
- Optional, for frame generation: `Lossless.dll` from your own copy of **Lossless Scaling** (Steam).

## Install
1. Unzip the release on your PC.
2. Run `build_pack.bat`. It finds the game in the default Steam folder. If yours is elsewhere, drag
   `Buckshot Roulette.exe` onto `build_pack.bat`. It writes `switch/buckshot_roulette/buckshot_roulette.pck` (~740 MB).
3. Copy the `switch` folder to the root of your SD card.
4. Optional: copy `Lossless.dll` (in Lossless Scaling's Steam folder) to `sdmc:/switch/buckshot_roulette/`
   (or to the SD card root).
5. Start it from the homebrew menu **in title mode**: hold **R** while starting any game, then pick
   *Buckshot Roulette NX*. Applet mode (the Album) does not have enough memory.

## Controls
| | |
|---|---|
| Right stick | move the cursor |
| ZR / ZL | left / right click |
| Touch screen | tap = click |
| A / B, D-pad, left stick | the game's own controller controls |
| **Minus** | port menu (L / R switch tabs) |

## Port menu (Minus)
- **GRAPHICS**: 30 fps lock, 3D render scale (default 0.7), dynamic resolution (off by default; it trades the
  generated frames for resolution), sharpening, fps overlay, frame generation (on/off, takes effect after a restart).
- **SOUND**: volume per audio bus.
- **CHEATS**: show the shells, spawn items, restore health, set the next shell, game speed, and more.

Settings are saved to `sdmc:/switch/buckshot_roulette/nx_settings.cfg`.

## Performance
The game is locked at 30 fps. With `Lossless.dll` present, LSFG frame generation adds a generated frame between each
pair, so 60 images per second reach the screen. Tested on a Switch OLED in handheld mode (720p) at docked clocks
(GPU 768 MHz):
- main menu and the table: steady 30 (+ generated frames);
- the corridor into the club (about 20 lights) drops to ~17 fps for a few seconds;
- the first time some effects appear there can be a short hitch while their shaders compile.

Stock handheld clocks are slower. Docked play on a TV (1080p output) has not been tested much yet.

## Known limitations
- **Multiplayer** needs Steam and is hidden from the main menu.
- Steam achievements and leaderboards are not available (an offline stand-in replaces Steam).

## Files on the SD card
`sdmc:/switch/buckshot_roulette/`
- `buckshot_roulette.nro`, `buckshot_roulette.pck`: the port and the game pack
- `godot_log.txt`: log of the last run (attach it to bug reports)
- `nx_settings.cfg`, `userdata/`: port settings and the game's save
- `nx_patch.pck` (optional): updated port scripts, loaded over the pack
- `nx_lsfg_off`: created by the menu when frame generation is switched off

## Building from source
See [NOTES.md](NOTES.md). In short:
- Engine: Godot 4.1.1-stable + `engine/godot-4.1.1-switch.patch` (adds `platform/switch`), devkitPro (devkitA64, libnx).
- GL driver: [nxvk](https://github.com/PalindromicBreadLoaf/nxvk) built with `make gl` (Zink + NVK), with the swapchain
  change in `nxvk/wsi_swapchain_images.sh`, then the objcopy step described there.
- Frame generation: [lsfg-vk](https://github.com/PancakeTAS/lsfg-vk) sources in `third_party/lsfg-vk`.
- `py -3 -m SCons platform=switch target=template_release` (defaults: `zink=yes lsfg=yes`), then `elf2nro` with
  `release_assets/br.nacp` and `release_assets/icon.jpg`.
- `tools/make_switch_pck.py` builds the game pack; `tools/make_nx_patch.py` builds `nx_patch.pck` from `patch/nx`.

## Licenses
- Port code (`platform/switch`, scripts, tools): GPL-3.0-or-later, because the build links lsfg-vk (GPL-3.0-or-later).
- Godot Engine: MIT. Mesa / nxvk: MIT and GPL-2.0-or-later parts. See `LICENSES/`.
- Buckshot Roulette is © Mike Klubnika. This port is not affiliated with or endorsed by him. Buy the game.
- Lossless Scaling is © its developers. Its DLL is never included.
