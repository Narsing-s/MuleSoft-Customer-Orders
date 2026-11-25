@echo off
setlocal
set "INPUT=C:\Users\91938\Desktop\mulesoft file processing input data"
set "OUTPUT=C:\Users\91938\Desktop\mulesoft file processing output"
mkdir "%INPUT%" 2>nul
mkdir "%INPUT%\_archive" 2>nul
mkdir "%OUTPUT%" 2>nul
mkdir "%OUTPUT%\processed" 2>nul
mkdir "%OUTPUT%\failed" 2>nul

cd /d "%~dp0generator"
python -m pip install -r requirements.txt
if errorlevel 1 (
  echo Python dependency installation failed.
  exit /b 1
)
call run_generator.bat
if errorlevel 1 exit /b 1

cd /d "%~dp0"
echo.
echo Installing automatic file generation every 2 minutes...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_auto_generator.ps1"
if errorlevel 1 (
  echo Automatic task installation failed. Run install_auto_generator.bat manually.
  exit /b 1
)
echo.
echo Setup complete. Files will be regenerated every 2 minutes.
endlocal
