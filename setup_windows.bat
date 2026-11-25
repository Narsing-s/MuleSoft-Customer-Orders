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
if errorlevel 1 exit /b 1
call run_generator.bat
endlocal
