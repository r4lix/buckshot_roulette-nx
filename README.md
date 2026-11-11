# buckshot_roulette-nx

Buckshot Roulette (Godot 4.1) running natively on the Nintendo Switch.

**No game content is included.** You need your own copy of the game (the Steam PC version, 2.2.x).

## Disclaimer

This project was created **entirely with the help of AI coding tools**.

I am **not a developer**, so the code may contain bugs, security vulnerabilities, mistakes, or unfinished features. buckshot_roulette-nx is a personal project that I decided to share with others who may find it useful.

Use it at your own risk. I cannot guarantee support, stability, compatibility, security, or regular updates.

## Takedown notice

The NRO contains no game files: the game pack is built on your PC from your own Steam copy. If you are a right holder and want this project removed, contact me or open an issue and I will take it down within 48 hours.


## Install

1. Download `BuckshotRouletteNX-1.0.0.zip` from the [latest release](https://github.com/r4lix/buckshot_roulette-nx/releases/latest) and extract it on your PC.
2. Run `build_pack.bat` (needs [Python 3](https://www.python.org/downloads/)). It builds the game pack from your Steam copy;
   if the game is not in the default Steam folder, drag `Buckshot Roulette.exe` onto `build_pack.bat`.
3. Copy the `switch` folder to the root of your SD card. This creates `sdmc:/switch/buckshot_roulette/`.
4. Optional, for frame generation (60 frames on screen): copy `Lossless.dll` from your own copy of Lossless Scaling to
   `sdmc:/switch/buckshot_roulette/`.
5. Launch **Buckshot Roulette NX** from the homebrew menu, opened through a game (hold **R** while starting any game).

Right stick moves the cursor, **ZR** / **ZL** click, the touch screen works too. Press **-** for the menu: graphics,
sound and cheats.

Multiplayer needs Steam and is not available.


## Building

See [docs/ADVANCED.md](docs/ADVANCED.md).
