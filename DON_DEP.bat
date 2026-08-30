@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo.
echo  Xoa cac file thua sot lai tu ban cu.
echo  Khong dong den ma nguon, cau hinh hay du lieu ghep cap.
echo.

set FOUND=0
if exist "BAT_DAU.md"  set FOUND=1 & echo   BAT_DAU.md        ^(da chuyen vao docs\^)
if exist "debug_symbols" set FOUND=1 & echo   debug_symbols\    ^(BUILD_APK.bat sinh lai duoc^)
if exist ".idea"       set FOUND=1 & echo   .idea\            ^(cau hinh Android Studio^)
if exist "tools\icon.png" set FOUND=1 & echo   tools\*.png       ^(make_icon.py sinh lai duoc^)

if "%FOUND%"=="0" (
    echo   Khong co gi thua. Thu muc da sach.
    echo.
    pause & exit /b 0
)

echo.
set /p ok="Xoa nhung thu tren? (y/n): "
if /i not "%ok%"=="y" exit /b 0

if exist "BAT_DAU.md" del /q "BAT_DAU.md"
if exist "debug_symbols" rmdir /s /q "debug_symbols"
if exist ".idea" rmdir /s /q ".idea"
del /q "tools\*.png" 2>nul

echo.
echo  Da don xong.
echo.
pause
