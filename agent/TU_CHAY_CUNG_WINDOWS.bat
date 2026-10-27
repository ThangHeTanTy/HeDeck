@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

rem Bat may tu xa xong ma agent khong tu chay thi app van khong ket noi duoc.
rem File nay dat loi tat cua agent vao thu muc Startup cua tai khoan hien
rem tai: dang nhap Windows la agent tu chay ngam o khay he thong, khong mo
rem cua so nao. Chay lai lan nua de go bo.
rem Ban tai tu GitHub dung HeDeckAgent.exe, ban ma nguon dung run_agent.bat.

set "TARGET=%~dp0run_agent.bat"
if exist "%~dp0HeDeckAgent.exe" set "TARGET=%~dp0HeDeckAgent.exe"

set "LNK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\HeDeck Agent.lnk"

if exist "%LNK%" (
    del "%LNK%"
    echo Da go bo: agent se KHONG tu chay khi dang nhap Windows nua.
    echo.
    pause & exit /b 0
)

powershell -NoProfile -Command ^
  "$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:LNK);" ^
  "$s.TargetPath = $env:TARGET;" ^
  "$s.Arguments = '--tray';" ^
  "$s.WorkingDirectory = '%~dp0';" ^
  "$s.WindowStyle = 7;" ^
  "$s.Description = 'HeDeck Agent';" ^
  "$s.Save()"
if errorlevel 1 (
    echo [X] Khong tao duoc loi tat.
    pause & exit /b 1
)

echo Da bat: dang nhap Windows la agent tu chay ngam o khay he thong.
echo Bam icon HeDeck o khay (mui ten ^ goc phai thanh tac vu) de mo cua so.
echo.
echo Luu y: neu Windows co mat khau, may bat len se dung o man hinh dang nhap
echo va agent chi chay sau khi ban dang nhap. Xem docs\BAT_MAY_TU_XA.md muc
echo "Tu dang nhap" neu muon bo qua buoc nay.
echo.
echo Chay lai file nay mot lan nua de go bo.
echo.
pause
