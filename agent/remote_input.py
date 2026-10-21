"""Chuột và bàn phím từ xa: touchpad và bàn phím ảo trên điện thoại.

Dùng SendInput — cùng đường với chuột/phím thật, nên mọi app đều nhận, kể cả
game. Hàm nào ở đây cũng rất nhanh (micro giây), agent gọi thẳng trong vòng
sự kiện thay vì đẩy sang luồng khác: đẩy sang luồng khác thì các lệnh có thể
chạy lộn thứ tự, ví dụ nhấp chuột chạy trước khi con trỏ kịp di chuyển tới.
"""

import ctypes

user32 = ctypes.windll.user32

INPUT_MOUSE = 0
INPUT_KEYBOARD = 1

MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_WHEEL = 0x0800
MOUSEEVENTF_HWHEEL = 0x1000

KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004

WHEEL_DELTA = 120

BUTTONS = {
    "left": (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP),
    "right": (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP),
    "middle": (MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP),
}

# Giới hạn để một gói tin hỏng hay cố ý không làm loạn máy: con trỏ không
# nhảy quá xa mỗi lần, cuộn không quá nhiều nấc, chữ gõ không quá dài.
MAX_MOVE = 400
MAX_WHEEL = 20
MAX_TEXT = 500

# Kiểu có độ rộng cố định, đúng như Windows định nghĩa (LONG/DWORD 4 byte,
# WORD 2 byte). Không dùng ctypes.wintypes vì trên một số nền tảng LONG dài 8
# byte, làm cấu trúc INPUT sai kích thước và SendInput âm thầm bỏ qua.
LONG = ctypes.c_int32
DWORD = ctypes.c_uint32
WORD = ctypes.c_uint16
ULONG_PTR = ctypes.c_size_t


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", LONG), ("dy", LONG),
                ("mouseData", DWORD), ("dwFlags", DWORD),
                ("time", DWORD), ("dwExtraInfo", ULONG_PTR)]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", WORD), ("wScan", WORD),
                ("dwFlags", DWORD), ("time", DWORD),
                ("dwExtraInfo", ULONG_PTR)]


class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [("uMsg", DWORD), ("wParamL", WORD),
                ("wParamH", WORD)]


class _INPUTUNION(ctypes.Union):
    _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT), ("hi", HARDWAREINPUT)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", DWORD), ("u", _INPUTUNION)]


def _send(*inputs):
    arr = (INPUT * len(inputs))(*inputs)
    user32.SendInput(len(inputs), arr, ctypes.sizeof(INPUT))


def _mouse(flags, dx=0, dy=0, data=0):
    inp = INPUT(type=INPUT_MOUSE)
    # mouseData là số có dấu (cuộn xuống là âm) nhưng khai báo DWORD.
    inp.u.mi = MOUSEINPUT(dx, dy, data & 0xFFFFFFFF, flags, 0, 0)
    return inp


def _clamp(value, limit):
    return max(-limit, min(limit, int(value)))


def move(dx, dy):
    dx, dy = _clamp(dx, MAX_MOVE), _clamp(dy, MAX_MOVE)
    if dx or dy:
        _send(_mouse(MOUSEEVENTF_MOVE, dx, dy))


def button(name, action="click"):
    """action: click | double | down | up."""
    if name not in BUTTONS:
        raise ValueError(f"Nút chuột lạ: {name}")
    down, up = BUTTONS[name]
    if action == "down":
        _send(_mouse(down))
    elif action == "up":
        _send(_mouse(up))
    elif action == "double":
        _send(_mouse(down), _mouse(up), _mouse(down), _mouse(up))
    elif action == "click":
        _send(_mouse(down), _mouse(up))
    else:
        raise ValueError(f"Thao tác chuột lạ: {action}")


def scroll(dy=0, dx=0):
    """dy, dx tính bằng nấc. dy dương là cuộn lên (như con lăn đẩy ra xa)."""
    dy, dx = _clamp(dy, MAX_WHEEL), _clamp(dx, MAX_WHEEL)
    events = []
    if dy:
        events.append(_mouse(MOUSEEVENTF_WHEEL, data=dy * WHEEL_DELTA))
    if dx:
        events.append(_mouse(MOUSEEVENTF_HWHEEL, data=dx * WHEEL_DELTA))
    if events:
        _send(*events)


def type_text(text):
    """Gõ chữ dạng Unicode: tiếng Việt có dấu, emoji... gõ đúng nguyên văn,
    không phụ thuộc bộ gõ hay bố cục bàn phím đang bật trên máy tính."""
    events = []
    for ch in str(text)[:MAX_TEXT]:
        if ch == "\n":
            events += [_key(0x0D, 0), _key(0x0D, KEYEVENTF_KEYUP)]
            continue
        data = ch.encode("utf-16-le")
        for i in range(0, len(data), 2):  # ký tự ngoài BMP thành 2 đơn vị
            unit = int.from_bytes(data[i:i + 2], "little")
            events += [_key(0, KEYEVENTF_UNICODE, unit),
                       _key(0, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP, unit)]
    if events:
        _send(*events)


def _key(vk, flags, scan=0):
    inp = INPUT(type=INPUT_KEYBOARD)
    inp.u.ki = KEYBDINPUT(vk, scan, flags, 0, 0)
    return inp
