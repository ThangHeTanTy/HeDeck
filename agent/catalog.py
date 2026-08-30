"""Danh mục ứng dụng của agent.

Nguyên tắc bảo mật: điện thoại chỉ gửi `app_id`. Đường dẫn thật nằm ở đây,
trên laptop. Không có lệnh nào cho phép điện thoại chạy một đường dẫn tuỳ ý.
"""

import hashlib
import json
import os
from pathlib import Path

import win_control

CONFIG_DIR = Path(os.path.expanduser("~")) / ".hedeck"
CATALOG_FILE = CONFIG_DIR / "catalog.json"

# Tăng số này mỗi khi đổi cách trích icon. Agent thấy catalog.json cũ hơn sẽ
# tự quét lại, khỏi phải nhớ bấm "Quét lại ứng dụng" bằng tay.
CATALOG_VERSION = 9

SKIP_WORDS = (
    "uninstall", "gỡ cài đặt", "readme", "help", "documentation", "license",
    "release notes", "website", "báo lỗi", "repair", "safe mode",
)

START_MENUS = [
    Path(os.environ.get("APPDATA", "")) / "Microsoft/Windows/Start Menu/Programs",
    Path(os.environ.get("PROGRAMDATA", "")) / "Microsoft/Windows/Start Menu/Programs",
]


def _app_id(name: str, target: str) -> str:
    return hashlib.sha1(f"{name}|{target}".lower().encode()).hexdigest()[:12]


def _make_shell():
    """Một đối tượng WScript.Shell dùng chung cho cả lượt quét.

    Tạo mới cho từng shortcut là cách cũ, tốn một vòng COM mỗi lần và chậm
    thấy rõ khi Start Menu có vài trăm file.
    """
    try:
        import win32com.client
        return win32com.client.Dispatch("WScript.Shell")
    except Exception as exc:
        print(f"  Không tạo được WScript.Shell: {exc}", flush=True)
        return None


def _resolve_lnk(shell, lnk_path: Path):
    """Đọc shortcut .lnk -> (target, args, workdir)."""
    if shell is None:
        return "", "", ""
    try:
        sc = shell.CreateShortCut(str(lnk_path))
        return sc.TargetPath or "", sc.Arguments or "", sc.WorkingDirectory or ""
    except Exception:
        return "", "", ""


def scan_start_menu(with_icons: bool = False):
    """Quét Start Menu, trả về danh sách app đã khử trùng lặp.

    Hàm này chạy ở luồng nền, nên phải tự khởi tạo COM cho luồng đó. Thiếu
    bước này thì đọc shortcut và lấy icon đều hỏng.
    """
    import pythoncom

    try:
        pythoncom.CoInitialize()
    except Exception:
        pass

    apps, seen = [], set()
    print("  Bắt đầu quét Start Menu...", flush=True)
    try:
        return _scan(apps, seen, with_icons)
    finally:
        try:
            pythoncom.CoUninitialize()
        except Exception:
            pass


def _scan(apps, seen, with_icons):
    import time

    shell = _make_shell()
    started = time.time()
    checked = 0
    for root in START_MENUS:
        if not root.exists():
            continue
        for dirpath, _, files in os.walk(root):
            for fname in files:
                if not fname.lower().endswith(".lnk"):
                    continue
                name = fname[:-4]
                low = name.lower()
                if any(w in low for w in SKIP_WORDS):
                    continue
                lnk = Path(dirpath) / fname
                checked += 1
                # Nhịp báo tiến độ: kẹt ở đâu là thấy ngay, không phải đoán.
                if checked % 25 == 0:
                    print(f"    ...đã xem {checked} shortcut, "
                          f"nhận {len(apps)} app "
                          f"({time.time() - started:.1f}s)", flush=True)
                target, args, workdir = _resolve_lnk(shell, lnk)
                if not target or not target.lower().endswith(".exe"):
                    continue
                if not os.path.exists(target):
                    continue
                key = target.lower()
                if key in seen:
                    continue
                seen.add(key)
                apps.append({
                    "id": _app_id(name, target),
                    "name": name,
                    "path": str(lnk),          # mở qua .lnk cho đúng tham số
                    "exe": os.path.basename(target),
                    "args": args,
                    "workdir": workdir,
                    "target": target,   # đường dẫn .exe, dùng để lấy icon
                    "icon": None,
                    "icon_native": 0,
                })
                if with_icons:
                    # Một icon hỏng không được phép làm chết cả lượt quét.
                    try:
                        result = win_control.extract_icon_png(target)
                        if result:
                            apps[-1]["icon"], apps[-1]["icon_native"] = result
                    except Exception as exc:
                        print(f"    (bỏ qua icon {name}: {exc})", flush=True)
    apps.sort(key=lambda a: a["name"].lower())
    print(f"  Quét xong: {len(apps)} ứng dụng từ {checked} shortcut "
          f"({time.time() - started:.1f}s)", flush=True)
    return apps


def attach_icons(apps, on_progress=None):
    """Trích icon cho danh sách đã quét. Chạy sau, vì đây là phần chậm nhất.

    Trả về số icon lấy được. Lỗi ở một app không ảnh hưởng các app khác.
    """
    import pythoncom

    try:
        pythoncom.CoInitialize()
    except Exception:
        pass

    done = 0
    small = []
    try:
        for index, app in enumerate(apps):
            if app.get("icon"):
                done += 1
                continue
            target = app.get("target") or app.get("path")
            try:
                result = win_control.extract_icon_png(target)
                if result:
                    app["icon"], app["icon_native"] = result
                    if app["icon_native"] < 64:
                        small.append(f"{app['name']} ({app['icon_native']}px)")
                    done += 1
            except Exception as exc:
                print(f"    (bỏ qua icon {app['name']}: {exc})", flush=True)
            if on_progress and index % 10 == 9:
                on_progress(index + 1, len(apps))
    finally:
        try:
            pythoncom.CoUninitialize()
        except Exception:
            pass
    if small:
        print(f"    ({len(small)} app chỉ có icon nhỏ: "
              f"{', '.join(small[:5])}"
              f"{'...' if len(small) > 5 else ''})", flush=True)
    return done


def load(rescan: bool = False):
    """Đọc catalog từ đĩa. Tự quét lại nếu chưa có, bị ép, hoặc đã lỗi thời."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    stale = False

    if CATALOG_FILE.exists() and not rescan:
        try:
            data = json.loads(CATALOG_FILE.read_text(encoding="utf-8"))
            if data.get("apps"):
                if data.get("version") == CATALOG_VERSION:
                    return data["apps"]
                stale = True
        except Exception:
            pass

    if stale:
        print("  Danh mục icon đã lỗi thời, đang quét lại...", flush=True)

    apps = scan_start_menu(with_icons=False)
    save(apps)
    return apps


def save(apps) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CATALOG_FILE.write_text(
        json.dumps({"version": CATALOG_VERSION, "apps": apps},
                   ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def public_view(apps):
    """Bản gửi cho điện thoại: không lộ đường dẫn tuyệt đối."""
    return [
        {
            "id": a["id"],
            "name": a["name"],
            "exe": a["exe"],
            "icon": a.get("icon"),
            # Kích thước gốc thật, để app không phóng to quá mức thành vỡ hình
            "icon_native": a.get("icon_native", 0),
        }
        for a in apps
    ]
