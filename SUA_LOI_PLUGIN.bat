@echo off
chcp 65001 >nul
setlocal
call "%~dp0android_patch\tim_flutter.bat"
if not defined FLUTTER_OK (
    echo.
    echo [X] Khong tim thay Flutter tren may nay.
    echo.
    echo   1. Tai Flutter SDK:
    echo      https://docs.flutter.dev/get-started/install/windows
    echo   2. Giai nen vao C:\flutter  ^(tranh thu muc co dau cach^)
    echo   3. Them C:\flutter\bin vao bien moi truong PATH
    echo   4. Mo lai cua so nay roi chay lai script
    echo.
    echo   Neu da cai o cho khac, mo PowerShell va chay:
    echo      $env:Path += ";duong\dan\flutter\bin"
    echo.
    pause & exit /b 1
)

cd /d "%~dp0flutter_app"

echo.
echo  Don sach cache plugin va dung lai. Dung khi gap loi kieu:
echo    - Unresolved reference trong mot plugin nao do
echo    - compileDebugKotlin failed
echo    - Plugin cu khong hop voi ban Flutter moi
echo.
echo  Code trong lib/ KHONG bi dong den.
echo.
set /p ok="Tiep tuc? (y/n): "
if /i not "%ok%"=="y" exit /b 0

echo.
echo [1/4] Xoa cache build...
call flutter clean
if exist .dart_tool rmdir /s /q .dart_tool
if exist android\.gradle rmdir /s /q android\.gradle

echo [2/4] Xoa cache plugin trong Pub...
if exist "%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\wakelock_plus-1.5.2" (
    rmdir /s /q "%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\wakelock_plus-1.5.2"
    echo   Da xoa wakelock_plus-1.5.2 hong
)

echo [3/4] Tai lai package...
call flutter pub get
if errorlevel 1 (echo [X] pub get that bai & pause & exit /b 1)

echo [4/4] Va lai MainActivity va manifest...
powershell -NoProfile -ExecutionPolicy Bypass -File "..\android_patch\patch_manifest.ps1"

echo.
echo === Xong. Chay lai: flutter run ===
echo.
pause
