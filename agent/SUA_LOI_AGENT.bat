@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo.
echo  Dung lai moi truong Python cua agent tu dau.
echo  Dung khi gap loi ModuleNotFoundError hoac "cannot find the path".
echo.
set /p ok="Tiep tuc? (y/n): "
if /i not "%ok%"=="y" exit /b 0

if exist .venv (
    echo Xoa moi truong ao cu...
    rmdir /s /q .venv
)
if exist __pycache__ rmdir /s /q __pycache__

echo Chay lai run_agent.bat de dung lai...
call run_agent.bat
