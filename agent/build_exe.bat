@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set "VENV=.venv"
set "VPY=%VENV%\Scripts\python.exe"

if not exist "%VPY%" (
    echo [X] Chua co moi truong ao. Chay run_agent.bat mot lan truoc.
    pause & exit /b 1
)

echo [1/2] Cai pyinstaller...
"%VPY%" -m pip install pyinstaller --quiet
if errorlevel 1 (echo [X] Cai pyinstaller that bai & pause & exit /b 1)

echo [2/2] Dong goi...
"%VPY%" -m PyInstaller --onefile --name HeDeckAgent ^
    --hidden-import win32timezone ^
    --collect-all zeroconf ^
    --collect-all pycaw ^
    --collect-all comtypes ^
    agent.py
if errorlevel 1 (echo [X] Dong goi that bai & pause & exit /b 1)

echo.
echo File nam o: dist\HeDeckAgent.exe
echo.
pause
