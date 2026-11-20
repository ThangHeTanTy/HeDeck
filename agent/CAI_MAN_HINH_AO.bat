@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

rem Cai "man hinh ao" cho Windows de dien thoai thanh man hinh mo rong that:
rem Windows thay them mot man hinh, keo cua so sang la hien tren dien thoai
rem (HeDeck -> nut Man hinh phu). Dung Virtual Display Driver, ma nguon mo
rem (giay phep MIT), da ky so: https://github.com/VirtualDrivers/Virtual-Display-Driver
rem Cai qua winget, trinh cai dat co san tren Windows 10/11.

echo ============================================================
echo   HeDeck - Man hinh ao cho che do Man hinh phu
echo ============================================================
echo   1. Cai man hinh ao
echo   2. Go man hinh ao
echo   3. Mo cai dat man hinh cua Windows
echo.
set /p CHON=Chon 1, 2 hoac 3 roi Enter: 

where winget >nul 2>nul
if errorlevel 1 if not "%CHON%"=="3" (
    echo.
    echo [X] May nay chua co winget. Cai "App Installer" tu Microsoft Store,
    echo     hoac tai ban cai tai trang duoi day roi bam Install:
    start "" "https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/latest"
    goto :end
)

if "%CHON%"=="1" goto :install
if "%CHON%"=="2" goto :remove
if "%CHON%"=="3" goto :settings
echo Khong hieu lua chon.
goto :end

:install
echo.
echo Dang cai... Windows co the hoi quyen Administrator, bam Yes.
echo Neu hien cua so Virtual Driver Control, bam Install trong do.
winget install --id=VirtualDrivers.Virtual-Display-Driver -e --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
    echo.
    echo [X] Cai chua xong. Thu chay lai, hoac tai ban cai bang tay:
    echo     https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/latest
    goto :end
)
echo.
echo [OK] Da cai. Buoc tiep theo:
echo   - Trong cai dat man hinh (vua mo ra): chon man hinh moi, dat
echo     "Extend these displays" / "Mo rong cac man hinh nay".
echo   - Chon do phan giai gan voi dien thoai (HeDeck hien so nay khi chon
echo     nguon trong Man hinh phu), keo man hinh moi toi canh man hinh chinh.
echo   - Tren dien thoai: HeDeck -> nut Man hinh phu -> chon man hinh ao.
:settings
start "" ms-settings:display
goto :end

:remove
echo.
winget uninstall --id=VirtualDrivers.Virtual-Display-Driver -e
if errorlevel 1 (
    echo [X] Khong go duoc qua winget. Go bang tay trong Settings -^> Apps.
) else (
    echo [OK] Da go man hinh ao.
)

:end
echo.
pause
