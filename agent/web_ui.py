"""Phục vụ bản web của HeDeck (cho iPhone, iPad, trình duyệt) ngay trên cổng
của agent.

Trình duyệt mở http://<ip>:8787/ là nhận trang; trang đó lại mở WebSocket tới
chính địa chỉ ấy, đi đúng đường của app Android. Cùng một cổng nên không phải
mở thêm cổng trên tường lửa, và trang luôn khớp phiên bản với agent đã phục
vụ nó — cập nhật agent là bản web mới theo.

Chỉ trả trang cho máy trong mạng nội bộ, như WebSocket.
"""

import mimetypes
import re
import sys
from email.utils import formatdate
from pathlib import Path
from urllib.parse import unquote, urlsplit

from websockets.datastructures import Headers
from websockets.http11 import Response

import security

HERE = Path(__file__).resolve().parent

TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".wasm": "application/wasm",
    ".css": "text/css; charset=utf-8",
    ".png": "image/png",
    ".ico": "image/x-icon",
    ".svg": "image/svg+xml",
    ".otf": "font/otf",
    ".ttf": "font/ttf",
    ".mp4": "video/mp4",
    ".frag": "text/plain; charset=utf-8",
    "": "application/octet-stream",
}

NOT_BUILT = """<!doctype html><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeDeck</title>
<body style="font:16px system-ui;background:#0F1218;color:#E8EAF0;padding:24px">
<h2>Agent này chưa có bản web</h2>
<p>Bản tải từ GitHub (HeDeckAgent.exe) có sẵn bản web. Nếu đang chạy agent từ
mã nguồn, chạy <b>BUILD_WEB.bat</b> ở thư mục gốc HeDeck rồi tải lại trang.</p>
<p style="color:#8A90A0">This agent has no web version yet. Run BUILD_WEB.bat in
the HeDeck folder, then reload.</p></body>"""


def find_root():
    """Thư mục chứa bản web đã build, hoặc None nếu chưa có."""
    candidates = []
    if getattr(sys, "frozen", False):
        candidates.append(Path(getattr(sys, "_MEIPASS", HERE)) / "web")
    candidates += [HERE / "web", HERE.parent / "flutter_app" / "build" / "web"]
    for path in candidates:
        if (path / "index.html").is_file():
            return path.resolve()
    return None


def _response(status, reason, body, content_type, extra=()):
    headers = Headers([
        ("Content-Type", content_type),
        ("Content-Length", str(len(body))),
        ("Date", formatdate(usegmt=True)),
        # Mỗi lần mở đều hỏi lại agent: vừa cập nhật agent là trang mới ngay,
        # không bị trình duyệt giữ bản cũ. ETag giúp khỏi tải lại khi không đổi.
        ("Cache-Control", "no-cache"),
        ("Connection", "close"),
        *extra,
    ])
    return Response(status, reason, headers, body)


class WebFiles:
    def __init__(self, log=print):
        self.log = log
        self.root = find_root()
        self._etags = {}

    @property
    def available(self):
        return self.root is not None

    def process_request(self, connection, request):
        """Móc vào websockets.serve: yêu cầu WebSocket thì cho đi tiếp (None),
        còn lại là tải trang thì trả file."""
        if "websocket" in request.headers.get("Upgrade", "").lower():
            return None

        peer = connection.remote_address[0] if connection.remote_address else ""
        if not security.is_private_ip(peer):
            return _response(403, "Forbidden", b"", "text/plain")

        if self.root is None:
            return _response(200, "OK", NOT_BUILT.encode("utf-8"),
                             TYPES[".html"])

        path = unquote(urlsplit(request.path).path).lstrip("/") or "index.html"
        try:
            file = (self.root / path).resolve()
            file.relative_to(self.root)  # chặn ../ ra ngoài thư mục web
        except (ValueError, OSError):
            return _response(404, "Not Found", b"", "text/plain")
        if not file.is_file():
            # Đường dẫn không có đuôi là trang trong app: trả index.html.
            if "." in Path(path).name:
                return _response(404, "Not Found", b"", "text/plain")
            file = self.root / "index.html"

        try:
            stat = file.stat()
            etag = f'"{stat.st_size:x}-{int(stat.st_mtime):x}"'
            extra = [("ETag", etag), ("Accept-Ranges", "bytes")]
            wanted = request.headers.get("Range")
            if not wanted and request.headers.get("If-None-Match") == etag:
                return _response(304, "Not Modified", b"",
                                 self._type(file), extra)
            body = file.read_bytes()
        except OSError as exc:
            self.log(f"Bản web: không đọc được {file.name}: {exc}")
            return _response(500, "Internal Server Error", b"", "text/plain")

        # Safari trên iPhone chỉ phát video khi máy chủ trả được từng đoạn
        # (Range) — cần cho video giữ màn hình sáng của bản web.
        part = _byte_range(wanted, len(body)) if wanted else None
        if part:
            start, end = part
            return _response(
                206, "Partial Content", body[start:end + 1], self._type(file),
                extra + [("Content-Range", f"bytes {start}-{end}/{len(body)}")])
        return _response(200, "OK", body, self._type(file), extra)

    @staticmethod
    def _type(file):
        suffix = file.suffix.lower()
        if suffix in TYPES:
            return TYPES[suffix]
        return mimetypes.guess_type(file.name)[0] or TYPES[""]


def _byte_range(header, size):
    """'bytes=0-1023' -> (0, 1023). Chỉ hỗ trợ một đoạn; sai dạng thì None
    và trả cả file, trình duyệt vẫn dùng được."""
    m = re.fullmatch(r"\s*bytes=(\d*)-(\d*)\s*", header or "")
    if not m or size == 0 or (m.group(1) == "" and m.group(2) == ""):
        return None
    if m.group(1) == "":                      # bytes=-500: 500 byte cuối
        start, end = max(0, size - int(m.group(2))), size - 1
    else:
        start = int(m.group(1))
        end = int(m.group(2)) if m.group(2) else size - 1
    end = min(end, size - 1)
    return (start, end) if start <= end else None


def page_url(ip, port, pair_code=None):
    """Địa chỉ mở bản web, kèm mã ghép cặp để quét QR là ghép luôn."""
    url = f"http://{ip}:{port}/"
    return url + f"#ghep={pair_code}" if pair_code else url

