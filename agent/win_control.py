"""Lớp điều khiển Windows: mở app, focus/toggle cửa sổ, phím media, macro phím tắt.

Toàn bộ hàm ở đây đều là đồng bộ (blocking). agent.py gọi chúng qua
run_in_executor để không chặn event loop của websockets.
"""

import base64
import ctypes
import io
import os
import subprocess
import time
from ctypes import wintypes

import psutil
import win32api
import win32con
import win32gui
import win32process
import win32ui

user32 = ctypes.windll.user32

# --------------------------------------------------------------------------
# Bảng mã phím
# --------------------------------------------------------------------------

MEDIA_KEYS = {
    "playpause": 0xB3,
    "next": 0xB0,
    "prev": 0xB1,
    "stop": 0xB2,
    "volup": 0xAF,
    "voldown": 0xAE,
    "mute": 0xAD,
}

MODIFIERS = {
    "ctrl": win32con.VK_CONTROL,
    "control": win32con.VK_CONTROL,
    "alt": win32con.VK_MENU,
    "shift": win32con.VK_SHIFT,
    "win": win32con.VK_LWIN,
    "meta": win32con.VK_LWIN,
    "cmd": win32con.VK_LWIN,
}

NAMED_KEYS = {
    "enter": win32con.VK_RETURN,
    "return": win32con.VK_RETURN,
    "esc": win32con.VK_ESCAPE,
    "escape": win32con.VK_ESCAPE,
    "tab": win32con.VK_TAB,
    "space": win32con.VK_SPACE,
    "backspace": win32con.VK_BACK,
    "delete": win32con.VK_DELETE,
    "del": win32con.VK_DELETE,
    "insert": win32con.VK_INSERT,
    "home": win32con.VK_HOME,
    "end": win32con.VK_END,
    "pageup": win32con.VK_PRIOR,
    "pagedown": win32con.VK_NEXT,
    "up": win32con.VK_UP,
    "down": win32con.VK_DOWN,
    "left": win32con.VK_LEFT,
    "right": win32con.VK_RIGHT,
    "printscreen": win32con.VK_SNAPSHOT,
    "capslock": win32con.VK_CAPITAL,
}
for _i in range(1, 25):
    NAMED_KEYS[f"f{_i}"] = getattr(win32con, f"VK_F{_i}")

# Các phím cần cờ EXTENDEDKEY khi gửi sự kiện
EXTENDED = {
    win32con.VK_UP, win32con.VK_DOWN, win32con.VK_LEFT, win32con.VK_RIGHT,
    win32con.VK_HOME, win32con.VK_END, win32con.VK_PRIOR, win32con.VK_NEXT,
    win32con.VK_INSERT, win32con.VK_DELETE, win32con.VK_LWIN, win32con.VK_SNAPSHOT,
}


def _key_down(vk: int) -> None:
    flags = win32con.KEYEVENTF_EXTENDEDKEY if vk in EXTENDED else 0
    win32api.keybd_event(vk, win32api.MapVirtualKey(vk, 0), flags, 0)


def _key_up(vk: int) -> None:
    flags = win32con.KEYEVENTF_KEYUP
    if vk in EXTENDED:
        flags |= win32con.KEYEVENTF_EXTENDEDKEY
    win32api.keybd_event(vk, win32api.MapVirtualKey(vk, 0), flags, 0)


def tap_key(vk: int) -> None:
    _key_down(vk)
    time.sleep(0.02)
    _key_up(vk)


def press_media(action: str) -> None:
    """Gửi một phím media. Ném KeyError nếu action không hợp lệ."""
    tap_key(MEDIA_KEYS[action])


def parse_hotkey(combo: str):
    """'ctrl+shift+p' -> ([VK_CONTROL, VK_SHIFT], VK_P)."""
    parts = [p.strip().lower() for p in combo.split("+") if p.strip()]
    if not parts:
        raise ValueError("Tổ hợp phím rỗng")
    mods, main = [], None
    for part in parts:
        if part in MODIFIERS:
            vk = MODIFIERS[part]
            if vk not in mods:
                mods.append(vk)
        elif part in NAMED_KEYS:
            main = NAMED_KEYS[part]
        elif len(part) == 1:
            main = win32api.VkKeyScan(part) & 0xFF
        else:
            raise ValueError(f"Không hiểu phím: {part}")
    if main is None:
        raise ValueError(f"Thiếu phím chính trong: {combo}")
    return mods, main


def press_hotkey(combo: str) -> None:
    """Gõ một tổ hợp phím, ví dụ 'ctrl+shift+p' hoặc 'win+d'."""
    mods, main = parse_hotkey(combo)
    for vk in mods:
        _key_down(vk)
    time.sleep(0.01)
    try:
        tap_key(main)
    finally:
        for vk in reversed(mods):
            _key_up(vk)


def press_sequence(combos, gap: float = 0.12) -> None:
    """Gõ lần lượt nhiều tổ hợp, dùng cho macro nhiều bước."""
    for combo in combos:
        press_hotkey(combo)
        time.sleep(gap)


# --------------------------------------------------------------------------
# Cửa sổ & tiến trình
# --------------------------------------------------------------------------

def _pid_of(hwnd: int) -> int:
    try:
        return win32process.GetWindowThreadProcessId(hwnd)[1]
    except Exception:
        return 0


# Cửa sổ của chính Windows mà tiến trình explorer.exe đứng tên: màn hình
# desktop, thanh taskbar. Không bỏ thì ô File Explorer lúc nào cũng thừa một
# "cửa sổ" và luôn sáng xanh dù chưa mở thư mục nào.
_SHELL_CLASSES = {
    "progman", "workerw", "shell_traywnd", "shell_secondarytraywnd",
}


def _is_real_window(hwnd: int) -> bool:
    """Đúng những cửa sổ có nút trên taskbar Windows.

    Quy tắc của taskbar: hiện, không phải tool window, và hoặc không có cửa
    sổ chủ, hoặc có cờ WS_EX_APPWINDOW. Cách cũ bỏ mọi cửa sổ có chủ, nên
    app nào đặt cửa sổ chính dưới một cửa sổ ẩn thì không bao giờ được tính.
    """
    if not win32gui.IsWindowVisible(hwnd):
        return False
    if not win32gui.GetWindowText(hwnd):
        return False
    ex = win32gui.GetWindowLong(hwnd, win32con.GWL_EXSTYLE)
    if ex & win32con.WS_EX_TOOLWINDOW:
        return False
    if win32gui.GetWindow(hwnd, win32con.GW_OWNER) and \
            not ex & win32con.WS_EX_APPWINDOW:
        return False  # hộp thoại Lưu, Mở file... thuộc về cửa sổ chính
    try:
        if win32gui.GetClassName(hwnd).lower() in _SHELL_CLASSES:
            return False
    except Exception:
        pass
    # Bỏ cửa sổ "cloaked" của UWP (ẩn nhưng vẫn tồn tại)
    cloaked = ctypes.c_int(0)
    ctypes.windll.dwmapi.DwmGetWindowAttribute(
        wintypes.HWND(hwnd), 14, ctypes.byref(cloaked), ctypes.sizeof(cloaked)
    )
    return cloaked.value == 0


def _proc_info(pid: int):
    """(tên, đường dẫn exe) viết thường. Tiến trình chạy quyền admin thì
    không đọc được đường dẫn — vẫn còn tên để so."""
    try:
        proc = psutil.Process(pid)
        name = proc.name().lower()
    except Exception:
        return "", ""
    try:
        path = os.path.normpath(proc.exe()).lower()
    except Exception:
        path = ""
    return name, path


def _norm_procs(procs):
    if isinstance(procs, str):
        procs = [procs]
    return {os.path.basename(p).lower() for p in procs if p}


def _norm_dirs(dirs):
    if isinstance(dirs, str):
        dirs = [dirs]
    return tuple(d.lower() for d in dirs if d)


def _matches(name, path, procs, dirs):
    if name in procs:
        return True
    return bool(path) and any(path.startswith(d) for d in dirs)


def window_table():
    """Mọi cửa sổ thật kèm tên và đường dẫn tiến trình, trong MỘT lượt duyệt.

    Trước đây agent gọi windows_of() cho từng app, mỗi lần lại duyệt toàn bộ
    cửa sổ của Windows và hỏi psutil tên tiến trình. Với 63 app thì thành 63
    lượt duyệt mỗi 1,5 giây — đủ để chiếm hết luồng nền và làm nghẽn cả việc
    quét danh mục. Một lượt duy nhất cho kết quả y hệt.

    Cần cả đường dẫn vì game qua launcher không đoán trước được tên tiến
    trình, nhưng biết chắc nó nằm trong thư mục cài của game.
    """
    rows = []
    cache = {}

    def cb(hwnd, _):
        if not _is_real_window(hwnd):
            return True
        pid = _pid_of(hwnd)
        info = cache.get(pid)
        if info is None:
            info = cache[pid] = _proc_info(pid)
        if info[0]:
            rows.append((hwnd, info[0], info[1]))
        return True

    win32gui.EnumWindows(cb, None)
    return rows


def count_windows(table, procs, dirs=()):
    procs, dirs = _norm_procs(procs), _norm_dirs(dirs)
    if not procs and not dirs:
        return 0
    return sum(1 for _, name, path in table if _matches(name, path, procs, dirs))


def windows_in(table, procs, dirs=()):
    """Các hwnd trong bảng đã duyệt sẵn thuộc về app."""
    procs, dirs = _norm_procs(procs), _norm_dirs(dirs)
    if not procs and not dirs:
        return []
    return [hwnd for hwnd, name, path in table
            if _matches(name, path, procs, dirs)]


def windows_of(procs, dirs=()):
    """Danh sách hwnd thuộc về app: theo tên tiến trình hoặc thư mục cài."""
    procs, dirs = _norm_procs(procs), _norm_dirs(dirs)
    if not procs and not dirs:
        return []
    return [hwnd for hwnd, name, path in window_table()
            if _matches(name, path, procs, dirs)]


def _processes(procs, dirs=()):
    procs, dirs = _norm_procs(procs), _norm_dirs(dirs)
    found = []
    if not procs and not dirs:
        return found
    for proc in psutil.process_iter(["name", "exe"]):
        try:
            name = (proc.info["name"] or "").lower()
            path = os.path.normpath(proc.info["exe"]).lower() \
                if proc.info["exe"] else ""
            if _matches(name, path, procs, dirs):
                found.append(proc)
        except (psutil.Error, TypeError, ValueError):
            continue
    return found


def is_running(procs, dirs=()) -> bool:
    return bool(_processes(procs, dirs))


def force_foreground(hwnd: int) -> bool:
    """Đưa cửa sổ lên trước, vượt qua foreground lock của Windows.

    Windows chỉ cho tiến trình đang ở foreground gọi SetForegroundWindow.
    Cách vòng: gắn input thread của mình vào thread foreground hiện tại, đồng
    thời nhấp phím ALT để giải khoá.
    """
    if win32gui.IsIconic(hwnd):
        win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)

    fg = win32gui.GetForegroundWindow()
    if fg == hwnd:
        return True

    cur_tid = win32api.GetCurrentThreadId()
    fg_tid = win32process.GetWindowThreadProcessId(fg)[0] if fg else 0
    tgt_tid = win32process.GetWindowThreadProcessId(hwnd)[0]
    attached = []
    try:
        for tid in {fg_tid, tgt_tid}:
            if tid and tid != cur_tid and user32.AttachThreadInput(cur_tid, tid, True):
                attached.append(tid)
        tap_key(win32con.VK_MENU)  # mẹo nhấp ALT
        user32.AllowSetForegroundWindow(-1)
        win32gui.BringWindowToTop(hwnd)
        win32gui.SetForegroundWindow(hwnd)
        win32gui.SetActiveWindow(hwnd)
    except Exception:
        pass
    finally:
        for tid in attached:
            user32.AttachThreadInput(cur_tid, tid, False)
    return win32gui.GetForegroundWindow() == hwnd


# --------------------------------------------------------------------------
# Từng cửa sổ riêng lẻ (chọn cửa sổ như thanh taskbar)
# --------------------------------------------------------------------------

def window_title(hwnd: int) -> str:
    try:
        return win32gui.GetWindowText(hwnd) or ""
    except Exception:
        return ""


def foreground() -> int:
    try:
        return win32gui.GetForegroundWindow() or 0
    except Exception:
        return 0


def focus_or_minimize(hwnd: int) -> str:
    """Giống bấm vào ô xem trước trên taskbar: cửa sổ đang ở trước thì thu
    nhỏ, còn lại thì đưa lên trước."""
    if not win32gui.IsWindow(hwnd):
        return "gone"
    if foreground() == hwnd and not win32gui.IsIconic(hwnd):
        minimize(hwnd)
        return "minimized"
    force_foreground(hwnd)
    return "focused"


def close_window(hwnd: int) -> str:
    """Đóng đúng một cửa sổ. Chỉ xin đóng lịch sự (như bấm dấu X), không
    giết tiến trình: Chrome còn cửa sổ khác thì vẫn phải sống."""
    if not win32gui.IsWindow(hwnd):
        return "gone"
    win32gui.PostMessage(hwnd, win32con.WM_CLOSE, 0, 0)
    return "closing"


# Tiến trình có cửa sổ nhưng không phải "ứng dụng" để gắn vào ô.
_NOT_AN_APP = {
    "applicationframehost.exe", "textinputhost.exe", "shellexperiencehost.exe",
    "searchhost.exe", "searchapp.exe", "startmenuexperiencehost.exe",
    "lockapp.exe", "systemsettings.exe", "conhost.exe", "openconsole.exe",
    "windowsterminal.exe", "python.exe", "pythonw.exe", "py.exe",
    "hedeckagent.exe", "taskmgr.exe", "rundll32.exe", "dllhost.exe",
}


def describe_exe(path: str) -> str:
    """Tên đẹp của chương trình, lấy từ thông tin phiên bản trong file .exe
    (cái tên Task Manager hiển thị), thiếu thì dùng tên file."""
    try:
        info = win32api.GetFileVersionInfo(path, "\\VarFileInfo\\Translation")
        if info:
            lang, page = info[0]
            for field in ("FileDescription", "ProductName"):
                value = win32api.GetFileVersionInfo(
                    path, f"\\StringFileInfo\\{lang:04x}{page:04x}\\{field}")
                if value and value.strip():
                    return value.strip()
    except Exception:
        pass
    return os.path.splitext(os.path.basename(path))[0].replace("_", " ").title()


def running_programs():
    """Các chương trình đang có cửa sổ, gộp theo file .exe.

    Trả về [{path, exe, windows, title}]. Chỉ có tiến trình đọc được đường
    dẫn mới vào danh sách — không biết đường dẫn thì không mở lại được.
    """
    groups = {}
    for hwnd, name, path in window_table():
        if not path or name in _NOT_AN_APP:
            continue
        if "\\windows\\systemapps\\" in path:
            continue
        g = groups.setdefault(path, {"path": path, "exe": name,
                                     "windows": 0, "title": ""})
        g["windows"] += 1
        if not g["title"]:
            g["title"] = window_title(hwnd)
    return list(groups.values())


def minimize(hwnd: int) -> None:
    win32gui.ShowWindow(hwnd, win32con.SW_MINIMIZE)


def cycle_or_focus(procs, toggle: bool = True, dirs=()) -> str:
    """Focus app. Nếu đang focus rồi thì thu nhỏ (toggle) hoặc xoay vòng cửa sổ.

    Trả về: 'focused' | 'minimized' | 'cycled' | 'not_running'
    """
    hwnds = windows_of(procs, dirs)
    if not hwnds:
        return "not_running"

    fg = win32gui.GetForegroundWindow()
    if fg in hwnds:
        if len(hwnds) > 1:
            nxt = hwnds[(hwnds.index(fg) + 1) % len(hwnds)]
            force_foreground(nxt)
            return "cycled"
        if toggle:
            minimize(fg)
            return "minimized"
    force_foreground(hwnds[0])
    return "focused"


def launch(path: str, args: str = "", workdir: str = "") -> None:
    """Mở một chương trình, shortcut (.lnk), thư mục hoặc URL."""
    # Link launcher (steam://, com.epicgames.launcher://...) và shortcut: để
    # Windows tự mở. Shortcut .lnk đã chứa sẵn tham số của nó, truyền thêm
    # args vào nữa là chạy với tham số bị lặp đôi.
    if "://" in path or path.startswith("shell:"):
        os.startfile(path)
        return
    if path.lower().endswith((".lnk", ".url")):
        os.startfile(path)
        return
    cmd = f'"{path}" {args}'.strip()
    subprocess.Popen(
        cmd,
        shell=True,
        cwd=workdir or os.path.dirname(path) or None,
        creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
    )


def open_or_focus(path: str, procs, args: str = "", workdir: str = "",
                  toggle: bool = True, dirs=(), wait: float = 12) -> str:
    """Hành vi chính của một ô: chưa chạy thì mở, đang chạy thì focus/toggle.

    `procs`/`dirs` cho biết cửa sổ nào là của app. Game mở qua launcher cần
    `wait` dài hơn vì launcher phải khởi động và kiểm tra cập nhật trước.
    """
    known = bool(_norm_procs(procs) or _norm_dirs(dirs))
    result = cycle_or_focus(procs, toggle=toggle, dirs=dirs) if known \
        else "not_running"
    if result != "not_running":
        return result
    launch(path, args, workdir)
    if not known:
        return "launched_no_window"
    # Chờ cửa sổ xuất hiện rồi kéo lên trước
    deadline = time.time() + wait
    while time.time() < deadline:
        time.sleep(0.35 if wait <= 12 else 1.0)
        hwnds = windows_of(procs, dirs)
        if hwnds:
            force_foreground(hwnds[0])
            return "launched"
    return "launched_no_window"


# Tiến trình không bao giờ được giết: explorer.exe vừa là File Explorer vừa
# là taskbar, desktop của Windows. Tắt "File Explorer" chỉ đóng cửa sổ thư mục.
_NEVER_KILL = {"explorer.exe"}


def close_app(procs, grace: float = 3.0, dirs=()) -> str:
    """Đóng app: xin đóng lịch sự trước, hết kiên nhẫn thì cưỡng bức.

    Trả về: 'closed' | 'killed' | 'not_running'
    """
    if _norm_procs(procs) & _NEVER_KILL:
        hwnds = windows_of(procs, dirs)
        for hwnd in hwnds:
            close_window(hwnd)
        return "closed" if hwnds else "not_running"

    if not is_running(procs, dirs):
        return "not_running"

    for hwnd in windows_of(procs, dirs):
        try:
            win32gui.PostMessage(hwnd, win32con.WM_CLOSE, 0, 0)
        except Exception:
            pass

    deadline = time.time() + grace
    while time.time() < deadline:
        if not is_running(procs, dirs):
            return "closed"
        time.sleep(0.25)

    # App còn sống (thường vì có hộp thoại "Lưu thay đổi?"). Cưỡng bức.
    victims = _processes(procs, dirs)
    for proc in victims:
        try:
            proc.terminate()
        except psutil.Error:
            pass
    _, alive = psutil.wait_procs(victims, timeout=2)
    for proc in alive:
        try:
            proc.kill()
        except psutil.Error:
            pass
    return "killed"


# --------------------------------------------------------------------------
# Trích icon
# --------------------------------------------------------------------------

def _hicon_to_image(hicon, size):
    """Vẽ HICON ra ảnh RGBA đúng kích thước yêu cầu."""
    from PIL import Image

    screen = win32gui.GetDC(0)
    hdc = bmp = mem = None
    try:
        hdc = win32ui.CreateDCFromHandle(screen)
        bmp = win32ui.CreateBitmap()
        bmp.CreateCompatibleBitmap(hdc, size, size)
        mem = hdc.CreateCompatibleDC()
        old = mem.SelectObject(bmp)
        mem.FillSolidRect((0, 0, size, size), 0)

        # DrawIconEx co giãn icon cho vừa khung. DrawIcon (không Ex) vẽ ở kích
        # thước gốc tại góc trên trái — đó chính là lý do icon bị nhỏ và lệch.
        win32gui.DrawIconEx(
            mem.GetSafeHdc(), 0, 0, hicon, size, size, 0, None, win32con.DI_NORMAL
        )

        info = bmp.GetInfo()
        img = Image.frombuffer(
            "RGBA", (info["bmWidth"], info["bmHeight"]),
            bmp.GetBitmapBits(True), "raw", "BGRA", 0, 1,
        )
        mem.SelectObject(old)
        return img.copy()
    finally:
        if mem:
            mem.DeleteDC()
        if hdc:
            hdc.DeleteDC()
        if bmp:
            win32gui.DeleteObject(bmp.GetHandle())
        win32gui.ReleaseDC(0, screen)


# Chỉ số danh sách ảnh hệ thống của Windows
SHIL_LARGE, SHIL_SMALL, SHIL_EXTRALARGE, SHIL_SYSSMALL, SHIL_JUMBO = 0, 1, 2, 3, 4
SHIL_ORDER = (SHIL_JUMBO, SHIL_EXTRALARGE, SHIL_LARGE)
SHIL_PIXELS = {SHIL_JUMBO: 256, SHIL_EXTRALARGE: 48, SHIL_LARGE: 32}


def _jumbo_hicon(path):
    """Lấy icon từ danh sách ảnh hệ thống, nơi Windows giữ bản 256px thật.

    PrivateExtractIcons khi không tìm thấy khung đúng cỡ sẽ tự phóng to bản
    nhỏ bằng thuật toán thô — đó là lý do icon bị vỡ. IImageList lấy đúng
    khung gốc mà file .ico có, không nội suy.
    """
    try:
        import pythoncom
        from win32com.shell import shell, shellcon
    except Exception:
        return None, 0

    IID_IImageList = pythoncom.MakeIID("{46EB5926-582E-4017-9FDF-E8998DAA0950}")

    for shil in SHIL_ORDER:
        try:
            info = shell.SHGetFileInfo(
                path, 0, shellcon.SHGFI_SYSICONINDEX | shellcon.SHGFI_ICON
            )
            index = info[0] if isinstance(info, tuple) else info
            if isinstance(index, tuple):
                index = index[0]

            image_list = shell.SHGetImageList(shil, IID_IImageList)
            hicon = image_list.GetIcon(index, 1)  # ILD_TRANSPARENT
            if hicon:
                return hicon, SHIL_PIXELS.get(shil, 32)
        except Exception:
            continue
    return None, 0


def _best_hicon(path, wanted=256):
    """Icon nét nhất có thể, trả về (hicon, kích thước gốc thật).

    Thứ tự ưu tiên: danh sách ảnh hệ thống (có bản 256px thật), rồi
    PrivateExtractIcons dò từ lớn xuống nhỏ, cuối cùng là API cũ.
    """
    hicon, native = _jumbo_hicon(path)
    if hicon and native >= 48:
        return hicon, native
    if hicon:
        try:
            win32gui.DestroyIcon(hicon)
        except Exception:
            pass

    for size in (256, 128, 96, 64, 48, 32):
        if size > wanted:
            continue
        try:
            result = win32gui.PrivateExtractIcons(path, 0, size, size, 1, 0)
            handles = result[0] if isinstance(result, tuple) else result
            if handles:
                for extra in handles[1:]:
                    win32gui.DestroyIcon(extra)
                return handles[0], size
        except Exception:
            continue

    try:
        large, small = win32gui.ExtractIconEx(path, 0)
        handles = large or small
        if handles:
            for extra in (large or [])[1:] + (small or [])[1:]:
                win32gui.DestroyIcon(extra)
            return handles[0], 32
    except Exception:
        pass
    return None, 0


def _from_resources(path, size):
    """Ưu tiên số một: đọc thẳng tài nguyên icon trong file.

    Đây là nguồn duy nhất cho biết độ phân giải THẬT. Các API khác âm thầm
    phóng to bản nhỏ rồi trả về, khiến ta tưởng có icon lớn mà thực ra là ảnh
    mờ đã bị kéo dãn.
    """
    try:
        import icon_source
    except ImportError:
        return None

    target = path
    # Với shortcut .lnk thì phải soi file .exe mà nó trỏ tới
    if path.lower().endswith(".lnk"):
        try:
            import win32com.client
            shell = win32com.client.Dispatch("WScript.Shell")
            target = shell.CreateShortCut(path).TargetPath or path
        except Exception:
            pass

    result = icon_source.best_source(target)
    if not result:
        return None
    img, native, origin = result
    return img, native, origin


def extract_icon_png(path: str, size: int = 256):
    """Lấy icon của file .exe, trả về chuỗi base64 PNG vuông (hoặc None).

    Ảnh được cắt sạch viền trong suốt rồi căn giữa lại, nên khi hiển thị trên
    điện thoại nó lấp đầy ô thay vì trôi về một góc.
    """
    try:
        from PIL import Image
    except ImportError:
        return None

    # Shortcut .url của Steam/Epic trỏ icon vào một file .ico rời.
    if path.lower().endswith(".ico"):
        try:
            img = Image.open(path)
            sizes = sorted(img.info.get("sizes") or [img.size])
            if hasattr(img, "ico") and sizes:
                img = img.ico.getimage(sizes[-1])
            img = img.convert("RGBA")
            return _finish_icon(img, max(img.size), size)
        except Exception:
            return None

    # Nguồn nét nhất trước
    direct = _from_resources(path, size)
    if direct:
        img, native, _origin = direct
        return _finish_icon(img, native, size)

    hicon, native = _best_hicon(path, size)
    if not hicon:
        return None

    try:
        # Vẽ ở đúng kích thước Windows trả về. Nếu nhỏ hơn mong muốn thì để
        # Pillow phóng to bằng LANCZOS — mượt hơn hẳn cách GDI phóng to.
        img = _hicon_to_image(hicon, native)
    except Exception:
        return None
    finally:
        try:
            win32gui.DestroyIcon(hicon)
        except Exception:
            pass

    return _finish_icon(img, native, size)


def _finish_icon(img, native, size):
    """Cắt lề thừa, căn giữa trong khung vuông, xuất ra base64 PNG."""
    from PIL import Image

    try:
        from PIL import ImageChops

        # Không phóng quá hai lần độ phân giải gốc: thêm pixel mà không thêm
        # chi tiết chỉ làm file nặng.
        size = min(size, max(native * 2, 64))

        # Cắt bỏ phần thừa quanh icon. Ưu tiên kênh alpha; nếu icon không mang
        # thông tin trong suốt thì so với màu ở góc để tìm vùng có nội dung.
        alpha = img.getchannel("A")
        lo, hi = alpha.getextrema()
        box = None
        if hi > 0 and lo != hi:
            box = alpha.getbbox()
        if box is None:
            rgb = img.convert("RGB")
            corner = rgb.getpixel((0, 0))
            flat = Image.new("RGB", rgb.size, corner)
            box = ImageChops.difference(rgb, flat).getbbox()
        if box:
            img = img.crop(box)

        # Đặt vào khung vuông để tỉ lệ không méo, nội dung nằm chính giữa
        side = max(img.size)
        if side <= 0:
            return None
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
        if side != size:
            square = square.resize((size, size), Image.LANCZOS)
            # Phóng to nhiều thì LANCZOS làm mềm cạnh. Làm nét lại vừa phải để
            # icon nhỏ vẫn rõ ràng khi hiện lớn trên điện thoại.
            if native and size >= native * 2:
                from PIL import ImageFilter
                square = square.filter(
                    ImageFilter.UnsharpMask(radius=1.6, percent=95, threshold=2)
                )

        buf = io.BytesIO()
        square.save(buf, format="PNG", optimize=True)
        return base64.b64encode(buf.getvalue()).decode("ascii"), native
    except Exception:
        return None
