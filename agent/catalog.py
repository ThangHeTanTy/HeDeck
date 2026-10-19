"""Danh mục ứng dụng của agent.

Nguyên tắc bảo mật: điện thoại chỉ gửi `app_id`. Đường dẫn thật nằm ở đây,
trên laptop. Không có lệnh nào cho phép điện thoại chạy một đường dẫn tuỳ ý.
"""

import hashlib
import json
import os
from pathlib import Path

import launchers
import win_control

CONFIG_DIR = Path(os.path.expanduser("~")) / ".hedeck"
CATALOG_FILE = CONFIG_DIR / "catalog.json"
# Danh sách tự thêm tay. Nằm riêng khỏi catalog.json nên quét lại không mất.
CUSTOM_FILE = CONFIG_DIR / "them_ung_dung.json"

# Tăng số này mỗi khi đổi cách trích icon. Agent thấy catalog.json cũ hơn sẽ
# tự quét lại, khỏi phải nhớ bấm "Quét lại ứng dụng" bằng tay.
CATALOG_VERSION = 10

SKIP_WORDS = (
    "uninstall", "gỡ cài đặt", "readme", "help", "documentation", "license",
    "release notes", "website", "báo lỗi", "repair", "safe mode",
)

START_MENUS = [
    Path(os.environ.get("APPDATA", "")) / "Microsoft/Windows/Start Menu/Programs",
    Path(os.environ.get("PROGRAMDATA", "")) / "Microsoft/Windows/Start Menu/Programs",
]

# Shortcut .url chỉ nhận khi trỏ tới launcher (steam://, com.epicgames...).
# Link web trên desktop thì bỏ, không phải ứng dụng.
_WEB_SCHEMES = ("http://", "https://", "file://", "ftp://")


def desktops():
    """Desktop của người dùng và desktop chung. Hỏi Windows thay vì đoán
    ~/Desktop, vì OneDrive hay chuyển Desktop sang chỗ khác."""
    found = []
    try:
        from win32com.shell import shell, shellcon
        for csidl in (shellcon.CSIDL_DESKTOPDIRECTORY,
                      shellcon.CSIDL_COMMON_DESKTOPDIRECTORY):
            try:
                found.append(Path(shell.SHGetFolderPath(0, csidl, None, 0)))
            except Exception:
                pass
    except ImportError:
        pass
    found += [Path(os.path.expanduser("~")) / "Desktop",
              Path(os.environ.get("PUBLIC", r"C:\Users\Public")) / "Desktop"]
    unique = []
    for d in found:
        if d.exists() and all(not _same_path(d, u) for u in unique):
            unique.append(d)
    return unique


def _same_path(a, b):
    try:
        return os.path.samefile(a, b)
    except OSError:
        return str(a).lower() == str(b).lower()


def _app_id(name: str, target: str, args: str = "") -> str:
    # Không có tham số thì giữ nguyên công thức cũ, để các ô người dùng đã
    # xếp trên deck vẫn trỏ đúng app sau khi quét lại.
    if args:
        target = f"{target}|{launchers.norm_args(args)}"
    return hashlib.sha1(f"{name}|{target}".lower().encode()).hexdigest()[:12]


def _read_url_file(path: Path):
    """Đọc shortcut .url (định dạng INI đơn giản) -> (url, icon_file)."""
    url = icon = ""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return "", ""
    for line in text.splitlines():
        key, _, value = line.partition("=")
        key = key.strip().lower()
        if key == "url" and not url:
            url = value.strip()
        elif key == "iconfile" and not icon:
            icon = value.strip()
    return url, icon


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
    """Quét mọi nguồn (launcher, Start Menu, Desktop, danh sách tự thêm),
    trả về danh sách app đã khử trùng lặp.

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


def _entry(name, path, target, args="", workdir="", exe="", procs=(),
           folder="", source="shortcut"):
    return {
        "id": _app_id(name, target, args),
        "name": name,
        "path": path,          # thứ được mở: .lnk, .exe, hoặc URL launcher
        "exe": exe or os.path.basename(target),  # tiến trình chính
        "args": args,
        "workdir": workdir,
        "target": target,      # file lấy icon
        "procs": list(procs),  # thêm tên tiến trình cũng tính là app này
        "dir": folder,         # cửa sổ của exe trong thư mục này cũng tính
        "source": source,
        "icon": None,
        "icon_native": 0,
    }


def _from_shortcut(shell, lnk: Path, name: str):
    """Shortcut -> (khoá khử trùng lặp, app) hoặc None."""
    if lnk.suffix.lower() == ".url":
        url, icon = _read_url_file(lnk)
        if "://" not in url or url.lower().startswith(_WEB_SCHEMES):
            return None
        target = icon if icon and os.path.exists(icon) else ""
        return (launchers.shortcut_key(url, ""),
                _entry(name, str(lnk), target, exe="", source="url"))

    target, args, workdir = _resolve_lnk(shell, lnk)
    if not target or not target.lower().endswith(".exe"):
        return None
    if not os.path.exists(target):
        return None
    # Mọi shortcut game của Riot đều trỏ về RiotClientServices.exe, chỉ khác
    # tham số. Nhận ra sản phẩm để viền xanh bám theo game chứ không theo
    # Riot Client.
    procs = launchers.riot_procs(launchers.riot_product_of(args))
    return (launchers.shortcut_key(target, args),
            _entry(name, str(lnk), target, args, workdir,
                   exe=procs[0] if procs else "", procs=procs))


def _shortcut_files(roots, recursive):
    for root in roots:
        if not root.exists():
            continue
        if recursive:
            for dirpath, _, files in os.walk(root):
                for fname in files:
                    yield Path(dirpath) / fname
        else:
            for f in root.iterdir():
                if f.is_file():
                    yield f


def _custom_apps():
    """Đọc them_ung_dung.json. Chưa có thì tạo file mẫu để người dùng sửa."""
    if not CUSTOM_FILE.exists():
        CUSTOM_FILE.write_text(json.dumps({
            "_huong_dan": "Thêm app quét không ra. 'path' là file .exe, "
                          "shortcut .lnk hoặc link launcher (steam://...). "
                          "'procs' là tên tiến trình để nhận biết app đang "
                          "chạy, không bắt buộc. Sửa xong bấm 'Quét lại "
                          "ứng dụng' trên điện thoại.",
            "apps": [
                {"name": "Ví dụ — xoá dòng này",
                 "path": "C:\\Windows\\notepad.exe",
                 "args": "", "procs": []},
            ],
        }, ensure_ascii=False, indent=2), encoding="utf-8")
        return []
    try:
        data = json.loads(CUSTOM_FILE.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"  them_ung_dung.json lỗi định dạng, bỏ qua: {exc}", flush=True)
        return []
    out = []
    for item in data.get("apps", []):
        name = str(item.get("name", "")).strip()
        path = str(item.get("path", "")).strip()
        if not name or not path or name.startswith("Ví dụ"):
            continue
        is_url = "://" in path
        if not is_url and not os.path.exists(path):
            print(f"    (bỏ qua {name}: không thấy {path})", flush=True)
            continue
        args = str(item.get("args", ""))
        target = "" if is_url else path
        procs = [str(p) for p in item.get("procs", []) if p]
        exe = procs[0] if procs else (
            os.path.basename(path) if path.lower().endswith(".exe") else "")
        out.append((launchers.shortcut_key(path, args),
                    _entry(name, path, target, args, exe=exe, procs=procs,
                           folder=launchers.safe_dir(item.get("dir", "")),
                           source="custom")))
    return out


def _scan(apps, seen, with_icons):
    """Gom app từ mọi nguồn, nguồn nhiều thông tin nhất đi trước.

    1. Game từ launcher (Riot, Steam, Epic): biết tên, thư mục cài, tiến trình.
    2. Shortcut .lnk/.url trong Start Menu.
    3. Shortcut trên Desktop — nhiều game chỉ tạo shortcut ở đây.
    4. Danh sách tự thêm trong them_ung_dung.json.

    Khử trùng lặp theo file đích + tham số, không theo file đích. Trước đây
    chỉ so file .exe nên mọi game Riot (cùng trỏ RiotClientServices.exe) bị
    gộp thành một mục "Riot Client".
    """
    import time

    shell = _make_shell()
    started = time.time()
    checked = 0
    names = set()

    def add(key, app):
        if key in seen or app["name"].lower() in names:
            return False
        seen.add(key)
        names.add(app["name"].lower())
        apps.append(app)
        if with_icons and app["target"]:
            # Một icon hỏng không được phép làm chết cả lượt quét.
            try:
                result = win_control.extract_icon_png(app["target"])
                if result:
                    app["icon"], app["icon_native"] = result
            except Exception as exc:
                print(f"    (bỏ qua icon {app['name']}: {exc})", flush=True)
        return True

    print("  Tìm game trong Riot Client, Steam, Epic...", flush=True)
    for game in launchers.all_games(log=lambda m: print(m, flush=True)):
        key = game.pop("key")
        add(key, _entry(game["name"], game["path"], game["target"],
                        game["args"], exe=game["exe"], procs=game["procs"],
                        folder=game["dir"], source=game["source"]))

    for roots, recursive, label in ((START_MENUS, True, "Start Menu"),
                                    (desktops(), False, "Desktop")):
        before = len(apps)
        for lnk in _shortcut_files(roots, recursive):
            if lnk.suffix.lower() not in (".lnk", ".url"):
                continue
            name = lnk.stem
            if any(w in name.lower() for w in SKIP_WORDS):
                continue
            checked += 1
            # Nhịp báo tiến độ: kẹt ở đâu là thấy ngay, không phải đoán.
            if checked % 25 == 0:
                print(f"    ...đã xem {checked} shortcut, "
                      f"nhận {len(apps)} app "
                      f"({time.time() - started:.1f}s)", flush=True)
            found = _from_shortcut(shell, lnk, name)
            if found:
                add(*found)
        print(f"    {label}: thêm {len(apps) - before} app", flush=True)

    for key, app in _custom_apps():
        add(key, app)

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
            target = app.get("target")
            if not target:
                continue  # link launcher không kèm icon: dùng icon vector
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


def add_custom(name, path):
    """Thêm một chương trình vào them_ung_dung.json rồi trả về app mới.

    Dùng cho "Thêm từ cửa sổ đang mở". `path` luôn do agent tự đọc từ tiến
    trình đang chạy, không bao giờ do điện thoại gửi lên.
    """
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if not CUSTOM_FILE.exists():
        _custom_apps()  # tạo file mẫu trước
    try:
        data = json.loads(CUSTOM_FILE.read_text(encoding="utf-8"))
    except Exception:
        data = {}
    items = data.setdefault("apps", [])
    exe = os.path.basename(path)
    if not any(str(i.get("path", "")).lower() == path.lower() for i in items):
        items.append({"name": name, "path": path, "args": "", "procs": [exe]})
        CUSTOM_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2),
                               encoding="utf-8")
    return _entry(name, path, path, exe=exe, procs=[exe], source="custom")


def match_of(app):
    """(tên tiến trình, thư mục cài) để nhận ra cửa sổ nào là của app."""
    procs = [app.get("exe", "")] + list(app.get("procs") or [])
    dirs = [app["dir"]] if app.get("dir") else []
    return list(dict.fromkeys(p for p in procs if p)), dirs


def is_launcher_app(app):
    """Game mở qua launcher: launcher khởi động và cập nhật trước, cửa sổ
    game ra chậm hơn hẳn app thường."""
    return app.get("source") in ("riot", "steam", "epic", "url") or \
        "://" in app.get("path", "")


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
