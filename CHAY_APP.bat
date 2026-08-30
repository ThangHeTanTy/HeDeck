@echo off
chcp 65001 >nul
setlocal
call "%~dp0android_patch\tim_flutter.bat"
if not defined FLUTTER_OK (
    echo.
    echo [X] Khong tim thay Flutter tren may nay.
    echo     Tai tai: https://docs.flutter.dev/get-started/install/windows
    echo     Giai nen vao C:\flutter roi chay lai script nay.
    echo.
    pause & exit /b 1
)
cd /d "%~dp0flutter_app"

echo.
echo ============================================================
echo  Chay HeDeck tren thiet bi Android
echo ============================================================

echo.
echo [1/4] Cau hinh Gradle...
powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "..\android_patch\cau_hinh_gradle.ps1" -ProjectAndroidDir "%CD%\android"

echo [2/4] Dung daemon cu con giu cache...
powershell -NoProfile -ExecutionPolicy Bypass -File "..\android_patch\dung_daemon.ps1"

echo [3/4] Kiem tra thiet bi...
call flutter devices
echo.

echo [4/4] Chay app...
echo.
call flutter run %*

pause
