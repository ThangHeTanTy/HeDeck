"""Cửa sổ agent và icon ở khay hệ thống (góc phải thanh tác vụ).

Bấm X chỉ ẩn cửa sổ, agent vẫn chạy ngầm và điện thoại vẫn điều khiển được.
Icon nằm trong khu "Show hidden icons" (mũi tên ^); chuột phải icon → Thoát
mới tắt hẳn agent.

Agent (asyncio) chạy ở luồng riêng. Tk chỉ được đụng tới từ luồng chính, nên
mọi thứ từ luồng khác — dòng log, lệnh từ menu khay — đi qua một hàng đợi mà
luồng chính đọc mỗi 100 ms.
"""

import asyncio
import io
import os
import queue
import sys
import threading
import webbrowser
from pathlib import Path

import tkinter as tk
from tkinter import messagebox, scrolledtext

from PIL import Image, ImageDraw

import catalog
import instance
import power
import updater

try:
    from PIL import ImageTk
except ImportError:
    ImageTk = None

# Không có pystray (hoặc máy không có khay) thì vẫn chạy được, chỉ là bấm X
# sẽ thu nhỏ xuống thanh tác vụ thay vì ẩn vào khay.
try:
    if os.environ.get("HEDECK_NO_TRAY"):
        raise ImportError
    import pystray
except Exception:
    pystray = None

LOG_FILE = catalog.CONFIG_DIR / "agent.log"
LOG_LIMIT = 1024 * 1024
MAX_LINES = 1500

BG = "#0F1218"
SURFACE = "#171B23"
LINE = "#262C38"
TEXT = "#E8EAF0"
MUTED = "#8A90A0"
ACCENT = "#7B6EF6"
GOOD = "#3FB27F"
WARN = "#E0A030"
BAD = "#E05A5A"


class _LogStream(io.TextIOBase):
    """Thay cho stdout/stderr: chép mọi dòng log vào cửa sổ và file log.

    Chạy ngầm thì không còn cửa sổ lệnh, file log là chỗ duy nhất xem lại
    được lỗi sau khi đã xảy ra.
    """

    def __init__(self, sink):
        super().__init__()
        self._sink = sink
        self._lock = threading.Lock()
        catalog.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        try:
            if LOG_FILE.exists() and LOG_FILE.stat().st_size > LOG_LIMIT:
                os.replace(LOG_FILE, LOG_FILE.with_suffix(".log.1"))
            # Ghi từng dòng ngay: agent có thể bị tắt đột ngột (os._exit).
            self._file = open(LOG_FILE, "a", encoding="utf-8", buffering=1)
        except OSError:
            self._file = None

    def writable(self):
        return True

    def write(self, text):
        if not text:
            return 0
        self._sink(text)
        if self._file:
            with self._lock:
                try:
                    self._file.write(text)
                except OSError:
                    pass
        return len(text)

    def flush(self):
        if self._file:
            with self._lock:
                try:
                    self._file.flush()
                except OSError:
                    pass


def _icon_image():
    here = Path(__file__).resolve().parent
    for path in (Path(getattr(sys, "_MEIPASS", here)) / "icon.png",
                 here.parent / "flutter_app" / "assets" / "icon" / "icon.png"):
        try:
            if path.exists():
                return Image.open(path).convert("RGBA").resize((64, 64))
        except Exception:
            pass
    # Không tìm thấy logo thì vẽ tạm một ô chữ H.
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 2, 62, 62), radius=14, fill=ACCENT)
    d.rectangle((18, 16, 25, 48), fill="white")
    d.rectangle((39, 16, 46, 48), fill="white")
    d.rectangle((18, 29, 46, 35), fill="white")
    return img


def _windows_setup():
    """Chữ nét trên màn hình độ phân giải cao, icon riêng trên thanh tác vụ."""
    if sys.platform != "win32":
        return
    import ctypes
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        pass
    try:
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
            "HeDeck.Agent")
    except Exception:
        pass


class AgentWindow:
    def __init__(self, start_hidden):
        self.queue = queue.Queue()
        self.agent = None
        self.ip = ""
        self.port = 0
        self.thread = None
        self._told_tray = False
        self._seen_update = None

        # Chuyển log vào cửa sổ ngay từ đầu, kể cả lỗi lúc dựng giao diện.
        sys.stdout = sys.stderr = _LogStream(self.write_log)

        _windows_setup()
        self.image = _icon_image()
        self.root = tk.Tk()
        self.root.title("HeDeck Agent")
        self.root.configure(bg=BG)
        self.root.geometry("560x700")
        self.root.minsize(480, 520)
        self.root.protocol("WM_DELETE_WINDOW", self.hide)
        if ImageTk:
            try:
                self._tk_icon = ImageTk.PhotoImage(self.image)
                self.root.iconphoto(True, self._tk_icon)
            except Exception:
                pass
        self._build()

        self.icon = self._make_tray()
        if start_hidden and self.icon:
            self.root.withdraw()
        instance.on_show_request(lambda: self.queue.put(("show", None)))
        updater.before_restart.append(self._remove_tray)

    # -- dựng giao diện ---------------------------------------------------

    def _label(self, parent, text="", size=10, color=TEXT, bold=False, **kw):
        font = ("Segoe UI", size, "bold" if bold else "normal")
        return tk.Label(parent, text=text, bg=parent["bg"], fg=color,
                        font=font, anchor="w", justify="left", **kw)

    def _button(self, parent, text, command, primary=False):
        return tk.Button(
            parent, text=text, command=command, relief="flat", bd=0,
            padx=12, pady=6, cursor="hand2", font=("Segoe UI", 9),
            bg=ACCENT if primary else LINE, fg="white" if primary else TEXT,
            activebackground="#9488FF" if primary else "#333A48",
            activeforeground="white")

    def _build(self):
        root = self.root
        head = tk.Frame(root, bg=BG, padx=18, pady=14)
        head.pack(fill="x")
        self.title = self._label(head, "HeDeck Agent", 15, bold=True)
        self.title.pack(anchor="w")
        self.state_label = self._label(head, "Đang khởi động…", 9, MUTED)
        self.state_label.pack(anchor="w")

        card = tk.Frame(root, bg=SURFACE, padx=18, pady=14,
                        highlightthickness=1, highlightbackground=LINE)
        card.pack(fill="x", padx=14)
        self._label(card, "Mã ghép cặp", 9, MUTED).grid(row=0, column=0,
                                                       sticky="w")
        self.code = self._label(card, "------", 28, ACCENT, bold=True)
        self.code.grid(row=1, column=0, sticky="w")
        self.code_status = self._label(card, "", 9, MUTED)
        self.code_status.grid(row=2, column=0, sticky="w")
        self._button(card, "Mã mới", self.new_code, primary=True).grid(
            row=1, column=1, sticky="e", padx=(12, 0))
        card.columnconfigure(0, weight=1)

        info = tk.Frame(root, bg=BG, padx=18, pady=10)
        info.pack(fill="x")
        self.info = {}
        for row, key in enumerate(("Địa chỉ", "Ứng dụng", "Điện thoại",
                                   "Bật từ xa", "Phiên bản")):
            self._label(info, key, 9, MUTED).grid(row=row, column=0,
                                                  sticky="w", padx=(0, 14))
            self.info[key] = self._label(info, "", 9)
            self.info[key].grid(row=row, column=1, sticky="w")

        self.update_bar = tk.Frame(root, bg="#2A2440", padx=14, pady=8)
        self.update_text = self._label(self.update_bar, "", 9, TEXT)
        self.update_text.pack(side="left", fill="x", expand=True)
        self.update_button = self._button(self.update_bar, "Cập nhật",
                                          self.ask_update, primary=True)
        self.update_button.pack(side="right")

        tools = self.tools = tk.Frame(root, bg=BG, padx=14)
        tools.pack(fill="x")
        self._button(tools, "Gỡ chặn IP", self.unban).pack(side="left")
        self._button(tools, "Xoá điện thoại đã ghép",
                     self.forget).pack(side="left", padx=8)
        self._button(tools, "Ẩn xuống khay", self.hide).pack(side="right")

        # Dòng nhắc đặt trước để luôn còn chỗ, khung log co giãn phần còn lại.
        self.hint = self._label(
            root, "Bấm X: agent vẫn chạy ngầm ở khay hệ thống (mũi tên ^ góc "
            "phải thanh tác vụ). Chuột phải icon HeDeck → Thoát để tắt hẳn.",
            8, MUTED, wraplength=520)
        self.hint.configure(padx=18)
        self.hint.pack(side="bottom", fill="x", pady=(0, 10))

        self.log = scrolledtext.ScrolledText(
            root, bg=SURFACE, fg="#C9CDD8", insertbackground=TEXT,
            relief="flat", bd=0, font=("Consolas", 9), wrap="word",
            padx=10, pady=8, height=12)
        self.log.pack(fill="both", expand=True, padx=14, pady=(10, 6))
        self.log.configure(state="disabled")

    def _make_tray(self):
        if pystray is None:
            self.hint.configure(text="Bấm X để thu nhỏ. Thiếu thư viện pystray "
                                "nên chưa ẩn được vào khay hệ thống.")
            return None
        put = self.queue.put
        menu = pystray.Menu(
            pystray.MenuItem("Mở HeDeck Agent", lambda: put(("show", None)),
                             default=True),
            pystray.MenuItem("Mã ghép cặp mới", lambda: put(("code", None))),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Thoát HeDeck Agent", lambda: put(("quit", None))),
        )
        try:
            icon = pystray.Icon("HeDeckAgent", self.image, "HeDeck Agent", menu)
            threading.Thread(target=icon.run, daemon=True,
                             name="hedeck-tray").start()
            return icon
        except Exception as exc:
            print("Không tạo được icon ở khay hệ thống:", exc)
            return None

    # -- nối với agent ----------------------------------------------------

    def attach(self, agent, ip, port):
        """Agent gọi từ luồng của nó khi đã sẵn sàng."""
        self.agent, self.ip, self.port = agent, ip, port

    def write_log(self, text):
        self.queue.put(("log", text))

    def _on_agent(self, fn, *args):
        agent = self.agent
        if agent and agent.loop:
            agent.loop.call_soon_threadsafe(fn, *args)

    # -- thao tác ---------------------------------------------------------

    def show(self):
        self.root.deiconify()
        self.root.lift()
        self.root.attributes("-topmost", True)
        self.root.after(200, lambda: self.root.attributes("-topmost", False))
        self.root.focus_force()

    def hide(self):
        if not self.icon:
            self.root.iconify()
            return
        self.root.withdraw()
        if not self._told_tray:
            self._told_tray = True
            self._notify("HeDeck Agent vẫn đang chạy ngầm. Chuột phải icon "
                         "HeDeck ở khay hệ thống → Thoát để tắt hẳn.")

    def _notify(self, text):
        try:
            if self.icon:
                self.icon.notify(text, "HeDeck Agent")
        except Exception:
            pass

    def new_code(self):
        if self.agent:
            self._on_agent(self.agent.new_pair_code)

    def unban(self):
        if self.agent:
            self._on_agent(self.agent.guard.unban_all)

    def forget(self):
        if not self.agent:
            return
        if messagebox.askyesno(
                "Xoá điện thoại đã ghép",
                "Mọi điện thoại đã ghép sẽ phải ghép cặp lại. Tiếp tục?",
                parent=self.root):
            self._on_agent(self.agent.forget_devices)

    def ask_update(self):
        """Hỏi trước rồi mới cài — không bao giờ tự cập nhật."""
        agent = self.agent
        info = agent.update if agent else None
        if not info:
            return
        if not updater.can_self_update(info):
            webbrowser.open(info.get("page") or updater.RELEASES)
            return
        notes = "\n".join(updater.short_notes(info["notes"], 12))
        if messagebox.askyesno(
                f"Cập nhật lên {info['version']}",
                (notes + "\n\n" if notes else "")
                + "Agent sẽ tải bản mới, tự đóng rồi mở lại sau vài giây. "
                "Điện thoại tự kết nối lại. Cập nhật ngay?",
                parent=self.root):
            self.update_button.configure(state="disabled", text="Đang tải…")
            asyncio.run_coroutine_threadsafe(agent.self_update(), agent.loop)

    def _remove_tray(self):
        # Gỡ icon ngay, nếu không Windows để lại một icon "ma" tới khi rê chuột.
        try:
            if self.icon:
                self.icon.visible = False
        except Exception:
            pass

    def quit(self):
        self._remove_tray()
        try:
            sys.stdout.flush()
        except Exception:
            pass
        # Thoát thẳng: các luồng nền (đọc cảm biến, chờ mạng) không cần dọn.
        os._exit(0)

    # -- vòng lặp giao diện -----------------------------------------------

    def _poll(self):
        lines = []
        try:
            while True:
                kind, value = self.queue.get_nowait()
                if kind == "log":
                    lines.append(value)
                elif kind == "show":
                    self.show()
                elif kind == "code":
                    self.new_code()
                    self.show()
                elif kind == "quit":
                    self.quit()
        except queue.Empty:
            pass
        if lines:
            self._append("".join(lines))
        self.root.after(100, self._poll)

    def _append(self, text):
        log = self.log
        at_end = log.yview()[1] > 0.98
        log.configure(state="normal")
        log.insert("end", text)
        count = int(log.index("end-1c").split(".")[0])
        if count > MAX_LINES:
            log.delete("1.0", f"{count - MAX_LINES}.0")
        log.configure(state="disabled")
        if at_end:
            log.see("end")

    def _refresh(self):
        agent = self.agent
        alive = self.thread is None or self.thread.is_alive()
        if not alive:
            self.state_label.configure(
                text="Agent đã dừng vì lỗi — xem log bên dưới, rồi mở lại.",
                fg=BAD)
        elif agent:
            clients = len(agent.clients)
            self.title.configure(text=f"HeDeck Agent · {agent.host_name}")
            self.state_label.configure(
                text=(f"Đang chạy · {clients} điện thoại đang kết nối"
                      if clients else "Đang chạy · chờ điện thoại kết nối"),
                fg=GOOD if clients else MUTED)
            code = agent.pair_code
            self.code.configure(text=f"{code[:3]} {code[3:]}",
                                fg=MUTED if agent.code_expired else ACCENT)
            self.code_status.configure(text=agent.code_status().capitalize())
            st = agent.guard.status()
            version = updater.VERSION or (
                "bản tự đóng gói" if updater.FROZEN else "chạy từ mã nguồn")
            apps = len(agent.apps) if agent.catalog_ready else "đang quét…"
            for key, value in {
                "Địa chỉ": f"ws://{self.ip}:{self.port}",
                "Ứng dụng": apps,
                "Điện thoại": f"{len(agent.state['devices'])} đã ghép cặp"
                              f" · {st['banned']} IP bị chặn",
                "Bật từ xa": power.describe(agent.wol),
                "Phiên bản": version,
            }.items():
                self.info[key].configure(text=value)
            self._refresh_update(agent.update)
            if self.icon:
                tip = f"HeDeck Agent · {self.ip} · {clients} điện thoại"
                if self.icon.title != tip:
                    self.icon.title = tip[:127]
        self.root.after(1000, self._refresh)

    def _refresh_update(self, info):
        if not info:
            self.update_bar.pack_forget()
            return
        if info is not self._seen_update:
            self._seen_update = info
            self._notify(f"Có bản mới {info['version']} — mở HeDeck Agent "
                         "để xem và cập nhật.")
        if updater.can_self_update(info):
            text = f"Có bản mới {info['version']} trên GitHub."
            button = "Xem và cập nhật"
        elif updater.FROZEN:
            text = f"Có bản mới {info['version']} trên GitHub."
            button = "Mở trang tải"
        else:
            text = (f"Có bản mới {info['version']}: chạy git pull rồi mở lại "
                    "run_agent.bat.")
            button = "Xem thay đổi"
        self.update_text.configure(text=text)
        if self.update_button["text"] != "Đang tải…":
            self.update_button.configure(text=button)
        if not self.update_bar.winfo_ismapped():
            self.update_bar.pack(fill="x", padx=14, pady=(0, 10),
                                 before=self.tools)

    def run(self, start_agent):
        self.thread = start_agent(self.attach)
        self.root.after(100, self._poll)
        self.root.after(300, self._refresh)
        self.root.mainloop()


def run(start_agent, start_hidden=False):
    AgentWindow(start_hidden).run(start_agent)
