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
echo  Script nay xoa sach thu muc android roi dung lai tu dau.
echo  Code trong lib/ va pubspec.yaml KHONG bi dong den.
echo.
echo  Dung khi gap loi:
echo    - Build failed due to use of deleted Android v1 embedding
echo    - Gradle loi lung tung khong ro nguyen nhan
echo.
set /p ok="Tiep tuc? (y/n): "
if /i not "%ok%"=="y" exit /b 0

echo.
echo [1/5] Xoa thu muc android va cache build...
if exist android rmdir /s /q android
if exist build rmdir /s /q build
if exist .dart_tool rmdir /s /q .dart_tool

echo [2/5] Sinh lai phan khung Android...
call flutter create . --platforms=android --project-name hedeck --org com.hedeck
if errorlevel 1 (echo [X] flutter create that bai & pause & exit /b 1)

echo [3/5] Va AndroidManifest cho HeDeck...
powershell -NoProfile -ExecutionPolicy Bypass -File "..\android_patch\patch_manifest.ps1"

echo [4/5] Tai package...
call flutter pub get

echo [5/5] Sinh icon launcher...
call dart run flutter_launcher_icons

echo.
echo === Xong. Chay lai: flutter run ===
echo.
pause
