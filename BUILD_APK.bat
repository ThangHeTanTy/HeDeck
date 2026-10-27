@echo off
chcp 65001 >nul
setlocal
echo.
echo  Xuat APK ban phat hanh, co lam roi ma nguon Dart.
echo.

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

echo [1/3] Don cache build cu...
call flutter clean >nul
call flutter pub get
if errorlevel 1 (echo [X] pub get that bai & pause & exit /b 1)

rem Va lai thu muc android moi lan build: file trong do chi duoc tao luc chay
rem setup_app.bat, sua android_patch sau do (quy tac R8, bo cap nhat app...)
rem se khong toi duoc ban build neu khong va lai o day. Va nhieu lan van an toan.
if exist android\app (
    powershell -NoProfile -ExecutionPolicy Bypass -File "..\android_patch\patch_manifest.ps1"
    if errorlevel 1 (echo [X] Va thu muc android that bai & pause & exit /b 1)
)

echo [2/3] Build APK release ^(obfuscate^)...
rem --obfuscate doi ten lop, ham, bien trong ma Dart thanh ky tu vo nghia.
rem --split-debug-info tach bang doi chieu ra ngoai, KHONG kem trong APK.
rem Giu thu muc debug_symbols de con doc duoc bao loi tu ban da phat hanh.
rem
rem TAT R8 (shrink=false). Ban release cua Flutter LUON bat R8 va rut gon tai
rem nguyen, ke ca khi khong ghi --shrink - co --no-shrink cung da bi bo, khong
rem con tac dung. R8 cat bo lop Java/Kotlin ma no cho la khong dung toi; cac
rem plugin dung Pigeon (shared_preferences chang han) duoc goi qua phan xa nen
rem R8 khong thay -> ban release treo hoac loi ma ban debug tren may ao van
rem chay. Tiet kiem vai tram KB khong dang de doi lay rui ro do.
call flutter build apk --release ^
    --android-project-arg=shrink=false ^
    --obfuscate ^
    --split-debug-info=..\debug_symbols
if errorlevel 1 (echo [X] Build that bai & pause & exit /b 1)

echo [3/3] Kiem tra ket qua...
set APK=build\app\outputs\flutter-apk\app-release.apk
if not exist "%APK%" (echo [X] Khong thay file APK & pause & exit /b 1)

rem Co khoa phat hanh (TAO_KHOA_KY.bat) thi ky bang khoa do, de cai de len
rem duoc ban tai tu GitHub. Khong co thi bo qua.
powershell -NoProfile -ExecutionPolicy Bypass -File "..\tools\ky_apk.ps1" -Apk "%APK%"

powershell -NoProfile -Command ^
  "$f = Get-Item '%APK%'; " ^
  "Write-Host ''; " ^
  "Write-Host ('  File   : ' + $f.FullName); " ^
  "Write-Host ('  Kich thuoc : ' + [math]::Round($f.Length/1MB,2) + ' MB'); " ^
  "$h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash; " ^
  "Write-Host ('  SHA-256: ' + $h); " ^
  "$h | Out-File -Encoding ascii ($f.FullName + '.sha256')"

echo.
echo  Ma doi chieu loi nam o: debug_symbols\
echo  Giu thu muc do lai neu muon doc stack trace tu ban phat hanh.
echo.
pause
