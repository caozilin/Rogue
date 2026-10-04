@echo off
setlocal
cd /d "%~dp0"
if exist ".tools\Godot_v4.5.1-stable_win64.exe" (
  if not exist ".godot\global_script_class_cache.cfg" (
    ".tools\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0." --editor --quit
  )
  start "Twin Survivors" ".tools\Godot_v4.5.1-stable_win64.exe" --path "%~dp0."
  exit /b 0
)
where godot >nul 2>nul
if %errorlevel% equ 0 (
  godot --path "%~dp0."
  exit /b
)
where godot4 >nul 2>nul
if %errorlevel% equ 0 (
  godot4 --path "%~dp0."
  exit /b
)
echo Open project.godot in Godot 4.x, then press F5.
pause
