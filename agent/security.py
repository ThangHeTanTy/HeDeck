"""Lớp bảo vệ của agent.

Ba tầng, độc lập nhau:

1. **Chặn theo mạng** — chỉ nhận kết nối từ dải IP nội bộ. Máy ngoài Internet
   không bao giờ chạm được tới lớp xác thực.
2. **Phát hiện IP lạ** — đếm số lần thất bại theo từng IP, quá ngưỡng thì khoá
   tạm rồi khoá vĩnh viễn, đồng thời báo lên cửa sổ agent.
3. **Xác thực một chiều** — agent chỉ giữ khoá công khai của điện thoại. Kẻ
   đọc trộm file cấu hình không lấy được gì để giả mạo, vì khoá bí mật nằm
   trong điện thoại và không bao giờ rời khỏi đó.
"""

import base64
import hashlib
import ipaddress
import json
import os
import time
from collections import defaultdict, deque
from pathlib import Path

CONFIG_DIR = Path(os.path.expanduser("~")) / ".hedeck"
BLOCK_FILE = CONFIG_DIR / "blocked.json"

# Ngưỡng phát hiện
MAX_FAILS = 5              # sai bao nhiêu lần thì khoá tạm
FAIL_WINDOW = 300          # trong khoảng bao nhiêu giây
TEMP_BLOCK = 900           # khoá tạm 15 phút
PERMANENT_AFTER = 3        # bị khoá tạm bấy nhiêu lần thì khoá hẳn
MAX_CONN_PER_MIN = 30      # số kết nối tối đa mỗi IP mỗi phút

CLOCK_SKEW = 120           # cho phép lệch giờ 2 phút
NONCE_MEMORY = 4096        # số nonce gần nhất được nhớ để chặn phát lại


def is_private_ip(addr: str) -> bool:
    """Địa chỉ có thuộc mạng nội bộ hoặc chính máy này không."""
    try:
        ip = ipaddress.ip_address(addr)
    except ValueError:
        return False
    return ip.is_private or ip.is_loopback or ip.is_link_local


class Guard:
    """Theo dõi và chặn các IP có hành vi bất thường."""

    def __init__(self, log=print):
        self.log = log
        self.fails = defaultdict(list)        # ip -> mốc thời gian thất bại
        self.temp_until = {}                  # ip -> thời điểm hết khoá tạm
        self.temp_count = defaultdict(int)    # ip -> số lần bị khoá tạm
        self.conns = defaultdict(lambda: deque(maxlen=MAX_CONN_PER_MIN * 2))
        self.banned = self._load_banned()
        self.seen_nonces = deque(maxlen=NONCE_MEMORY)
        self._nonce_set = set()

    # -- danh sách chặn vĩnh viễn ----------------------------------------

    def _load_banned(self):
        if BLOCK_FILE.exists():
            try:
                return set(json.loads(BLOCK_FILE.read_text(encoding="utf-8")))
            except Exception:
                pass
        return set()

    def _save_banned(self):
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        BLOCK_FILE.write_text(
            json.dumps(sorted(self.banned), indent=2), encoding="utf-8"
        )

    def unban_all(self):
        self.banned.clear()
        self.temp_until.clear()
        self.temp_count.clear()
        self.fails.clear()
        self._save_banned()
        self.log("Đã xoá toàn bộ danh sách chặn.")

    # -- kiểm tra khi có kết nối mới -------------------------------------

    def check(self, ip: str):
        """Trả về (cho_phép, lý_do_từ_chối)."""
        now = time.time()

        if not is_private_ip(ip):
            self.log(f"CHẶN: kết nối từ ngoài mạng nội bộ — {ip}")
            return False, "Chỉ chấp nhận kết nối từ mạng nội bộ"

        if ip in self.banned:
            return False, "Thiết bị này đã bị chặn"

        until = self.temp_until.get(ip, 0)
        if now < until:
            return False, f"Tạm khoá, thử lại sau {int(until - now)} giây"

        recent = self.conns[ip]
        recent.append(now)
        while recent and now - recent[0] > 60:
            recent.popleft()
        if len(recent) > MAX_CONN_PER_MIN:
            self.log(f"CHẶN: {ip} kết nối quá dày ({len(recent)} lần/phút)")
            self._temp_block(ip, "kết nối quá dày")
            return False, "Kết nối quá nhiều lần"

        return True, ""

    # -- ghi nhận kết quả xác thực ---------------------------------------

    def record_failure(self, ip: str, what: str):
        now = time.time()
        marks = self.fails[ip]
        marks.append(now)
        self.fails[ip] = [t for t in marks if now - t <= FAIL_WINDOW]
        count = len(self.fails[ip])

        self.log(f"CẢNH BÁO: {what} từ {ip} (lần {count}/{MAX_FAILS})")

        if count >= MAX_FAILS:
            self._temp_block(ip, what)
            self.fails[ip] = []

    def record_success(self, ip: str):
        self.fails.pop(ip, None)
        self.temp_count.pop(ip, None)

    def _temp_block(self, ip: str, why: str):
        self.temp_until[ip] = time.time() + TEMP_BLOCK
        self.temp_count[ip] += 1
        self.log(f"KHOÁ TẠM {ip} trong {TEMP_BLOCK // 60} phút — {why}")

        if self.temp_count[ip] >= PERMANENT_AFTER:
            self.banned.add(ip)
            self._save_banned()
            self.log(f"CHẶN VĨNH VIỄN {ip} — tái phạm {PERMANENT_AFTER} lần")

    # -- chống phát lại ---------------------------------------------------

    def fresh_nonce(self, nonce: str) -> bool:
        """Mỗi nonce chỉ dùng được một lần, chặn kẻ ghi lại rồi gửi lại."""
        if not nonce or nonce in self._nonce_set:
            return False
        if len(self.seen_nonces) == self.seen_nonces.maxlen:
            self._nonce_set.discard(self.seen_nonces[0])
        self.seen_nonces.append(nonce)
        self._nonce_set.add(nonce)
        return True

    @staticmethod
    def fresh_timestamp(ts) -> bool:
        try:
            return abs(time.time() - float(ts)) <= CLOCK_SKEW
        except (TypeError, ValueError):
            return False

    def status(self):
        now = time.time()
        temp = sum(1 for t in self.temp_until.values() if t > now)
        return {"banned": len(self.banned), "temp_blocked": temp}


# --------------------------------------------------------------------------
# Xác thực một chiều bằng chữ ký Ed25519
# --------------------------------------------------------------------------

def verify_signature(public_key_b64: str, message: bytes, signature_b64: str) -> bool:
    """Kiểm tra chữ ký bằng khoá công khai.

    Agent chỉ giữ khoá công khai. Khoá bí mật nằm trong điện thoại và không
    bao giờ được gửi đi, nên đọc trộm file cấu hình của agent cũng không giả
    mạo được thiết bị — khác hẳn cách dùng khoá chung HMAC.
    """
    try:
        from cryptography.exceptions import InvalidSignature
        from cryptography.hazmat.primitives.asymmetric.ed25519 import (
            Ed25519PublicKey,
        )
    except ImportError:
        return False

    try:
        key = Ed25519PublicKey.from_public_bytes(base64.b64decode(public_key_b64))
        key.verify(base64.b64decode(signature_b64), message)
        return True
    except (InvalidSignature, ValueError, TypeError):
        return False


def fingerprint(public_key_b64: str) -> str:
    """Vân tay ngắn của khoá, để hiển thị cho người dùng đối chiếu."""
    digest = hashlib.sha256(base64.b64decode(public_key_b64)).hexdigest()
    return ":".join(digest[i:i + 4] for i in range(0, 12, 4)).upper()
