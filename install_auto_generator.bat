@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_auto_generator.ps1"
if errorlevel 1 (
  echo Failed to install the automatic generator task.
  exit /b 1
)
pause
endlocal