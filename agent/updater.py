"""Cập nhật agent từ GitHub Releases.

Chỉ bản .exe (tải từ trang Releases) mới tự thay được chính nó: tải file mới
về cạnh file đang chạy, đổi tên file cũ thành .old (Windows cho đổi tên file
đang chạy, chỉ không cho xoá), đặt file mới vào chỗ cũ rồi mở lại. Bản chạy từ
mã nguồn (run_agent.bat) chỉ được báo có bản mới — mã nguồn cập nhật bằng
git pull, agent tự ghi đè lên đó sẽ làm rối Git.

Không bao giờ tự cài: agent chỉ báo, người dùng gõ C trong cửa sổ agent mới
cài.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = "ThangHeTanTy/HeDeck"
LATEST = f"https://api.github.com/repos/{REPO}/releases/latest"
RELEASES = f"https://github.com/{REPO}/releases/latest"
ASSET = "HeDeckAgent.exe"

# CI ghi file này lúc đóng gói .exe. Chạy từ mã nguồn thì không có.
try:
    from _build_version import VERSION
except ImportError:
    VERSION = ""

FROZEN = getattr(sys, "frozen", False)

# Việc cần làm ngay trước khi thoát để mở bản mới (gỡ icon ở khay...).
before_restart = []
EXE = Path(sys.executable) if FROZEN else None


def parse_version(text):
    """'v1.2.3' -> (1, 2, 3). Không đúng dạng thì trả về None."""
    m = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", (text or "").strip())
    return tuple(int(x) for x in m.groups()) if m else None


def _get(url, timeout=15):
    req = urllib.request.Request(url, headers={
        "User-Agent": "HeDeck-Agent",
        "Accept": "application/vnd.github+json",
    })
    return urllib.request.urlopen(req, timeout=timeout)


def check():
    """Hỏi GitHub bản mới nhất. Trả về dict nếu có bản mới hơn bản đang chạy.

    Chạy từ mã nguồn (không biết số phiên bản) thì luôn trả về bản mới nhất,
    để cửa sổ agent nhắc git pull khi có phát hành mới.
    """
    try:
        with _get(LATEST) as resp:
            rel = json.load(resp)
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None  # kho chưa có bản phát hành nào
        raise
    latest = parse_version(rel.get("tag_name"))
    if latest is None:
        return None
    current = parse_version(VERSION)
    if current is not None and latest <= current:
        return None
    asset = next((a for a in rel.get("assets", []) if a.get("name") == ASSET),
                 None)
    digest = (asset or {}).get("digest") or ""
    return {
        "version": ".".join(map(str, latest)),
        # Phần dưới dòng --- là hướng dẫn cài lần đầu, không phải thay đổi.
        "notes": re.split(r"(?m)^---\s*$", rel.get("body") or "")[0].strip(),
        "page": rel.get("html_url", ""),
        "url": asset["browser_download_url"] if asset else "",
        "size": asset.get("size", 0) if asset else 0,
        # GitHub tự tính SHA-256 cho mọi file đính kèm, dạng "sha256:…".
        "sha256": digest[7:] if digest.startswith("sha256:") else "",
    }


def can_self_update(info):
    return bool(FROZEN and info and info.get("url"))


def short_notes(notes, max_lines=8):
    lines = [ln.rstrip() for ln in notes.splitlines() if ln.strip()]
    if len(lines) > max_lines:
        lines = lines[:max_lines] + ["…"]
    return lines


def install(info, log=print):
    """Tải bản mới và đặt vào chỗ file .exe đang chạy. Lỗi thì giữ bản cũ."""
    new = EXE.with_name(EXE.name + ".new")
    old = EXE.with_name(EXE.name + ".old")
    sha = hashlib.sha256()
    done = 0
    last = -1
    with _get(info["url"], timeout=60) as resp, open(new, "wb") as out:
        total = int(resp.headers.get("Content-Length") or info.get("size") or 0)
        while chunk := resp.read(256 * 1024):
            out.write(chunk)
            sha.update(chunk)
            done += len(chunk)
            pct = done * 100 // total if total else -1
            if pct >= 0 and pct // 20 != last // 20:
                log(f"Đang tải bản {info['version']}: {pct}%")
            last = pct

    if info.get("sha256") and sha.hexdigest() != info["sha256"].lower():
        new.unlink(missing_ok=True)
        raise RuntimeError("file tải về bị hỏng (sai mã SHA-256), đã giữ bản cũ")

    old.unlink(missing_ok=True)
    os.replace(EXE, old)
    # Phần mềm diệt virus hay giữ file mới tải vài giây để quét: thử lại.
    for attempt in range(10):
        try:
            os.replace(new, EXE)
            return
        except OSError:
            if attempt == 9:
                os.replace(old, EXE)  # trả bản cũ về chỗ, vẫn chạy lại được
                raise
            time.sleep(1)


def restart():
    """Mở bản vừa cài rồi thoát bản đang chạy."""
    # Không có biến này, bản mới tưởng mình là tiến trình con của bản cũ và
    # dùng chung thư mục giải nén tạm — bản cũ thoát là xoá mất thư mục đó.
    env = dict(os.environ, PYINSTALLER_RESET_ENVIRONMENT="1")
    # --after-update: bản mới chờ bản này thoát hẳn thay vì tưởng đã có một
    # agent khác đang chạy rồi tự thoát.
    args = [a for a in sys.argv[1:] if a != "--after-update"]
    subprocess.Popen([str(EXE), *args, "--after-update"],
                     creationflags=subprocess.CREATE_NEW_CONSOLE,
                     cwd=str(EXE.parent), env=env)
    for hook in before_restart:
        try:
            hook()
        except Exception:
            pass
    os._exit(0)


def cleanup():
    """Xoá file .old còn sót từ lần cập nhật trước."""
    if not FROZEN:
        return
    try:
        EXE.with_name(EXE.name + ".old").unlink(missing_ok=True)
    except OSError:
        pass  # bản cũ chưa thoát hẳn, lần sau xoá
