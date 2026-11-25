@echo off
setlocal
schtasks /Delete /TN "MuleSoftCustomerOrdersFileGenerator" /F
if errorlevel 1 (
  echo Could not remove the scheduled task. It may not be installed.
  exit /b 1
)
echo Automatic two-minute file generation has been disabled.
endlocal