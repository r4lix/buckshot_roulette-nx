@echo off
setlocal
rem Builds the Switch game pack from YOUR OWN Steam copy of Buckshot Roulette.
rem Usage: double-click (uses the default Steam folder), or drag "Buckshot Roulette.exe" onto this file.
cd /d "%~dp0"

set "EXE=%~1"
if "%EXE%"=="" set "EXE=C:\Program Files (x86)\Steam\steamapps\common\Buckshot Roulette\Buckshot Roulette_windows\Buckshot Roulette.exe"
if not exist "%EXE%" (
  echo Could not find "%EXE%".
  echo Drag "Buckshot Roulette.exe" from your Steam folder onto build_pack.bat.
  pause
  exit /b 1
)

set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY (
  echo Python 3 is needed: install it from https://www.python.org/downloads/ and run this again.
  pause
  exit /b 1
)

%PY% "pc\make_switch_pck.py" "%EXE%" "switch\buckshot_roulette\buckshot_roulette.pck"
if errorlevel 1 (
  echo Building the pack failed.
  pause
  exit /b 1
)
echo.
echo Done. Copy the "switch" folder to the root of your SD card.
pause
