"""Chụp màn hình gửi về điện thoại, hiện phía sau touchpad.

Điện thoại xin từng khung một: nhận xong khung này mới xin khung sau. Nhờ vậy
mạng chậm (4G, ra ngoài qua Tailscale) tự giảm số khung, không dồn ứ.

Phóng to: điện thoại gửi kèm mức zoom, agent cắt đúng vùng quanh con trỏ rồi
mới thu nhỏ — vùng phóng to được gửi ở độ phân giải gốc nên vẫn nét, không
phải phóng một ảnh nhỏ lên. Vùng cắt đứng yên, chỉ trượt theo khi con trỏ đi
sát mép (như kính lúp của Windows), để màn hình khỏi rung theo từng nhích chuột.

Con trỏ không vẽ vào ảnh: agent gửi toạ độ và loại con trỏ (mũi tên, chữ I,
bàn tay...), điện thoại tự vẽ — luôn sắc nét, và di chuột trên desktop đứng yên
không phải gửi lại cả ảnh.

Mỗi gói nhị phân gồm 25 byte đầu rồi tới ảnh JPEG (có thể trống):
    "HDS2"                      4 byte
    rộng, cao của ảnh           2 × uint16
    rộng, cao của màn hình      2 × uint16
    toạ độ con trỏ              2 × int16  (pixel màn hình, -1 nếu ẩn)
    vùng cắt x, y, rộng, cao    4 × uint16 (pixel màn hình)
    loại con trỏ                uint8      (xem CURSOR_KINDS)
Màn hình (vùng cắt) không đổi so với khung trước thì không gửi ảnh, chỉ gửi
phần đầu — đứng yên gần như không tốn dữ liệu.
"""

import hashlib
import io
import struct

HEADER = struct.Struct(">4sHHHHhhHHHHB")
MAGIC = b"HDS2"

QUALITY = {
    "low": (640, 45),
    "mid": (960, 60),
    "high": (1280, 72),
    "max": (1920, 82),
}

# Mã loại con trỏ gửi cho điện thoại. 0: đang ẩn (game, video toàn màn hình).
# Con trỏ riêng của từng app không nhận ra được thì coi như mũi tên.
CURSOR_KINDS = {
    32512: 1,   # IDC_ARROW
    32513: 2,   # IDC_IBEAM
    32649: 3,   # IDC_HAND
    32514: 4,   # IDC_WAIT
    32650: 5,   # IDC_APPSTARTING
    32515: 6,   # IDC_CROSS
    32646: 7,   # IDC_SIZEALL
    32644: 8,   # IDC_SIZEWE
    32645: 9,   # IDC_SIZENS
    32642: 10,  # IDC_SIZENWSE
    32643: 11,  # IDC_SIZENESW
    32648: 12,  # IDC_NO
}
ARROW = 1

# Con trỏ tới sát mép vùng phóng to (trong khoảng này) thì vùng trượt theo.
EDGE = 0.18

_dpi_done = False
_cursor_handles = None


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
    """(x, y, loại) của con trỏ. Con trỏ hệ thống dùng chung một handle cho
    mọi app, nên so handle là biết đang là mũi tên, chữ I hay bàn tay."""
    global _cursor_handles
    try:
        import win32gui
        if _cursor_handles is None:
            _cursor_handles = {}
            for idc, kind in CURSOR_KINDS.items():
                try:
                    _cursor_handles[win32gui.LoadCursor(0, idc)] = kind
                except Exception:
                    pass
        flags, handle, (x, y) = win32gui.GetCursorInfo()
        if not flags & 1:            # CURSOR_SHOWING
            return x, y, 0
        return x, y, _cursor_handles.get(handle, ARROW)
    except Exception:
        pass
    try:
        import win32api
        x, y = win32api.GetCursorPos()
        return x, y, ARROW
    except Exception:
        return -1, -1, 0


def _crop(sw, sh, zoom, cx, cy, prev):
    """Vùng cần gửi (x, y, rộng, cao) cho mức zoom, bám theo con trỏ."""
    if zoom <= 1.01:
        return (0, 0, sw, sh)
    cw, ch = max(1, round(sw / zoom)), max(1, round(sh / zoom))
    if cx < 0 or cy < 0:
        cx, cy = sw // 2, sh // 2
    if prev and prev[2] == cw and prev[3] == ch:
        x0, y0 = prev[0], prev[1]
        mx, my = cw * EDGE, ch * EDGE
        if cx < x0 + mx:
            x0 = cx - mx
        elif cx > x0 + cw - mx:
            x0 = cx - cw + mx
        if cy < y0 + my:
            y0 = cy - my
        elif cy > y0 + ch - my:
            y0 = cy - ch + my
    else:
        x0, y0 = cx - cw / 2, cy - ch / 2
    x0 = int(min(max(0, x0), sw - cw))
    y0 = int(min(max(0, y0), sh - ch))
    return (x0, y0, cw, ch)


def capture(level="mid", zoom=1.0, prev_crop=None, last_digest=None):
    """Chụp màn hình chính. Trả về (gói nhị phân, dấu vân tay, vùng cắt).

    Vùng cắt giống lần trước và nội dung không đổi (cùng last_digest) thì gói
    chỉ có phần đầu: toạ độ và loại con trỏ.
    """
    from PIL import Image, ImageGrab

    _dpi_aware()
    max_w, quality = QUALITY.get(level, QUALITY["mid"])
    try:
        zoom = min(4.0, max(1.0, float(zoom)))
    except (TypeError, ValueError):
        zoom = 1.0
    shot = ImageGrab.grab()
    sw, sh = shot.size
    cx, cy, kind = _cursor()
    cx, cy = (v if -32768 <= v <= 32767 else -1 for v in (cx, cy))
    crop = _crop(sw, sh, zoom, cx, cy, prev_crop)
    x0, y0, cw, ch = crop
    if crop != (0, 0, sw, sh):
        shot = shot.crop((x0, y0, x0 + cw, y0 + ch))

    # So bản thu nhỏ cho rẻ: vùng đứng yên thì khỏi nén và gửi lại ảnh.
    digest = hashlib.blake2b(
        shot.convert("L").resize((64, 36)).tobytes() + repr(crop).encode(),
        digest_size=12).digest()

    def head(fw, fh):
        return HEADER.pack(MAGIC, fw, fh, sw, sh, cx, cy, x0, y0, cw, ch, kind)

    if digest == last_digest:
        return head(0, 0), digest, crop

    if cw > max_w:
        shot = shot.resize((max_w, round(ch * max_w / cw)), Image.BILINEAR)
    buf = io.BytesIO()
    shot.convert("RGB").save(buf, "JPEG", quality=quality)
    fw, fh = shot.size
    return head(fw, fh) + buf.getvalue(), digest, crop
