"""Mở Tường lửa Windows cho kết nối qua Tailscale.

Lần đầu chạy, Windows hỏi tường lửa và người dùng cho phép ở "Private
networks". Nhưng card mạng ảo của Tailscale thường bị Windows xếp vào loại
"Public", nên kết nối qua Tailscale bị chặn lặng lẽ — iPhone báo "máy chủ đã
dừng phản hồi". Quy tắc ở đây chỉ mở cổng của HeDeck cho các máy trong mạng
Tailscale (100.64.0.0/10), không mở cho Internet.
"""

import base64
import subprocess
import sys

RULE = "HeDeck-Tailscale"
_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def rule_exists():
    """Đã có quy tắc chưa. Không phải Windows hay không hỏi được thì coi như có,
    để khỏi báo nhầm."""
    if sys.platform != "win32":
        return True
    try:
        r = subprocess.run(
            ["netsh", "advfirewall", "firewall", "show", "rule", f"name={RULE}"],
            capture_output=True, timeout=10, creationflags=_NO_WINDOW)
        return r.returncode == 0
    except Exception:
        return True


def command(port):
    """Lệnh PowerShell tạo quy tắc (xoá bản cũ trước để không bị trùng)."""
    return (
        f"Remove-NetFirewallRule -DisplayName '{RULE}' -ErrorAction SilentlyContinue; "
        f"New-NetFirewallRule -DisplayName '{RULE}' -Direction Inbound "
        f"-Protocol TCP -LocalPort {int(port)} -RemoteAddress 100.64.0.0/10 "
        f"-Action Allow -Profile Any | Out-Null"
    )


def open_for_tailscale(port):
    """Tạo quy tắc. Cần quyền Administrator: Windows hiện hộp hỏi (UAC)."""
    # Lệnh bên trong mã hoá base64 (UTF-16LE) để khỏi lo dấu nháy lồng nhau.
    inner = base64.b64encode(command(port).encode("utf-16-le")).decode()
    outer = ("Start-Process powershell -Verb RunAs -WindowStyle Hidden "
             f"-ArgumentList '-NoProfile -EncodedCommand {inner}'")
    subprocess.Popen(["powershell", "-NoProfile", "-WindowStyle", "Hidden",
                      "-Command", outer], creationflags=_NO_WINDOW)
