"""Tìm game cài qua các launcher: Riot Client, Steam, Epic Games.

Game cài qua launcher thường không có shortcut riêng trong Start Menu, hoặc
có nhưng mọi shortcut đều trỏ về cùng một file .exe của launcher, chỉ khác
tham số. Module này đọc thẳng dữ liệu mà launcher ghi lại trên đĩa để biết máy
có những game nào, mở bằng lệnh gì, và tiến trình nào là của game.

Mỗi hàm trả về danh sách "bản nháp" app với các khoá:
    name, path, args, target (exe để lấy icon), exe (tiến trình chính),
    procs (thêm tên tiến trình khác), dir (thư mục cài, để nhận diện cửa sổ),
    source, key (khoá khử trùng lặp với shortcut).

Mọi hàm đều không ném lỗi: launcher nào không cài hoặc đọc hỏng thì trả về
danh sách rỗng.
"""

import glob
import json
import os
import re
from pathlib import Path

PROGRAMDATA = Path(os.environ.get("PROGRAMDATA", r"C:\ProgramData"))

# File .exe không phải game: trình gỡ cài đặt, báo lỗi, cài thư viện phụ...
_JUNK_EXE = re.compile(
    r"(unins|uninst|setup|install|redist|vcredist|vc_|dxsetup|directx|"
    r"crash|report|helper|easyanticheat|eac_|battleye|ue4prereq|"
    r"prereq|dotnet|cefprocess|webhelper|update)", re.I)


def norm_args(args):
    return " ".join(str(args or "").lower().split())


def shortcut_key(target, args):
    """Khoá khử trùng lặp. Phải tính giống hệt cho shortcut và cho bản nháp
    từ launcher, để cùng một game không xuất hiện hai lần."""
    return f"{str(target).lower()}|{norm_args(args)}"


def main_exe(folder, prefer=(), max_files=4000):
    """Đoán file .exe chính của game: ưu tiên tên cho trước, còn lại lấy
    file lớn nhất không nằm trong danh sách rác. Game thật thường là file
    nặng nhất trong thư mục cài."""
    if not folder or not os.path.isdir(folder):
        return ""
    for name in prefer:
        # Chỉ tìm ở thư mục gốc và một cấp con. Quét đệ quy cả thư mục game
        # vài chục GB chỉ để tìm một cái tên thì quá chậm.
        for pattern in (os.path.join(folder, name),
                        os.path.join(folder, "*", name)):
            for candidate in glob.glob(pattern):
                return candidate
    best, best_size, seen = "", -1, 0
    base_depth = folder.rstrip("\\/").count(os.sep)
    for dirpath, dirnames, files in os.walk(folder):
        if dirpath.count(os.sep) - base_depth >= 3:
            dirnames[:] = []
        for f in files:
            seen += 1
            if seen > max_files:
                return best
            if not f.lower().endswith(".exe") or _JUNK_EXE.search(f):
                continue
            path = os.path.join(dirpath, f)
            try:
                size = os.path.getsize(path)
            except OSError:
                continue
            if size > best_size:
                best, best_size = path, size
    return best


_SHARED_DIRS = {
    "program files", "program files (x86)", "windows", "users", "programdata",
    "steamapps", "common", "games", "riot games", "epic games",
}


def safe_dir(folder):
    """Chỉ nhận thư mục cài riêng của game. Nhận diện cửa sổ theo thư mục mà
    lỡ nhận cả C:\\Program Files thì app nào cũng bị coi là game đó."""
    if not folder:
        return ""
    p = os.path.normpath(folder).rstrip("\\/")
    parts = [x for x in re.split(r"[\\/]", p) if x]
    if len(parts) < 2 or parts[-1].lower() in _SHARED_DIRS:
        return ""
    return p.lower() + os.sep


# --------------------------------------------------------------------------
# Riot Games
# --------------------------------------------------------------------------

# id sản phẩm của Riot -> (tên hiển thị, tiến trình của game, exe lấy icon)
RIOT_PRODUCTS = {
    "league_of_legends": ("Liên Minh Huyền Thoại",
                          ["LeagueClientUx.exe", "LeagueClient.exe",
                           "League of Legends.exe"],
                          ["LeagueClient.exe"]),
    "valorant": ("VALORANT",
                 ["VALORANT-Win64-Shipping.exe", "VALORANT.exe"],
                 ["VALORANT.exe"]),
    "bacon": ("Legends of Runeterra", ["LoR.exe"], ["LoR.exe"]),
    "lion": ("2XKO", [], []),
}

# Đấu Trường Chân Lý không phải sản phẩm riêng: chơi trong client Liên Minh.
# Vẫn tạo một ô riêng vì người dùng tìm nó theo tên, bấm vào là mở client.
TFT_NAME = "Đấu Trường Chân Lý"

_RIOT_ARG = re.compile(r"--launch-product=([a-z0-9_]+)", re.I)


def riot_product_of(args):
    m = _RIOT_ARG.search(args or "")
    return m.group(1).lower() if m else ""


def riot_procs(product):
    return list(RIOT_PRODUCTS.get(product, ("", [], []))[1])


def _riot_client():
    candidates = []
    try:
        data = json.loads((PROGRAMDATA / "Riot Games" / "RiotClientInstalls.json")
                          .read_text(encoding="utf-8"))
        for k in ("rc_default", "rc_live", "rc_beta"):
            if data.get(k):
                candidates.append(data[k])
    except Exception:
        pass
    candidates += [r"C:\Riot Games\Riot Client\RiotClientServices.exe",
                   r"D:\Riot Games\Riot Client\RiotClientServices.exe"]
    for c in candidates:
        c = os.path.normpath(c)
        if os.path.isfile(c):
            return c
    return ""


def _yaml_value(text, key):
    m = re.search(rf"^\s*{key}\s*:\s*['\"]?(.+?)['\"]?\s*$", text, re.M)
    return m.group(1).strip() if m else ""


def riot_games():
    client = _riot_client()
    meta = PROGRAMDATA / "Riot Games" / "Metadata"
    if not client or not meta.is_dir():
        return []

    out = []
    for folder in sorted(meta.iterdir()):
        if not folder.is_dir() or "." not in folder.name:
            continue
        product, patchline = folder.name.split(".", 1)
        if product == "riot_client":
            continue
        install = ""
        for settings in folder.glob("*.product_settings.yaml"):
            try:
                text = settings.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            install = _yaml_value(text, "product_install_full_path")
            break
        install = os.path.normpath(install) if install else ""
        if not install or not os.path.isdir(install):
            continue  # sản phẩm đã gỡ nhưng còn sót metadata

        name, procs, icon_prefer = RIOT_PRODUCTS.get(
            product, (product.replace("_", " ").title(), [], []))
        if patchline != "live":
            name = f"{name} ({patchline.upper()})"
        args = f"--launch-product={product} --launch-patchline={patchline}"
        icon = main_exe(install, icon_prefer)
        entry = {
            "name": name,
            "path": client,
            "args": args,
            "target": icon or client,
            "exe": procs[0] if procs else (os.path.basename(icon) if icon else ""),
            "procs": procs,
            "dir": safe_dir(install),
            "source": "riot",
            "key": shortcut_key(client, args),
        }
        out.append(entry)
        if product == "league_of_legends" and patchline == "live":
            out.append(dict(entry, name=TFT_NAME, key=entry["key"] + "|tft"))
    return out


# --------------------------------------------------------------------------
# Steam
# --------------------------------------------------------------------------

# Không phải game: thư viện chạy chung, công cụ của Steam.
_STEAM_SKIP = re.compile(
    r"(redistributable|steamworks|proton|steam linux runtime|steamvr|"
    r"dedicated server|sdk)", re.I)


def _steam_root():
    try:
        import winreg
        for hive, sub, val in (
            (winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam", "SteamPath"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Valve\Steam",
             "InstallPath"),
        ):
            try:
                with winreg.OpenKey(hive, sub) as k:
                    path = winreg.QueryValueEx(k, val)[0]
                    if path and os.path.isdir(path):
                        return os.path.normpath(path)
            except OSError:
                continue
    except ImportError:
        pass
    return ""


def _vdf_values(text, key):
    return [v.replace("\\\\", "\\")
            for v in re.findall(rf'"{key}"\s+"([^"]*)"', text, re.I)]


def steam_games():
    root = _steam_root()
    if not root:
        return []
    libraries = {root}
    try:
        text = Path(root, "steamapps", "libraryfolders.vdf").read_text(
            encoding="utf-8", errors="replace")
        libraries.update(os.path.normpath(p) for p in _vdf_values(text, "path"))
    except OSError:
        pass

    steam_exe = os.path.join(root, "steam.exe")
    out = []
    for lib in libraries:
        for acf in glob.glob(os.path.join(lib, "steamapps", "appmanifest_*.acf")):
            try:
                text = Path(acf).read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            appid = (_vdf_values(text, "appid") or [""])[0]
            name = (_vdf_values(text, "name") or [""])[0]
            installdir = (_vdf_values(text, "installdir") or [""])[0]
            if not appid or not name or _STEAM_SKIP.search(name):
                continue
            folder = os.path.join(lib, "steamapps", "common", installdir)
            if not os.path.isdir(folder):
                continue
            exe = main_exe(folder)
            url = f"steam://rungameid/{appid}"
            out.append({
                "name": name,
                "path": url,
                "args": "",
                "target": exe or steam_exe,
                "exe": os.path.basename(exe) if exe else "",
                "procs": [],
                "dir": safe_dir(folder),
                "source": "steam",
                "key": shortcut_key(url, ""),
            })
    return out


# --------------------------------------------------------------------------
# Epic Games
# --------------------------------------------------------------------------

def epic_games():
    manifests = PROGRAMDATA / "Epic" / "EpicGamesLauncher" / "Data" / "Manifests"
    if not manifests.is_dir():
        return []
    out = []
    for item in manifests.glob("*.item"):
        try:
            data = json.loads(item.read_text(encoding="utf-8", errors="replace"))
        except Exception:
            continue
        if data.get("bIsIncompleteInstall") or data.get("bIsApplication") is False:
            continue
        name = data.get("DisplayName") or ""
        folder = os.path.normpath(data.get("InstallLocation") or "")
        app_name = data.get("AppName") or ""
        if not name or not app_name or not os.path.isdir(folder):
            continue
        launch_exe = data.get("LaunchExecutable") or ""
        exe = os.path.join(folder, launch_exe) if launch_exe else main_exe(folder)
        ns = data.get("CatalogNamespace") or ""
        cid = data.get("CatalogItemId") or ""
        ident = f"{ns}%3A{cid}%3A{app_name}" if ns and cid else app_name
        url = f"com.epicgames.launcher://apps/{ident}?action=launch&silent=true"
        out.append({
            "name": name,
            "path": url,
            "args": "",
            "target": exe if os.path.isfile(exe) else "",
            "exe": os.path.basename(exe) if exe else "",
            "procs": [],
            "dir": safe_dir(folder),
            "source": "epic",
            "key": shortcut_key(url, ""),
        })
    return out


def all_games(log=print):
    found = []
    for label, fn in (("Riot", riot_games), ("Steam", steam_games),
                      ("Epic", epic_games)):
        try:
            games = fn()
        except Exception as exc:
            log(f"    (bỏ qua {label}: {exc})")
            continue
        if games:
            log(f"    {label}: {len(games)} game")
        found += games
    return found
