@echo off
chcp 65001 >nul
setlocal
echo.
echo  Build ban web cua HeDeck (dung tren iPhone, iPad, trinh duyet).
echo  Agent phuc vu ban web nay tai http://^<ip may tinh^>:8787/
echo.

call "%~dp0android_patch\tim_flutter.bat"
if not defined FLUTTER_OK (
    echo [X] Khong tim thay Flutter. Xem huong dan trong setup_app.bat.
    pause & exit /b 1
)

cd /d "%~dp0flutter_app"

echo [1/3] Tai package...
call flutter pub get
if errorlevel 1 (echo [X] pub get that bai & pause & exit /b 1)

echo [2/3] Build ban web...
rem --no-web-resources-cdn: khong tai gi tu CDN, chay duoc ca khi mang nha
rem khong co Internet. --pwa-strategy=none: trang http khong dung duoc
rem service worker.
call flutter build web --release --no-web-resources-cdn --pwa-strategy=none
if errorlevel 1 (echo [X] Build that bai & pause & exit /b 1)

echo [3/3] Chep sang agent\web...
rem Ban JS chi dung CanvasKit: bo skwasm va bang ky hieu go loi cho nhe.
del /s /q build\web\*.symbols >nul 2>nul
del /q build\web\canvaskit\skwasm* >nul 2>nul
if exist "..\agent\web" rmdir /s /q "..\agent\web"
xcopy /e /i /q /y build\web "..\agent\web" >nul
if errorlevel 1 (echo [X] Chep that bai & pause & exit /b 1)

echo.
echo  Xong. Mo lai agent (chuot phai icon o khay - Thoat, roi chay lai)
echo  la dung duoc ban web. Muon dong goi vao .exe: chay agent\build_exe.bat.
echo.
pause
