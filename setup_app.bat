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

rem Canh bao som neu project va Pub cache khac o dia - day la nguyen nhan
rem quen thuoc lam build Kotlin sap tren Windows.
for %%A in ("%CD%") do set "PROJ_DRIVE=%%~dA"
set "PUBC=%PUB_CACHE%"
if not defined PUBC set "PUBC=%LOCALAPPDATA%\Pub\Cache"
for %%B in ("%PUBC%") do set "CACHE_DRIVE=%%~dB"
if /i not "%PROJ_DRIVE%"=="%CACHE_DRIVE%" (
    echo.
    echo [!] Project o dia %PROJ_DRIVE%, Pub cache o dia %CACHE_DRIVE%.
    echo     Script se tu tat bien dich tang dan cua Kotlin de build khong sap.
    echo     Muon nhanh hon ve lau dai, chay SUA_LOI_KHAC_O_DIA.bat va chon 2.
    echo.
)

echo [1/4] Sinh phan khung Android...
call flutter create . --platforms=android --project-name hedeck --org com.hedeck
if errorlevel 1 (echo [X] flutter create that bai & pause & exit /b 1)

echo [2/4] Va AndroidManifest cho HeDeck...
powershell -NoProfile -ExecutionPolicy Bypass -File "..\android_patch\patch_manifest.ps1"
if errorlevel 1 (echo [X] Va manifest that bai & pause & exit /b 1)

echo [2b/4] Cau hinh Gradle cho may nay...
powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "..\android_patch\cau_hinh_gradle.ps1" -ProjectAndroidDir "%CD%\android"

echo [3/4] Tai package...
call flutter pub get
if errorlevel 1 (echo [X] pub get that bai & pause & exit /b 1)

echo [4/4] Sinh icon launcher HeDeck...
call dart run flutter_launcher_icons
if errorlevel 1 (echo [!] Sinh icon that bai, app van chay duoc voi icon mac dinh)

echo.
echo === Xong. Cam dien thoai vao va chay: ===
echo     cd flutter_app
echo     flutter run                  ^(chay thu^)
echo     flutter build apk --release  ^(xuat APK^)
echo.
pause
