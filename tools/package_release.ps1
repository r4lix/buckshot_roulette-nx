# Builds dist/BuckshotRouletteNX-<version>.zip from the current build (no game files).
# usage: powershell -File tools/package_release.ps1 [-Version 1.0.0]
param([string]$Version = "1.0.0")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$elf = Join-Path $root "godot/bin/godot.switch.template_release.arm64.elf"
$name = "BuckshotRouletteNX-$Version"
$stage = Join-Path $root "dist/$name"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force "$stage/switch/buckshot_roulette", "$stage/pc/patch/nx", "$stage/pc/patch/steam_stub" | Out-Null

& C:/devkitPro/tools/bin/nacptool.exe --create "Buckshot Roulette NX" "Mike Klubnika / NX port" $Version "$root/release_assets/br.nacp" | Out-Null
& C:/devkitPro/tools/bin/elf2nro.exe $elf "$stage/switch/buckshot_roulette/buckshot_roulette.nro" "--nacp=$root/release_assets/br.nacp" "--icon=$root/release_assets/icon.jpg" | Out-Null
if (-not (Test-Path "$stage/switch/buckshot_roulette/buckshot_roulette.nro")) { throw "elf2nro failed" }

Copy-Item "$root/release_assets/build_pack.bat" $stage
Copy-Item "$root/tools/make_switch_pck.py" "$stage/pc/"
Copy-Item "$root/patch/nx/*.gd" "$stage/pc/patch/nx/"
Copy-Item "$root/patch/steam_stub/SteamStub.gd" "$stage/pc/patch/steam_stub/"
Copy-Item "$root/README.md" $stage; New-Item -ItemType Directory -Force "$stage/docs" | Out-Null; Copy-Item "$root/docs/ADVANCED.md" "$stage/docs/"
Copy-Item -Recurse "$root/LICENSES" $stage

$zip = Join-Path $root "dist/$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path "$stage/*" -DestinationPath $zip
Get-Item $zip | Select-Object FullName, Length
