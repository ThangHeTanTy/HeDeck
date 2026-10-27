@echo off
chcp 65001 >nul
setlocal
rem Gan the phien ban moi (vd v1.2.0) va day len GitHub. GitHub Actions tu
rem build APK + agent va dang Release. Xem docs\PHAT_HANH.md.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\phat_hanh.ps1"
echo.
pause
