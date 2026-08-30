@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set "VENV=.venv"
set "VPY=%VENV%\Scripts\python.exe"

rem ---------------------------------------------------------------- tim Python
set "PY="
where py >nul 2>nul
if not errorlevel 1 set "PY=py -3"
if defined PY goto :have_python

where python >nul 2>nul
if not errorlevel 1 set "PY=python"
if not defined PY goto :no_python

:have_python

rem -------------------------------------------------- kiem tra moi truong ao
rem Kiem tra chinh file python.exe chu khong phai chi thu muc .venv. Thu muc
rem co the ton tai nhung do dang; luc do activate.bat loi va script am tham
rem chay bang Python he thong von khong co thu vien nao.
if exist "%VPY%" goto :check_deps

if exist "%VENV%" (
    echo [!] Moi truong ao hong, dang dung lai...
    rmdir /s /q "%VENV%"
) else (
    echo [1/2] Tao moi truong ao...
)
%PY% -m venv "%VENV%"
if errorlevel 1 goto :venv_failed
goto :install

:check_deps
"%VPY%" -c "import websockets, win32gui, psutil, PIL, cryptography, zeroconf" >nul 2>nul
if not errorlevel 1 goto :run

:install
echo [2/2] Cai thu vien, lan dau mat khoang mot phut...
"%VPY%" -m pip install --upgrade pip --quiet
"%VPY%" -m pip install -r requirements.txt
if errorlevel 1 goto :pip_failed

rem Kiem tra lai cho chac, pip co the bao thanh cong ma van thieu
"%VPY%" -c "import websockets, win32gui, psutil, PIL, cryptography, zeroconf" >nul 2>nul
if errorlevel 1 goto :pip_failed

:run
rem Tu kiem tra truoc khi chay: bat cac loi kieu "quen goi mot tac vu nen"
"%VPY%" kiem_tra_agent.py >nul 2>nul
if errorlevel 1 (
    echo [!] Tu kiem tra phat hien van de, chi tiet:
    "%VPY%" kiem_tra_agent.py
    echo.
)

rem pycaw chi dung cho o "Am luong tung app", thieu thi van chay binh thuong
"%VPY%" -c "import pycaw" >nul 2>nul
if errorlevel 1 echo [!] Thieu pycaw: o "Am luong tung app" se khong dung duoc.

echo.
"%VPY%" agent.py %*
pause
exit /b 0

rem ------------------------------------------------------------------- loi
:no_python
echo.
echo [X] Khong tim thay Python tren may nay.
echo     Tai ban 3.10 tro len tai https://www.python.org/downloads/
echo     Nho tick "Add python.exe to PATH" luc cai dat.
echo.
pause & exit /b 1

:venv_failed
echo.
echo [X] Khong tao duoc moi truong ao.
echo     Thu chay lai bang quyen Administrator.
echo.
pause & exit /b 1

:pip_failed
echo.
echo [X] Cai thu vien that bai.
echo.
echo   Neu mang cong ty chan pypi.org, thu lenh nay:
echo     "%VPY%" -m pip install -r requirements.txt --trusted-host pypi.org --trusted-host files.pythonhosted.org
echo.
echo   Neu van khong duoc, chay SUA_LOI_AGENT.bat de dung lai tu dau.
echo.
pause & exit /b 1
