"""Nguồn hình cho chế độ "màn hình phụ": một màn hình hoặc một cửa sổ.

Điện thoại chọn một nguồn, agent chỉ chụp đúng nguồn đó và gửi về; chạm trên
điện thoại thì agent đổi toạ độ trong ảnh ra toạ độ thật trên Windows.

- Màn hình: mọi màn hình Windows đang thấy, kể cả màn hình ảo do driver
  Virtual Display Driver tạo ra (xem CAI_MAN_HINH_AO.bat). Có màn hình ảo thì
  điện thoại thành màn hình mở rộng thật: kéo cửa sổ sang là hiện trên điện
  thoại.
- Cửa sổ: một cửa sổ cụ thể (Discord, OBS, Spotify...), chụp được cả khi bị
  cửa sổ khác che.

Nguồn gửi qua mạng dạng {"monitor": số thứ tự} hoặc {"window": hwnd}.
Các hàm chỉ dùng Windows nhập thư viện bên trong hàm, để tự kiểm tra chạy
được trên máy khác.
"""

# Cửa sổ nhỏ hơn thế này (thanh công cụ nổi, popup) không đưa vào danh sách.
MIN_WINDOW = 160

# Danh sách cửa sổ dài quá thì khó chọn; giữ những cửa sổ đầu (theo thứ tự
# Windows xếp: cửa sổ dùng gần đây đứng trước).
MAX_WINDOWS = 40

# Chữ trong tên thiết bị cho biết đây là màn hình ảo (driver IddCx).
VIRTUAL_HINTS = ("virtual", "idd", "mttvdd", "parsec", "spacedesk")


def parse(source):
    """Kiểm tra nguồn điện thoại gửi. Trả về ("monitor", i), ("window", hwnd)
    hoặc None (màn hình chính, như touchpad)."""
    if not isinstance(source, dict):
        return None
    if "monitor" in source:
        try:
            i = int(source["monitor"])
        except (TypeError, ValueError):
            raise ValueError("Nguồn màn hình không hợp lệ")
        if not 0 <= i < 16:
            raise ValueError("Nguồn màn hình không hợp lệ")
        return ("monitor", i)
    if "window" in source:
        try:
            hwnd = int(source["window"])
        except (TypeError, ValueError):
            raise ValueError("Nguồn cửa sổ không hợp lệ")
        if hwnd <= 0:
            raise ValueError("Nguồn cửa sổ không hợp lệ")
        return ("window", hwnd)
    return None


def to_screen(rect, fx, fy):
    """Điểm (fx, fy) tính theo tỉ lệ 0..1 trong nguồn → pixel trên Windows.

    rect là (x, y, rộng, cao) của nguồn trên màn hình ảo của Windows (gốc ở
    góc trái trên của màn hình chính, màn hình bên trái có x âm)."""
    x, y, w, h = rect
    try:
        fx = min(1.0, max(0.0, float(fx)))
        fy = min(1.0, max(0.0, float(fy)))
    except (TypeError, ValueError):
        raise ValueError("Toạ độ không hợp lệ")
    return (x + min(w - 1, int(fx * w)), y + min(h - 1, int(fy * h)))


def relative_cursor(rect, cx, cy, kind):
    """Con trỏ tính theo nguồn. Ngoài nguồn thì coi như ẩn (-1, -1, 0)."""
    x, y, w, h = rect
    rx, ry = cx - x, cy - y
    if cx < -30000 or not (0 <= rx < w and 0 <= ry < h):
        return -1, -1, 0
    return rx, ry, kind


def is_virtual(device_string):
    s = (device_string or "").lower()
    return any(h in s for h in VIRTUAL_HINTS)


# --------------------------------------------------------------- Windows ---

def monitors():
    """Các màn hình, theo thứ tự Windows liệt kê: số thứ tự, tên, vị trí."""
    import win32api

    out = []
    for i, (hmon, _, _) in enumerate(win32api.EnumDisplayMonitors()):
        info = win32api.GetMonitorInfo(hmon)
        left, top, right, bottom = info["Monitor"]
        device = info.get("Device", "")
        label = ""
        try:
            label = win32api.EnumDisplayDevices(device, 0).DeviceString
        except Exception:
            pass
        out.append({
            "id": i,
            "device": device,
            "name": label or device.replace("\\\\.\\", ""),
            "x": left, "y": top, "w": right - left, "h": bottom - top,
            "primary": bool(info.get("Flags", 0) & 1),
            "virtual": is_virtual(label),
        })
    return out


def windows(table=None):
    """Cửa sổ chọn được: có tiêu đề, không thu nhỏ quá bé."""
    import win32gui

    import win_control

    out = []
    for hwnd, proc, _ in table if table is not None else win_control.window_table():
        title = win_control.window_title(hwnd).strip()
        if not title:
            continue
        try:
            if not win32gui.IsIconic(hwnd):
                _, _, w, h = window_rect(hwnd)
                if w < MIN_WINDOW or h < MIN_WINDOW:
                    continue
        except Exception:
            continue
        out.append({"id": hwnd, "title": title[:120], "exe": proc})
        if len(out) >= MAX_WINDOWS:
            break
    return out


def window_rect(hwnd):
    """Khung thật của cửa sổ (bỏ viền bóng trong suốt của Windows 10/11)."""
    import ctypes
    from ctypes import wintypes

    rect = wintypes.RECT()
    DWMWA_EXTENDED_FRAME_BOUNDS = 9
    try:
        ok = ctypes.windll.dwmapi.DwmGetWindowAttribute(
            wintypes.HWND(hwnd), DWMWA_EXTENDED_FRAME_BOUNDS,
            ctypes.byref(rect), ctypes.sizeof(rect)) == 0
    except Exception:
        ok = False
    if not ok:
        import win32gui
        left, top, right, bottom = win32gui.GetWindowRect(hwnd)
    else:
        left, top, right, bottom = rect.left, rect.top, rect.right, rect.bottom
    return (left, top, max(1, right - left), max(1, bottom - top))


def rect_of(kind, value):
    """(x, y, rộng, cao) của nguồn. Báo lỗi dễ hiểu nếu nguồn đã mất."""
    if kind == "monitor":
        mons = monitors()
        if value >= len(mons):
            raise LookupError("Màn hình này không còn nữa")
        m = mons[value]
        return (m["x"], m["y"], m["w"], m["h"])
    import win32gui
    if not win32gui.IsWindow(value):
        raise LookupError("Cửa sổ này đã đóng")
    if win32gui.IsIconic(value):
        # Đang thu nhỏ thì không có gì để chụp: mở lại, vì người dùng vừa
        # chọn xem đúng cửa sổ này.
        win32gui.ShowWindow(value, 9)   # SW_RESTORE
    return window_rect(value)


def grab(kind, value, rect):
    """Ảnh của nguồn (PIL.Image)."""
    from PIL import ImageGrab

    x, y, w, h = rect
    if kind == "window":
        img = _print_window(value, rect)
        if img is not None:
            return img
    # Màn hình, hoặc cửa sổ không tự vẽ ra được: chụp đúng vùng đó trên màn.
    return ImageGrab.grab(bbox=(x, y, x + w, y + h), all_screens=True)


def _print_window(hwnd, rect):
    """Nhờ cửa sổ tự vẽ vào ảnh: chụp được cả khi bị che. Trả None nếu cửa
    sổ không hỗ trợ (ảnh toàn đen)."""
    try:
        import ctypes

        import win32gui
        import win32ui
        from PIL import Image

        # Cửa sổ vẽ ra cả viền bóng trong suốt quanh nó (GetWindowRect), còn
        # rect là khung nhìn thấy: cắt phần bóng đi cho khớp toạ độ.
        left, top, right, bottom = win32gui.GetWindowRect(hwnd)
        w, h = max(1, right - left), max(1, bottom - top)
        ox, oy = max(0, rect[0] - left), max(0, rect[1] - top)
        hdc = win32gui.GetWindowDC(hwnd)
        src = win32ui.CreateDCFromHandle(hdc)
        mem = src.CreateCompatibleDC()
        bmp = win32ui.CreateBitmap()
        bmp.CreateCompatibleBitmap(src, w, h)
        mem.SelectObject(bmp)
        try:
            # 2 = PW_RENDERFULLCONTENT: vẽ được cả Chrome, app dùng GPU.
            ok = ctypes.windll.user32.PrintWindow(hwnd, mem.GetSafeHdc(), 2)
            info = bmp.GetInfo()
            raw = bmp.GetBitmapBits(True)
        finally:
            win32gui.DeleteObject(bmp.GetHandle())
            mem.DeleteDC()
            src.DeleteDC()
            win32gui.ReleaseDC(hwnd, hdc)
        if not ok:
            return None
        img = Image.frombuffer("RGB", (info["bmWidth"], info["bmHeight"]),
                               raw, "raw", "BGRX", 0, 1)
        img = img.crop((ox, oy, min(img.width, ox + rect[2]),
                        min(img.height, oy + rect[3])))
        if not img.convert("L").resize((32, 18)).getbbox():
            return None
        return img
    except Exception:
        return None


def focus(kind, value):
    """Trước khi nhấp vào một cửa sổ đang bị che: đưa nó ra trước."""
    if kind != "window":
        return
    import win_control
    try:
        if win_control.foreground() != value:
            win_control.force_foreground(value)
    except Exception:
        pass
