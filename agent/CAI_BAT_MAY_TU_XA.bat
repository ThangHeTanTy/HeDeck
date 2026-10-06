@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

rem Cau hinh card mang va Windows de bat may tu xa. Can quyen Administrator,
rem chua co thi tu xin roi chay lai chinh file nay.
net session >nul 2>nul
if errorlevel 1 (
    echo Dang xin quyen Administrator...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cau_hinh_wol.ps1"
pause
