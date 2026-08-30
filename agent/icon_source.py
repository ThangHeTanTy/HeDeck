"""Lấy icon ở độ phân giải gốc lớn nhất mà một file .exe thật sự có.

Vì sao cần module riêng: các API tiện dụng của Windows (`PrivateExtractIcons`,
`ExtractIconEx`, danh sách ảnh hệ thống) đều **tự phóng to** khi không tìm thấy
khung ảnh đúng cỡ bạn xin, và không hề báo là đã phóng. Xin 256px từ một file
chỉ có 32px thì nhận về ảnh 256px mờ nhoè, tưởng là nét.

Ở đây ta đọc thẳng tài nguyên RT_GROUP_ICON và RT_ICON trong file, xem file có
những cỡ nào, rồi lấy đúng cỡ lớn nhất. Không phóng to, không đoán.
"""

import io
import os
import struct

RT_ICON = 3
RT_GROUP_ICON = 14
LOAD_LIBRARY_AS_DATAFILE = 0x00000002


def _group_icon_entries(data: bytes):
    """Đọc bảng mục lục icon (RT_GROUP_ICON) -> [(rộng, cao, id tài nguyên)]."""
    if len(data) < 6:
        return []
    _, res_type, count = struct.unpack("<HHH", data[:6])
    if res_type != 1:  # 1 là icon, 2 là con trỏ chuột
        return []

    entries = []
    offset = 6
    for _ in range(count):
        if offset + 14 > len(data):
            break
        width, height = data[offset], data[offset + 1]
        res_id = struct.unpack("<H", data[offset + 12:offset + 14])[0]
        # 0 trong ICO nghĩa là 256
        entries.append((width or 256, height or 256, res_id))
        offset += 14
    return entries


def _wrap_as_ico(raw: bytes, width: int, height: int) -> bytes:
    """Bọc dữ liệu một ảnh icon thành file .ico hoàn chỉnh trong bộ nhớ.

    Tài nguyên RT_ICON chứa ảnh trần, có thể là PNG hoặc bitmap DIB. Bọc lại
    thành .ico rồi để Pillow đọc thì xử lý được cả hai mà không cần tự giải mã.
    """
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack(
        "<BBBBHHII",
        0 if width >= 256 else width,
        0 if height >= 256 else height,
        0, 0, 1, 32, len(raw), 22,
    )
    return header + entry + raw


def largest_icon(path: str):
    """Trả về (ảnh PIL, cạnh gốc) của icon lớn nhất trong file, hoặc None.

    Không phóng to gì cả — cạnh trả về là độ phân giải thật.
    """
    try:
        import win32api
        from PIL import Image
    except ImportError:
        return None

    if not path or not os.path.exists(path):
        return None

    hmod = None
    try:
        hmod = win32api.LoadLibraryEx(path, 0, LOAD_LIBRARY_AS_DATAFILE)
    except Exception:
        return None

    try:
        try:
            groups = win32api.EnumResourceNames(hmod, RT_GROUP_ICON)
        except Exception:
            groups = []
        if not groups:
            return None

        # Nhóm đầu tiên là icon chính của chương trình
        try:
            group_data = win32api.LoadResource(hmod, RT_GROUP_ICON, groups[0])
        except Exception:
            return None

        entries = _group_icon_entries(group_data)
        if not entries:
            return None

        best = None
        for width, height, res_id in sorted(entries, key=lambda e: -e[0]):
            try:
                raw = win32api.LoadResource(hmod, RT_ICON, res_id)
            except Exception:
                continue
            try:
                img = Image.open(io.BytesIO(_wrap_as_ico(raw, width, height)))
                img.load()
                img = img.convert("RGBA")
            except Exception:
                continue
            # Kích thước thật của ảnh đọc được mới là con số đáng tin
            side = min(img.size)
            if side > 0:
                best = (img, side)
                break

        return best
    finally:
        if hmod:
            try:
                win32api.FreeLibrary(hmod)
            except Exception:
                pass


def sizes_available(path: str):
    """Liệt kê các cỡ icon file này có. Dùng để chẩn đoán."""
    try:
        import win32api
    except ImportError:
        return []
    if not path or not os.path.exists(path):
        return []

    hmod = None
    try:
        hmod = win32api.LoadLibraryEx(path, 0, LOAD_LIBRARY_AS_DATAFILE)
        groups = win32api.EnumResourceNames(hmod, RT_GROUP_ICON)
        if not groups:
            return []
        data = win32api.LoadResource(hmod, RT_GROUP_ICON, groups[0])
        return sorted({w for w, _, _ in _group_icon_entries(data)}, reverse=True)
    except Exception:
        return []
    finally:
        if hmod:
            try:
                win32api.FreeLibrary(hmod)
            except Exception:
                pass


# --------------------------------------------------------------------------
# Tìm ảnh logo đi kèm trong thư mục cài đặt
# --------------------------------------------------------------------------

ASSET_DIRS = ("", "Assets", "assets", "resources", "res", "icons", "images")

# Tên file được coi là logo của chương trình
ASSET_NAMES = {
    "icon.png", "icon.ico", "logo.png", "logo.ico",
    "app.png", "app.ico", "appicon.png", "appicon.ico",
    "application.png", "application.ico",
}

# Không bao giờ soi những thư mục dùng chung của hệ điều hành. Chúng chứa hàng
# nghìn ảnh không liên quan, và quét ở đó từng khiến Command Prompt nhận nhầm
# một ảnh 1920x1080 làm icon.
SYSTEM_DIRS = (
    "\\windows\\system32", "\\windows\\syswow64", "\\windows\\winsxs",
    "\\windows\\systemapps", "\\windows\\immersivecontrolpanel",
)

MAX_SIDE = 1024          # lớn hơn nữa gần như chắc chắn không phải icon
SQUARE_TOLERANCE = 1.05  # icon phải vuông; ảnh nền thì không


def _is_system_path(path: str) -> bool:
    low = path.lower().replace("/", "\\")
    if low.rstrip("\\").endswith("\\windows"):
        return True
    return any(marker in low for marker in SYSTEM_DIRS)


def sidecar_image(exe_path: str, min_side: int = 128):
    """Tìm ảnh logo độ phân giải cao nằm cạnh file thực thi.

    Nhiều ứng dụng hiện đại (Electron, Store) đóng gói logo PNG lớn trong thư
    mục cài đặt, nét hơn hẳn icon nhúng trong .exe.

    Chỉ nhận file thoả **cả bốn** điều kiện, vì nhận nhầm một ảnh bất kỳ làm
    icon còn tệ hơn là icon hơi mờ:

    - không nằm trong thư mục hệ thống dùng chung
    - tên file trùng tên chương trình, hoặc là tên logo quy ước
    - ảnh vuông
    - cạnh trong khoảng hợp lý

    Trả về (ảnh PIL, cạnh) hoặc None.
    """
    try:
        from PIL import Image
    except ImportError:
        return None

    if not exe_path or not os.path.exists(exe_path):
        return None

    root = os.path.dirname(exe_path)
    if _is_system_path(root):
        return None

    stem = os.path.splitext(os.path.basename(exe_path))[0].lower()
    best = None

    for sub in ASSET_DIRS:
        folder = os.path.join(root, sub) if sub else root
        if not os.path.isdir(folder) or _is_system_path(folder):
            continue
        try:
            names = os.listdir(folder)
        except OSError:
            continue

        for name in names:
            low = name.lower()
            if not low.endswith((".png", ".ico")):
                continue

            # Tên phải liên quan tới chương trình, không nhận bừa
            name_stem = os.path.splitext(low)[0]
            if not (name_stem == stem
                    or name_stem.startswith(stem + "_")
                    or name_stem.startswith(stem + "-")
                    or low in ASSET_NAMES):
                continue

            full = os.path.join(folder, name)
            try:
                if os.path.getsize(full) > 8 * 1024 * 1024:
                    continue
                img = Image.open(full)
                img.load()
            except Exception:
                continue

            w, h = img.size
            if w <= 0 or h <= 0:
                continue
            # Ảnh nền và ảnh chụp màn hình đều không vuông
            if max(w, h) / min(w, h) > SQUARE_TOLERANCE:
                continue
            side = min(w, h)
            if side < min_side or side > MAX_SIDE:
                continue

            if best is None or side > best[1]:
                best = (img.convert("RGBA"), side)

    return best


def best_source(exe_path: str):
    """Nguồn icon nét nhất: tài nguyên trong .exe, hoặc ảnh logo đi kèm.

    Trả về (ảnh PIL, cạnh gốc, nguồn) — `nguồn` là 'exe' hoặc 'file' để log.
    Khi hai nguồn xấp xỉ nhau thì ưu tiên tài nguyên trong .exe, vì đó chắc
    chắn là icon chính thức của chương trình.
    """
    from_exe = largest_icon(exe_path)
    from_file = sidecar_image(exe_path)

    if from_exe and from_file:
        # Ảnh rời phải hơn hẳn thì mới thắng, tránh đổi icon vì chênh vài pixel
        return (from_file + ("file",)) if from_file[1] > from_exe[1] * 1.5 \
            else (from_exe + ("exe",))
    if from_exe:
        return from_exe + ("exe",)
    if from_file:
        return from_file + ("file",)
    return None
