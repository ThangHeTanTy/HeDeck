@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

rem Mo Tuong lua Windows cho HeDeck qua Tailscale. Card mang cua Tailscale
rem thuong bi Windows xep vao loai "Public" nen bi chan, iPhone/dien thoai o
rem ngoai bao "may chu da dung phan hoi". Chi mo cong 8787 cho cac may trong
rem mang Tailscale cua ban (100.64.0.0/10), khong mo cho Internet.
net session >nul 2>nul
if errorlevel 1 (
    echo Dang xin quyen Administrator...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

powershell -NoProfile -Command "Remove-NetFirewallRule -DisplayName 'HeDeck-Tailscale' -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'HeDeck-Tailscale' -Direction Inbound -Protocol TCP -LocalPort 8787 -RemoteAddress 100.64.0.0/10 -Action Allow -Profile Any | Out-Null"
if errorlevel 1 (
    echo [X] Khong tao duoc quy tac tuong lua.
) else (
    echo [OK] Da cho phep HeDeck qua Tailscale. Thu mo lai tren iPhone.
)
echo.
pause
