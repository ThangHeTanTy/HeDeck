"""HeDeck Agent — chạy nền trên thiết bị Windows, nhận lệnh từ điện thoại.

Chạy:  python agent.py
Quét lại danh sách app:  python agent.py --rescan
"""

import argparse
import asyncio
import hashlib
import hmac
import json
import os
import secrets
import socket
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import websockets

import app_volume
import catalog
import perf
import power
import remote_input
import security
import updater
import win_control

PORT = 8787
SERVICE_TYPE = "_hedeck._tcp.local."
STATE_FILE = catalog.CONFIG_DIR / "agent.json"
PAIR_WINDOW = 300          # mã ghép cặp sống 5 phút
STATUS_INTERVAL = 1.5      # giây
UPDATE_INTERVAL = 12 * 3600  # hỏi GitHub bản mới mỗi 12 giờ
ALLOW_MACROS = True        # đặt False nếu không muốn điện thoại gõ phím vào máy
# Tăng mỗi khi giao thức với app thay đổi. App so số này để báo người dùng
# chạy lại agent sau khi cập nhật code — pull code xong mà quên tắt cửa sổ
# agent cũ thì nó vẫn chạy bản cũ, mọi tính năng mới im lặng không hoạt động.
AGENT_VERSION = 6
# đặt False nếu không muốn điện thoại điều khiển chuột và gõ phím từ xa
ALLOW_REMOTE_INPUT = True
ALLOW_POWER = True         # đặt False nếu không muốn điện thoại tắt/ngủ máy

log = lambda *a: print(time.strftime("[%H:%M:%S]"), *a, flush=True)


# --------------------------------------------------------------------------
# Trạng thái bền vững: token của các thiết bị đã ghép cặp
# --------------------------------------------------------------------------

def load_state():
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"devices": {}}


def save_state(state):
    catalog.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


class Agent:
    def __init__(self, rescan=False):
        self.state = load_state()
        self.guard = security.Guard(log=log)
        self._rescan_on_start = rescan
        # Chưa quét vội. Quét icon 63 app mất hàng chục giây tới vài phút, mà
        # trong lúc đó cổng phải mở sẵn để điện thoại kết nối được ngay.
        self.apps = []
        self.by_id = {}
        self.catalog_ready = False
        self.clients = set()          # websocket đã xác thực
        self._volume_watch = set()    # app_id có ô âm lượng trên deck
        self._scan_pool = ThreadPoolExecutor(
            max_workers=1, thread_name_prefix="hedeck-scan")
        self.pair_code = f"{secrets.randbelow(1000000):06d}"
        self.pair_until = time.time() + PAIR_WINDOW
        self.host_name = socket.gethostname()
        # Địa chỉ MAC và broadcast để điện thoại bật máy bằng Wake-on-LAN.
        self.wol = {}
        # Thứ tự xuất hiện của từng cửa sổ, để số 1, 2, 3... trên ô không
        # nhảy lung tung mỗi lần Windows đổi thứ tự xếp chồng.
        self._win_seq = {}
        self._next_seq = 0
        # "Thêm từ cửa sổ đang mở": mã ngắn -> chương trình. Điện thoại chỉ
        # gửi lại mã, không bao giờ gửi đường dẫn.
        self._running = {}
        self._icon_cache = {}
        # Điện thoại đang mở tab Hiệu năng. Không ai xem thì không đo, để
        # agent không tốn chút CPU nào của game.
        self._perf_watchers = set()
        self._perf = None
        # Bản mới trên GitHub, None nếu đang là bản mới nhất.
        self.update = None
        self.loop = None

    # -- tiện ích ---------------------------------------------------------

    async def run_blocking(self, fn, *args, **kwargs):
        return await self.loop.run_in_executor(None, lambda: fn(*args, **kwargs))

    async def run_scan(self, fn, *args):
        """Chạy việc quét ở luồng riêng của nó.

        Dùng chung luồng với vòng đo trạng thái thì quét dễ bị xếp hàng phía
        sau và trông như treo. Một luồng riêng bảo đảm quét luôn chạy được.
        """
        return await self.loop.run_in_executor(self._scan_pool, lambda: fn(*args))

    def _set_apps(self, apps):
        self.apps = apps
        self.by_id = {a["id"]: a for a in apps}
        self.catalog_ready = True

    async def load_catalog(self, rescan=False):
        """Hai chặng: gửi danh sách app ngay, icon bổ sung sau.

        Quét tên app mất khoảng một giây; trích icon mới là phần mất hàng chục
        giây tới vài phút. Tách ra để điện thoại dùng được ngay thay vì chờ.
        """
        self.catalog_ready = False
        log("Bắt đầu dựng danh mục ứng dụng...")

        # Đồng hồ canh chừng: quét quá lâu thì nói ra, đừng im lặng.
        async def watchdog():
            waited = 0
            while not self.catalog_ready:
                await asyncio.sleep(15)
                waited += 15
                if not self.catalog_ready:
                    log(f"Vẫn đang quét danh mục ({waited}s)...")

        watcher = self.loop.create_task(watchdog())

        try:
            apps = await asyncio.wait_for(
                self.run_scan(catalog.load, rescan or self._rescan_on_start),
                timeout=180,
            )
        except asyncio.TimeoutError:
            log("Quét danh sách quá 3 phút, bỏ qua. Chạy kiem_tra_quet.py "
                "để xem tắc ở đâu.")
            apps = self.apps or []
        except Exception as exc:
            import traceback
            log(f"LỖI khi quét danh sách: {exc}")
            traceback.print_exc()
            apps = self.apps or []
        finally:
            self._rescan_on_start = False
            watcher.cancel()

        # Chặng 1 — danh sách đã dùng được, mở khoá ngay.
        self._set_apps(apps)
        log(f"Danh sách sẵn sàng: {len(apps)} ứng dụng")
        await self.broadcast(
            {"t": "catalog", "apps": catalog.public_view(apps)}
        )
        if not apps:
            log("Danh mục trống. Thử: python agent.py --rescan")
            return

        # Chặng 2 — icon, chạy tiếp ở nền.
        missing = [a for a in apps if not a.get("icon")]
        if not missing:
            return
        log(f"Đang lấy icon cho {len(missing)} ứng dụng...")
        try:
            got = await self.run_scan(catalog.attach_icons, apps)
        except Exception as exc:
            import traceback
            log(f"LỖI khi lấy icon: {exc}")
            traceback.print_exc()
            return

        try:
            await self.run_scan(catalog.save, apps)
        except Exception as exc:
            log(f"Không lưu được danh mục: {exc}")

        self._set_apps(apps)
        log(f"Đã lấy {got}/{len(apps)} icon")
        await self.broadcast(
            {"t": "catalog", "apps": catalog.public_view(apps)}
        )

    def _spawn(self, coro):
        """Chạy nền nhưng không nuốt lỗi — task chết lặng lẽ rất khó lần ra."""
        task = self.loop.create_task(coro)
        task.add_done_callback(self._report_task)
        return task

    @staticmethod
    def _report_task(task):
        if task.cancelled():
            return
        exc = task.exception()
        if exc:
            import traceback
            log(f"LỖI ở tác vụ nền: {exc}")
            traceback.print_exception(type(exc), exc, exc.__traceback__)

    async def broadcast(self, payload):
        message = json.dumps(payload)
        for ws in list(self.clients):
            try:
                await ws.send(message)
            except Exception:
                self.clients.discard(ws)

    def new_pair_code(self, announce=True):
        self.pair_code = f"{secrets.randbelow(1000000):06d}"
        self.pair_until = time.time() + PAIR_WINDOW
        if announce:
            log(f"Mã ghép cặp mới: {self.pair_code} — còn hiệu lực 5 phút")
        return self.pair_code

    @property
    def code_expired(self):
        return time.time() > self.pair_until

    def code_status(self):
        if self.code_expired:
            return "đã hết hạn — nhấn Enter để lấy mã mới"
        left = int(self.pair_until - time.time())
        return f"còn {left // 60}p{left % 60:02d}s"

    def print_banner(self, ip, port):
        """In lại bảng thông tin, dùng cả lúc khởi động lẫn khi làm mới mã."""
        st = self.guard.status()
        lines = [
            f"HeDeck Agent v{AGENT_VERSION} · {self.host_name}",
            f"Phiên bản: {updater.VERSION or ('bản tự đóng gói' if updater.FROZEN else 'chạy từ mã nguồn')}",
            f"Địa chỉ  : ws://{ip}:{port}",
            f"Mã ghép  : {self.pair_code}  ({self.code_status()})",
            f"Ứng dụng : {len(self.apps) if self.catalog_ready else 'đang quét…'}"
            f"  (danh mục v{catalog.CATALOG_VERSION})",
            f"Bảo vệ   : chỉ mạng nội bộ · chữ ký Ed25519 · "
            f"{st['banned']} IP bị chặn",
            f"Điện thoại: {len(self.state['devices'])} đã ghép cặp",
            f"Bật từ xa: {power.describe(self.wol)}",
        ]
        width = max(len(line) for line in lines) + 4
        print()
        print("  ┌" + "─" * width + "┐")
        for line in lines:
            pad = width - len(line) - 3
            print(f"  │  {line}" + " " * pad + "│")
        print("  └" + "─" * width + "┘")
        for warning in self.wol.get("warnings", []):
            print(f"  [!] {warning}")
        self.print_update()
        print("  Enter: mã mới · U: gỡ chặn IP · D: xoá điện thoại đã ghép · "
              + ("C: cập nhật · " if updater.can_self_update(self.update) else "")
              + "Ctrl+C: thoát\n")

    def print_update(self):
        info = self.update
        if not info:
            return
        print(f"  [↑] Có bản mới {info['version']} trên GitHub:")
        for line in updater.short_notes(info["notes"]):
            print(f"        {line}")
        if updater.can_self_update(info):
            print("      Gõ C rồi Enter để cập nhật, agent tự mở lại sau đó.")
        elif updater.FROZEN:
            print(f"      Tải tại: {info['page']}")
        else:
            print("      Đang chạy từ mã nguồn: chạy git pull rồi mở lại "
                  "run_agent.bat.")

    async def watch_console(self, ip, port):
        """Nhấn Enter trong cửa sổ agent là có mã mới, khỏi phải khởi động lại."""
        while True:
            try:
                line = await self.loop.run_in_executor(None, sys.stdin.readline)
            except Exception:
                return  # chạy dạng .exe không có console thì thôi
            if not line:
                return
            command = line.strip().lower()
            if command == "u":
                self.guard.unban_all()
            elif command == "c":
                if not updater.can_self_update(self.update):
                    log("Không có bản mới để cập nhật.")
                    continue
                await self.self_update()
                continue  # cập nhật hỏng thì vẫn chạy tiếp bản cũ
            elif command == "d":
                count = len(self.state["devices"])
                self.state["devices"] = {}
                save_state(self.state)
                log(f"Đã xoá {count} điện thoại đã ghép cặp. "
                    "Hãy ghép cặp lại từ điện thoại.")
            else:
                self.new_pair_code(announce=False)
            self.print_banner(ip, port)

    async def update_loop(self):
        """Hỏi GitHub bản mới lúc khởi động rồi cứ 12 giờ một lần.

        Chỉ báo trong cửa sổ agent; người dùng gõ C thì mới cài.
        """
        await asyncio.sleep(5)  # để bảng thông tin in xong trước
        while True:
            try:
                info = await self.run_blocking(updater.check)
            except Exception as exc:
                info = None
                log("Không kiểm tra được bản mới:", exc)
            if info and info != self.update:
                self.update = info
                print()
                self.print_update()
                print()
            await asyncio.sleep(UPDATE_INTERVAL)

    async def self_update(self):
        info = self.update
        log(f"Bắt đầu cập nhật lên {info['version']}...")
        try:
            await self.run_blocking(updater.install, info, log)
        except Exception as exc:
            log(f"Cập nhật thất bại: {exc}. Agent tiếp tục chạy bản cũ.")
            return
        log("Đã cài xong, đang mở lại agent...")
        updater.restart()

    def verify(self, ip, device_id, ts, nonce, sig, claimed_key=None):
        """Xác thực bằng chữ ký. Agent chỉ giữ khoá công khai của thiết bị.

        Trả về (ok, lý_do, mã_lỗi). `mã_lỗi` giúp app biết nên thử lại hay
        phải ghép cặp lại, thay vì đoán qua nội dung câu chữ.
        """
        dev = self.state["devices"].get(device_id)
        if not dev or not dev.get("pubkey"):
            return False, "Thiết bị chưa được ghép cặp", "unknown_device"
        if not security.Guard.fresh_timestamp(ts):
            return False, "Lệch giờ giữa hai máy quá 2 phút", "clock_skew"
        if not self.guard.fresh_nonce(str(nonce)):
            return False, "Yêu cầu bị lặp lại", "replay"

        stored = dev["pubkey"]

        # Điện thoại gửi kèm khoá đang dùng. Lệch với khoá đã lưu nghĩa là nó
        # đã sinh khoá mới — chuyện thường gặp sau khi cài lại app. Nói thẳng
        # ra để app đưa người dùng đi ghép cặp lại, thay vì thử lại vô ích.
        if claimed_key and claimed_key != stored:
            log(f"Khoá điện thoại đã đổi: đã lưu {security.fingerprint(stored)}, "
                f"máy gửi {security.fingerprint(claimed_key)}")
            return (False, "Khoá điện thoại đã thay đổi, cần ghép cặp lại",
                    "key_changed")

        message = f"{device_id}|{ts}|{nonce}".encode()
        if not security.verify_signature(stored, message, str(sig)):
            log(f"Chữ ký không khớp khoá {security.fingerprint(stored)} "
                f"(thiết bị {device_id}, ts={ts})")
            return False, "Chữ ký không hợp lệ", "bad_signature"
        return True, "", ""

    # -- vòng phát trạng thái --------------------------------------------

    def snapshot(self):
        """(trạng thái từng app, app đang ở trước).

        App đang ở trước dùng để điện thoại tự đổi trang như Stream Deck. Gửi
        mọi app khớp chứ không chỉ một: Chrome có thể khớp cả ô "Google
        Chrome" lẫn ô "Chrome - Công việc", trang nào gắn với cái nào cũng
        phải nhảy được.
        """
        if not self.catalog_ready:
            return {}, {"apps": [], "desk": False}
        out = {}
        want_volume = self._volume_watch
        # Một lượt duyệt cửa sổ cho tất cả app, thay vì một lượt mỗi app.
        table = win_control.window_table()
        fg = win_control.foreground()

        alive = {row[0] for row in table}
        for hwnd in list(self._win_seq):
            if hwnd not in alive:
                del self._win_seq[hwnd]
        for hwnd, _, _ in table:
            if hwnd not in self._win_seq:
                self._next_seq += 1
                self._win_seq[hwnd] = self._next_seq

        front = {"apps": [], "desk": win_control.is_desktop(fg)}

        for app in self.apps:
            procs, dirs = catalog.match_of(app)
            mine = win_control.windows_in(table, procs, dirs)
            if not mine:
                continue
            if fg in mine:
                front["apps"].append(app["id"])
            entry = {"running": True, "windows": len(mine)}
            # Từ hai cửa sổ trở lên mới cần danh sách để đánh số 1, 2, 3...
            if len(mine) >= 2:
                mine.sort(key=lambda h: self._win_seq.get(h, 0))
                entry["wins"] = [
                    {"h": h, "t": win_control.window_title(h)[:120],
                     "a": h == fg}
                    for h in mine
                ]
            # Chỉ hỏi âm lượng của app đang có ô âm lượng trên deck. Hỏi tất
            # cả mỗi giây rưỡi thì tốn vô ích.
            if app["id"] in want_volume:
                state = app_volume.get_state(app["exe"])
                if state:
                    entry["volume"], entry["muted"] = state
            out[app["id"]] = entry
        return out, front

    async def send_status(self):
        if not self.clients:
            return
        try:
            apps, front = await self.run_blocking(self.snapshot)
        except Exception as exc:
            log("Lỗi lấy trạng thái:", exc)
            return
        msg = json.dumps({"t": "status", "apps": apps, "fg": front})
        dead = []
        for ws in list(self.clients):
            try:
                await ws.send(msg)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.clients.discard(ws)

    async def status_loop(self):
        while True:
            await asyncio.sleep(STATUS_INTERVAL)
            await self.send_status()

    async def perf_loop(self):
        """Mỗi giây đo một lần, chỉ gửi cho điện thoại đang xem tab Hiệu năng."""
        while True:
            await asyncio.sleep(1.0)
            watchers = [ws for ws in self._perf_watchers if ws in self.clients]
            self._perf_watchers = set(watchers)
            if not watchers:
                continue
            try:
                if self._perf is None:
                    self._perf = await self.run_blocking(perf.PerfMonitor)
                pid = await self.run_blocking(win_control.foreground_pid)
                sample = await self.run_blocking(self._perf.sample, pid)
            except Exception as exc:
                log("Lỗi đo hiệu năng:", exc)
                continue
            msg = json.dumps(sample)
            for ws in watchers:
                try:
                    await ws.send(msg)
                except Exception:
                    self._perf_watchers.discard(ws)

    async def status_soon(self, delay=0.6):
        """Đóng hay chọn cửa sổ xong thì báo lại ngay, khỏi chờ nhịp 1,5 giây
        — số trên ô phải khớp với cửa sổ thật càng sớm càng tốt."""
        await asyncio.sleep(delay)
        await self.send_status()

    def _owns_window(self, app, hwnd):
        procs, dirs = catalog.match_of(app)
        return hwnd in win_control.windows_of(procs, dirs)

    def _describe_running(self):
        """Chạy ở luồng nền: liệt kê chương trình đang mở kèm tên và icon."""
        out, tokens = [], {}
        for prog in win_control.running_programs():
            path = prog["path"]
            token = hashlib.sha1(path.encode()).hexdigest()[:12]
            existing = next(
                (a["id"] for a in self.apps
                 if win_control.count_windows(
                     [(0, prog["exe"], path)], *catalog.match_of(a))), None)
            if path not in self._icon_cache:
                try:
                    self._icon_cache[path] = win_control.extract_icon_png(path)
                except Exception:
                    self._icon_cache[path] = None
            icon = self._icon_cache[path]
            name = win_control.describe_exe(path)
            tokens[token] = (path, name, icon)
            out.append({
                "token": token, "name": name, "exe": prog["exe"],
                "windows": prog["windows"], "title": prog["title"][:120],
                "app_id": existing,
                "icon": icon[0] if icon else None,
                "icon_native": icon[1] if icon else 0,
            })
        out.sort(key=lambda r: (r["app_id"] is not None, r["name"].lower()))
        return out, tokens

    async def adopt(self, token):
        found = self._running.get(token)
        if not found:
            return {"t": "error",
                    "msg": "Danh sách đã cũ, mở lại danh sách cửa sổ"}
        path, name, icon = found
        app = catalog.add_custom(name, path)
        if app["id"] not in self.by_id:
            if icon:
                app["icon"], app["icon_native"] = icon
            self._set_apps(sorted(self.apps + [app],
                                  key=lambda a: a["name"].lower()))
            await self.run_scan(catalog.save, self.apps)
            await self.broadcast(
                {"t": "catalog", "apps": catalog.public_view(self.apps)})
            log(f"Đã thêm từ cửa sổ đang mở: {name} ({path})")
        return {"t": "adopted", "app_id": app["id"]}

    async def run_scene(self, steps):
        """Ô chế độ: mở/đóng lần lượt từng app. Chạy nền vì đóng app có thể
        mất vài giây mỗi cái, không được chặn các lệnh khác."""
        names = []
        for app, close in steps:
            procs, dirs = catalog.match_of(app)
            try:
                if close:
                    await self.run_blocking(win_control.close_app, procs,
                                            dirs=dirs)
                # Xét theo cửa sổ chứ không theo tiến trình: app chỉ còn chạy
                # ngầm ở khay hệ thống (Discord, Zalo...) hay explorer.exe
                # vốn luôn chạy vẫn phải được mở cửa sổ ra.
                elif not await self.run_blocking(win_control.windows_of,
                                                 procs, dirs):
                    await self.run_blocking(
                        win_control.launch, app["path"],
                        app.get("args", ""), app.get("workdir", ""))
                    await asyncio.sleep(0.4)
            except Exception as exc:
                log(f"chế độ: lỗi ở {app['name']}: {exc}")
            names.append(("đóng " if close else "mở ") + app["name"])
        log("chế độ:", ", ".join(names))
        await self.status_soon(1.0)

    # -- xử lý lệnh -------------------------------------------------------

    async def handle_command(self, ws, msg):
        kind = msg.get("t")

        if kind == "ping":
            return {"t": "pong", "ts": msg.get("ts")}

        if kind == "watch_volume":
            ids = msg.get("app_ids")
            self._volume_watch = set(ids) if isinstance(ids, list) else set()
            return None

        if kind == "catalog":
            if not self.catalog_ready:
                # Đang quét: báo để app hiện trạng thái chờ thay vì tưởng lỗi.
                return {"t": "catalog_pending"}
            return {"t": "catalog", "apps": catalog.public_view(self.apps)}

        if kind == "rescan":
            self._spawn(self.load_catalog(rescan=True))
            return {"t": "catalog_pending"}

        if kind == "launch":
            if not self.catalog_ready:
                return {"t": "error", "msg": "Đang quét danh mục, thử lại sau vài giây"}
            app = self.by_id.get(msg.get("app_id"))
            if not app:
                return {"t": "error", "msg": "Không tìm thấy ứng dụng"}
            procs, dirs = catalog.match_of(app)
            result = await self.run_blocking(
                win_control.open_or_focus, app["path"], procs,
                args=app.get("args", ""), workdir=app.get("workdir", ""),
                toggle=bool(msg.get("toggle", True)), dirs=dirs,
                wait=45 if catalog.is_launcher_app(app) else 12,
            )
            log(f"launch {app['name']} -> {result}")
            return {"t": "launched", "app_id": app["id"], "result": result}

        if kind == "close":
            if not self.catalog_ready:
                return {"t": "error", "msg": "Đang quét danh mục, thử lại sau vài giây"}
            app = self.by_id.get(msg.get("app_id"))
            if not app:
                return {"t": "error", "msg": "Không tìm thấy ứng dụng"}
            procs, dirs = catalog.match_of(app)
            result = await self.run_blocking(
                win_control.close_app, procs, dirs=dirs)
            log(f"close {app['name']} -> {result}")
            return {"t": "closed", "app_id": app["id"], "result": result}

        if kind == "app_volume":
            if not self.catalog_ready:
                return {"t": "error", "msg": "Đang quét danh mục, thử lại sau"}
            app = self.by_id.get(msg.get("app_id"))
            if not app:
                return {"t": "error", "msg": "Không tìm thấy ứng dụng"}
            action = msg.get("action", "")
            ok, why, level, muted = await self.run_blocking(
                app_volume.apply, app["exe"], action
            )
            if not ok:
                return {"t": "error", "msg": why}
            log(f"âm lượng {app['name']} -> "
                f"{'tắt tiếng' if muted else f'{level * 100:.0f}%'}")
            return {"t": "volume", "app_id": app["id"],
                    "volume": level, "muted": muted}

        if kind in ("focus_window", "close_window"):
            app = self.by_id.get(msg.get("app_id"))
            hwnd = msg.get("hwnd")
            if not app or not isinstance(hwnd, int):
                return {"t": "error", "msg": "Không tìm thấy cửa sổ"}
            # Chỉ cho đụng vào cửa sổ của đúng app đó. Điện thoại không thể
            # gửi một số hwnd bất kỳ để đóng cửa sổ của chương trình khác.
            if not await self.run_blocking(self._owns_window, app, hwnd):
                return {"t": "error", "msg": "Cửa sổ đã đóng hoặc không thuộc app này"}
            fn = (win_control.focus_or_minimize if kind == "focus_window"
                  else win_control.close_window)
            result = await self.run_blocking(fn, hwnd)
            self._spawn(self.status_soon())
            return {"t": "window", "app_id": app["id"], "hwnd": hwnd,
                    "result": result}

        if kind == "perf_watch":
            if msg.get("on"):
                self._perf_watchers.add(ws)
            else:
                self._perf_watchers.discard(ws)
            return None

        if kind == "running":
            out, tokens = await self.run_blocking(self._describe_running)
            self._running = tokens
            return {"t": "running", "apps": out}

        if kind == "adopt":
            if not self.catalog_ready:
                return {"t": "error", "msg": "Đang quét danh mục, thử lại sau"}
            return await self.adopt(msg.get("token"))

        if kind == "scene":
            if not self.catalog_ready:
                return {"t": "error", "msg": "Đang quét danh mục, thử lại sau"}
            raw = msg.get("steps")
            steps = []
            for step in (raw if isinstance(raw, list) else [])[:20]:
                if not isinstance(step, dict):
                    continue
                app = self.by_id.get(step.get("app_id"))
                if app:
                    steps.append((app, bool(step.get("close", False))))
            if not steps:
                return {"t": "error", "msg": "Chế độ không có app nào hợp lệ"}
            self._spawn(self.run_scene(steps))
            return {"t": "ok", "scene": len(steps)}

        if kind == "media":
            action = msg.get("action", "")
            if action not in win_control.MEDIA_KEYS:
                return {"t": "error", "msg": f"Phím media lạ: {action}"}
            await self.run_blocking(win_control.press_media, action)
            return {"t": "ok", "action": action}

        if kind == "power":
            if not ALLOW_POWER:
                return {"t": "error", "msg": "Lệnh nguồn đang bị tắt trên agent"}
            action = msg.get("action", "")
            if action not in power.ACTIONS:
                return {"t": "error", "msg": f"Hành động nguồn lạ: {action}"}
            force = bool(msg.get("force", False))
            log(f"nguồn: {action}{' (buộc đóng app)' if force else ''}")
            # Trả lời trước, làm sau: tắt máy xong thì hết đường gửi tin.
            self._spawn(self.power_later(action, force))
            return {"t": "power", "action": action}

        if kind in ("mouse_move", "mouse_button", "mouse_scroll",
                    "type_text", "key"):
            return self.remote_input(kind, msg)

        if kind == "macro":
            if not ALLOW_MACROS:
                return {"t": "error", "msg": "Macro đang bị tắt trên agent"}
            keys = msg.get("keys")
            combos = keys if isinstance(keys, list) else [keys]
            combos = [c for c in combos if isinstance(c, str) and c.strip()]
            if not combos:
                return {"t": "error", "msg": "Macro rỗng"}
            try:
                await self.run_blocking(win_control.press_sequence, combos)
            except ValueError as exc:
                return {"t": "error", "msg": str(exc)}
            log("macro", " > ".join(combos))
            return {"t": "ok", "keys": combos}

        return {"t": "error", "msg": f"Lệnh không hỗ trợ: {kind}"}

    def remote_input(self, kind, msg):
        """Touchpad và bàn phím ảo. Gọi thẳng, không qua luồng khác, để các
        lệnh chạy đúng thứ tự gửi. Di chuột không trả lời gì — 60 lần mỗi
        giây mà lần nào cũng trả lời thì chỉ tốn mạng."""
        if not ALLOW_REMOTE_INPUT:
            return {"t": "error", "msg": "Điều khiển từ xa đang bị tắt trên agent"}
        try:
            if kind == "mouse_move":
                remote_input.move(msg.get("dx", 0), msg.get("dy", 0))
            elif kind == "mouse_button":
                remote_input.button(msg.get("button", "left"),
                                    msg.get("action", "click"))
            elif kind == "mouse_scroll":
                remote_input.scroll(msg.get("dy", 0), msg.get("dx", 0))
            elif kind == "type_text":
                remote_input.type_text(msg.get("text", ""))
            elif kind == "key":
                win_control.press_hotkey(str(msg.get("combo", "")))
        except (ValueError, TypeError) as exc:
            return {"t": "error", "msg": str(exc)}
        return None

    async def power_later(self, action, force):
        await asyncio.sleep(0.8)
        await self.run_blocking(power.apply, action, force)

    # -- vòng đời một kết nối ---------------------------------------------

    async def serve(self, ws):
        peer = ws.remote_address[0] if ws.remote_address else "?"

        allowed, why = self.guard.check(peer)
        if not allowed:
            try:
                await ws.send(json.dumps({"t": "error", "msg": why, "fatal": True}))
            except Exception:
                pass
            await ws.close()
            return

        authed = False
        try:
            async for raw in ws:
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    await ws.send(json.dumps({"t": "error", "msg": "JSON không hợp lệ"}))
                    continue

                kind = msg.get("t")

                if not authed and kind == "pair":
                    if self.code_expired:
                        log("Có máy xin ghép cặp nhưng mã đã hết hạn "
                            "— nhấn Enter ở cửa sổ này để lấy mã mới.")
                        await ws.send(json.dumps({
                            "t": "error",
                            "msg": "Mã đã hết hạn. Nhấn Enter ở cửa sổ agent "
                                   "trên thiết bị để lấy mã mới.",
                        }))
                        continue

                    pubkey = msg.get("pubkey")
                    if not pubkey:
                        await ws.send(json.dumps({
                            "t": "error", "msg": "Thiếu khoá công khai"}))
                        continue

                    if str(msg.get("code", "")) != self.pair_code:
                        self.guard.record_failure(peer, "nhập sai mã ghép cặp")
                        await asyncio.sleep(1.0)   # làm chậm dò mã
                        await ws.send(json.dumps({
                            "t": "error", "msg": "Mã không đúng"}))
                        continue

                    device_id = msg.get("device_id") or secrets.token_hex(8)
                    self.state["devices"][device_id] = {
                        "pubkey": pubkey,
                        "name": msg.get("device_name", "Điện thoại"),
                        "ip": peer,
                        "paired_at": int(time.time()),
                    }
                    save_state(self.state)
                    self.guard.record_success(peer)
                    authed = True
                    self.clients.add(ws)
                    log(f"Đã ghép cặp: {msg.get('device_name')} ({peer}) "
                        f"vân tay {security.fingerprint(pubkey)}")
                    await ws.send(json.dumps({
                        "t": "paired", "device_id": device_id,
                        "host_name": self.host_name,
                        "fingerprint": security.fingerprint(pubkey),
                        "wol": power.public_view(self.wol),
                        "v": AGENT_VERSION,
                    }))
                    self.new_pair_code()
                    continue

                if not authed and kind == "auth":
                    ok, why, code = self.verify(
                        peer, msg.get("device_id"), msg.get("ts"),
                        msg.get("nonce"), msg.get("sig"), msg.get("pubkey"),
                    )
                    if not ok:
                        if code == "unknown_device":
                            log("Điện thoại nhớ ghép cặp cũ nhưng agent đã "
                                "xoá danh sách điện thoại. Trên app: bánh răng "
                                "→ Quên thiết bị này, rồi ghép cặp lại.")
                        # Khoá đổi hoặc thiết bị lạ đều là tình huống bình
                        # thường sau khi cài lại app hay xoá danh sách, không
                        # phải dấu hiệu tấn công — đừng tính vào bộ đếm chặn.
                        if code not in ("key_changed", "clock_skew",
                                        "unknown_device"):
                            self.guard.record_failure(
                                peer, f"xác thực hỏng ({why})")
                        await ws.send(json.dumps({
                            "t": "error", "msg": why,
                            "code": code, "fatal": True}))
                        await ws.close()
                        return
                    self.guard.record_success(peer)
                    authed = True
                    self.clients.add(ws)
                    name = self.state["devices"][msg["device_id"]].get("name")
                    log(f"Đã kết nối: {name} ({peer})")
                    await ws.send(json.dumps({
                        "t": "auth_ok", "host_name": self.host_name,
                        "wol": power.public_view(self.wol),
                        "v": AGENT_VERSION}))
                    continue

                if not authed:
                    self.guard.record_failure(peer, "gửi lệnh khi chưa xác thực")
                    await ws.send(json.dumps({"t": "error", "msg": "Chưa xác thực",
                                              "fatal": True}))
                    await ws.close()
                    return

                reply = await self.handle_command(ws, msg)
                if reply:
                    await ws.send(json.dumps(reply))
        except websockets.ConnectionClosed:
            pass
        except Exception as exc:
            log("Lỗi kết nối:", exc)
        finally:
            self.clients.discard(ws)


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rescan", action="store_true", help="Quét lại Start Menu")
    ap.add_argument("--port", type=int, default=PORT)
    args = ap.parse_args()

    updater.cleanup()
    agent = Agent(rescan=args.rescan)
    agent.loop = asyncio.get_running_loop()
    ip = lan_ip()

    zc = None
    try:
        from zeroconf import ServiceInfo
        from zeroconf.asyncio import AsyncZeroconf
        zc = AsyncZeroconf()
        info = ServiceInfo(
            SERVICE_TYPE,
            f"{agent.host_name}.{SERVICE_TYPE}",
            addresses=[socket.inet_aton(ip)],
            port=args.port,
            properties={"host": agent.host_name, "v": "1"},
        )
        await zc.async_register_service(info)
    except Exception as exc:
        log("Không bật được mDNS (vẫn dùng được bằng cách nhập IP):", exc)

    # Một lượt PowerShell mất 1–3 giây, chấp nhận được lúc khởi động. Hỏng thì
    # wol_info tự trả về danh sách rỗng kèm cảnh báo, không chặn agent.
    agent.wol = await agent.run_blocking(power.wol_info, ip)

    agent.print_banner(ip, args.port)

    agent._spawn(agent.status_loop())
    agent._spawn(agent.perf_loop())
    agent._spawn(agent.watch_console(ip, args.port))
    agent._spawn(agent.update_loop())
    # Dựng danh mục ở nền. Cổng đã mở trước nên điện thoại kết nối được ngay,
    # không phải chờ quét xong.
    agent._spawn(agent.load_catalog())

    # Ngay sau khi tự cập nhật, bản cũ có thể chưa nhả cổng kịp: thử lại vài
    # giây thay vì chết với lỗi "cổng đã có người dùng".
    for attempt in range(10):
        try:
            server = await websockets.serve(
                agent.serve, "0.0.0.0", args.port,
                ping_interval=20, ping_timeout=20, max_size=32 * 2 ** 20)
            break
        except OSError:
            if attempt == 9:
                raise
            await asyncio.sleep(1)
    try:
        await asyncio.Future()
    finally:
        server.close()


if __name__ == "__main__":
    if sys.platform != "win32":
        print("Agent này chỉ chạy trên Windows.")
        sys.exit(1)
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nĐã dừng agent.")
