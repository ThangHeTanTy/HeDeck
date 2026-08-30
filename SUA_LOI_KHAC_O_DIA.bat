@echo off
chcp 65001 >nul
setlocal
call "%~dp0android_patch\tim_flutter.bat"
if not defined FLUTTER_OK (
    echo [X] Khong tim thay Flutter. Chay setup_app.bat truoc.
    pause & exit /b 1
)
cd /d "%~dp0flutter_app"

echo.
echo ============================================================
echo  Sua loi Kotlin khi project va Pub cache nam khac o dia
echo ============================================================
echo.

rem --- Chan doan: hai thu nay o dau ---
for %%A in ("%CD%") do set "PROJ_DRIVE=%%~dA"
set "PUBC=%PUB_CACHE%"
if not defined PUBC set "PUBC=%LOCALAPPDATA%\Pub\Cache"
for %%B in ("%PUBC%") do set "CACHE_DRIVE=%%~dB"

echo   Project    : %CD%
echo   Pub cache  : %PUBC%
echo.
if /i "%PROJ_DRIVE%"=="%CACHE_DRIVE%" (
    echo   Hai thu muc CUNG o dia %PROJ_DRIVE% - khong phai nguyen nhan nay.
    echo   Van co the don cache de thu lai.
) else (
    echo   [!] Project o dia %PROJ_DRIVE%, Pub cache o dia %CACHE_DRIVE%.
    echo       Kotlin khong tinh duoc duong dan tuong doi giua hai o dia,
    echo       nen build sap. Day chinh la nguyen nhan.
)
echo.
echo  Chon cach sua:
echo    1 - Tat bien dich tang dan cua Kotlin  ^(nhanh, build lai cham hon^)
echo    2 - Chuyen Pub cache ve cung o dia     ^(dut diem, tai lai package^)
echo    3 - Ca hai
echo    0 - Thoat
echo.
set /p choice="Chon (0-3): "
if "%choice%"=="0" exit /b 0

echo.
echo [1/4] Dung Gradle va Kotlin daemon dang chay...
if exist gradlew.bat call gradlew.bat --stop 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -File "..\android_patch\dung_daemon.ps1"

echo [2/4] Xoa cache build hong...
if exist build rmdir /s /q build
if exist .dart_tool rmdir /s /q .dart_tool
if exist android\.gradle rmdir /s /q android\.gradle
if exist android\app\build rmdir /s /q android\app\build

echo [3/4] Ap dung cach sua...
if "%choice%"=="1" goto :fix_incremental
if not exist android (
    echo   [!] Chua co thu muc android. Chay setup_app.bat truoc.
    pause & exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "..\android_patch\cau_hinh_gradle.ps1" -ProjectAndroidDir "%CD%\android"

:after_incremental

:fix_incremental
set "GP=android\gradle.properties"
if not exist android (
    echo   [!] Chua co thu muc android. Chay setup_app.bat truoc.
    pause & exit /b 1
)
if not exist "%GP%" type nul > "%GP%"
findstr /c:"kotlin.incremental=false" "%GP%" >nul 2>nul
if errorlevel 1 (
    echo.>> "%GP%"
    echo # Tat bien dich tang dan: project va Pub cache khac o dia thi Kotlin>> "%GP%"
    echo # khong tinh duoc duong dan tuong doi va build sap.>> "%GP%"
    echo kotlin.incremental=false>> "%GP%"
    echo kotlin.incremental.useClasspathSnapshot=false>> "%GP%"
    echo # Bien dich ngay trong tien trinh Gradle, khong dung daemon rieng.>> "%GP%"
    echo # Daemon giu trang thai giua cac lan build; mot lan hong la nhung lan>> "%GP%"
    echo # sau bao "Storage is already registered" cho toi khi giet no di.>> "%GP%"
    echo kotlin.compiler.execution.strategy=in-process>> "%GP%"
    echo   + Da ghi thiet lap Kotlin vao %GP%
) else (
    echo   + %GP% da co san thiet lap nay
)

:after_incremental
if "%choice%"=="2" goto :fix_pubcache
if "%choice%"=="3" goto :fix_pubcache
goto :done

:fix_pubcache
set "NEWCACHE=%PROJ_DRIVE%\pub-cache"
echo.
echo   Se dat PUB_CACHE = %NEWCACHE%
echo   Lan chay tiep theo se tai lai toan bo package, mat vai phut.
set /p ok2="Dong y? (y/n): "
if /i not "%ok2%"=="y" goto :done
setx PUB_CACHE "%NEWCACHE%" >nul
set "PUB_CACHE=%NEWCACHE%"
echo   + Da dat PUB_CACHE. Nho MO LAI cua so PowerShell truoc khi chay tiep.

:done
echo.
echo [4/4] Tai lai package...
call flutter pub get

echo.
echo ============================================================
echo  Xong. Chay lai:  flutter run
if "%choice%"=="2" echo  Nho mo lai cua so PowerShell truoc da.
if "%choice%"=="3" echo  Nho mo lai cua so PowerShell truoc da.
echo ============================================================
echo.
pause
