@echo off
chcp 65001 >nul
setlocal
rem Tao khoa ky APK va dan vao GitHub Secrets. Chi can lam MOT lan duy nhat,
rem truoc lan phat hanh dau tien. Xem docs\PHAT_HANH.md.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\tao_khoa_ky.ps1"
echo.
pause
