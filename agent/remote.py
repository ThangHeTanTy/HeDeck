"""Điều khiển từ xa qua Internet bằng Tailscale.

Tailscale nối điện thoại và máy tính thành một mạng riêng có mã hoá, dù hai
bên ở đâu. Agent không mở cổng nào ra Internet: nó chỉ nhận thêm kết nối từ
địa chỉ Tailscale (100.x.y.z), coi như mạng nội bộ. Địa chỉ đó cố định cho
mỗi máy, nên điện thoại nhớ một lần là ra ngoài vẫn gọi về được.
"""

import socket

import psutil

import security


def tailscale_ip():
    """Địa chỉ Tailscale IPv4 của máy này, rỗng nếu chưa cài hoặc chưa bật."""
    try:
        for addrs in psutil.net_if_addrs().values():
            for a in addrs:
                if a.family == socket.AF_INET and security.is_tailscale_ip(a.address):
                    return a.address
    except Exception:
        pass
    return ""


def describe():
    ip = tailscale_ip()
    return (f"Tailscale {ip}" if ip
            else "chưa có — cài Tailscale để dùng ngoài mạng nhà")
