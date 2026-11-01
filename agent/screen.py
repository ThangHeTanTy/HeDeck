"""Chụp màn hình gửi về điện thoại, hiện phía sau touchpad.

Điện thoại xin từng khung một: nhận xong khung này mới xin khung sau. Nhờ vậy
mạng chậm (4G, ra ngoài qua Tailscale) tự giảm số khung, không dồn ứ.

Mỗi gói nhị phân gồm 16 byte đầu rồi tới ảnh JPEG (có thể trống):
    "HDS1"  4 byte
    rộng, cao của ảnh       2 × uint16
    rộng, cao của màn hình  2 × uint16
    toạ độ con trỏ          2 × int16  (theo pixel màn hình)
Màn hình không đổi so với khung trước thì không gửi ảnh, chỉ gửi toạ độ con
trỏ — đứng yên trên desktop gần như không tốn dữ liệu.
"""

import hashlib
import io
import struct

HEADER = struct.Struct(">4sHHHHhh")
MAGIC = b"HDS1"

QUALITY = {"low": (640, 45), "mid": (960, 60), "high": (1280, 72)}

_dpi_done = False


def _dpi_aware():
    """Chụp đúng độ phân giải thật thay vì bản Windows thu nhỏ theo DPI."""
    global _dpi_done
    if _dpi_done:
        return
    _dpi_done = True
    try:
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        pass


def _cursor():
    try:
        import win32api
        return win32api.GetCursorPos()
    except Exception:
        return (-1, -1)


def capture(level="mid", last_digest=None):
    """Chụp màn hình chính. Trả về (gói nhị phân, dấu vân tay ảnh).

    Ảnh giống lần trước (cùng last_digest) thì gói chỉ có toạ độ con trỏ.
    """
    from PIL import Image, ImageGrab

    _dpi_aware()
    max_w, quality = QUALITY.get(level, QUALITY["mid"])
    shot = ImageGrab.grab()
    sw, sh = shot.size
    cx, cy = _cursor()

    # So bản thu nhỏ cho rẻ: màn hình đứng yên thì khỏi nén và gửi lại ảnh.
    digest = hashlib.blake2b(
        shot.convert("L").resize((64, 36)).tobytes(), digest_size=12).digest()
    cx, cy = (v if -32768 <= v <= 32767 else -1 for v in (cx, cy))
    if digest == last_digest:
        return HEADER.pack(MAGIC, 0, 0, sw, sh, cx, cy), digest

    if sw > max_w:
        shot = shot.resize((max_w, round(sh * max_w / sw)), Image.BILINEAR)
    buf = io.BytesIO()
    shot.convert("RGB").save(buf, "JPEG", quality=quality)
    fw, fh = shot.size
    head = HEADER.pack(MAGIC, fw, fh, sw, sh, cx, cy)
    return head + buf.getvalue(), digest
