"""Màn hình ảo cho chế độ màn hình phụ.

Windows chỉ cho kéo cửa sổ sang điện thoại khi nó "thấy" thêm một màn hình.
Không cắm màn hình thật thì cần một driver màn hình ảo: dùng Virtual Display
Driver (mã nguồn mở, giấy phép MIT, đã ký số), cài qua winget.

Nút trong cửa sổ agent gọi install() — không cần file .bat (bản agent tự cập
nhật chỉ tải HeDeckAgent.exe, không có các file .bat đi kèm).
"""

import subprocess
import sys

PACKAGE = "VirtualDrivers.Virtual-Display-Driver"
RELEASES = "https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/latest"


def status():
    """(số màn hình, có màn hình ảo không). Hỏi không được thì (0, False)."""
    if sys.platform != "win32":
        return 0, False
    try:
        import screen
        import sources
        screen._dpi_aware()
        mons = sources.monitors()
        return len(mons), any(m["virtual"] for m in mons)
    except Exception:
        return 0, False


def _console(title, lines):
    """Mở một cửa sổ lệnh chạy các dòng lệnh, để người dùng thấy tiến trình
    (winget tải về, hỏi quyền Administrator) và đọc được lỗi nếu có."""
    script = " & ".join(lines)
    subprocess.Popen(["cmd", "/c", "start", title, "cmd", "/k", script])


def install():
    """Cài driver qua winget rồi mở cài đặt màn hình của Windows."""
    _console("HeDeck - Them man hinh ao", [
        "chcp 65001 >nul",
        "echo Dang cai man hinh ao (Virtual Display Driver)...",
        "echo Windows hoi quyen Administrator thi bam Yes. Hien cua so"
        " Virtual Driver Control thi bam Install.",
        "echo.",
        f"winget install --id={PACKAGE} -e --accept-source-agreements"
        " --accept-package-agreements"
        f" || (echo. & echo [X] Chua cai duoc. Tai ban cai tai: {RELEASES})",
        "echo.",
        "echo Tiep theo: trong cai dat man hinh vua mo, chon man hinh moi,"
        " dat Extend these displays, chon do phan giai gan voi dien thoai.",
        "start ms-settings:display",
    ])


def remove():
    _console("HeDeck - Go man hinh ao", [
        "chcp 65001 >nul",
        f"winget uninstall --id={PACKAGE} -e",
        "echo. & echo Xong. Dong cua so nay.",
    ])


def open_settings():
    subprocess.Popen(["cmd", "/c", "start", "", "ms-settings:display"])
