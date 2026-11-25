@echo off
setlocal
title MuleSoft Customer Orders - Automatic Local Sync
set "ROOT=%LOCALAPPDATA%\MuleSoftCustomerOrders"
if not exist "%ROOT%" mkdir "%ROOT%"
echo Installing the automatic two-minute sync...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/Narsing-s/MuleSoft-Customer-Orders/main/scripts/sync_generated_files.ps1' -OutFile '%ROOT%\sync_generated_files.ps1'"
if errorlevel 1 (
  echo Could not download the sync script. Check your internet connection.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\sync_generated_files.ps1" -Install
if errorlevel 1 (
  echo Installation failed. Check %ROOT%\cloud-sync.log
  pause
  exit /b 1
)
echo.
echo SUCCESS: the sync task is installed.
echo Destination: C:\Users\91938\Desktop\mulesoft file processing input data
echo The files will be refreshed automatically every 2 minutes.
pause
endlocal
