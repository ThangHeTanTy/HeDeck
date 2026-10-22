"""Kiểm tra agent trước khi chạy thật.

Bắt những lỗi mà mắt người dễ bỏ sót: một lời gọi bị mất sau khi sửa code, một
lệnh khai báo nhưng chưa nối vào đâu, một nhánh không bao giờ chạy tới.

    python kiem_tra_agent.py

Chạy được trên mọi hệ điều hành — chỉ đọc và phân tích mã nguồn, không cần
Windows và không mở cổng mạng.
"""

import ast
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
FAILED = []


def check(name, condition, detail=""):
    mark = "OK  " if condition else "HỎNG"
    print(f"  [{mark}] {name}")
    if not condition:
        if detail:
            print(f"         {detail}")
        FAILED.append(name)


def parse(filename):
    return ast.parse((HERE / filename).read_text(encoding="utf-8"))


def called_names(tree):
    """Mọi tên hàm được gọi trực tiếp: foo() hoặc obj.foo()."""
    names = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            f = node.func
            if isinstance(f, ast.Attribute):
                names.add(f.attr)
            elif isinstance(f, ast.Name):
                names.add(f.id)
    return names


def referenced_names(tree):
    """Mọi tên được nhắc tới, kể cả khi chỉ truyền đi chứ không gọi.

    Cần thiết vì nhiều thứ hợp lệ không xuất hiện dưới dạng lời gọi:
    thuộc tính `self.code_expired`, hàm truyền cho executor
    `run_blocking(self.snapshot)`, hay callback `add_done_callback(self._x)`.
    """
    names = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Attribute):
            names.add(node.attr)
        elif isinstance(node, ast.Name):
            names.add(node.id)
    return names


def function_body(tree, name):
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if node.name == name:
                return node
    return None


def main():
    print("=" * 62)
    print("Kiểm tra agent HeDeck")
    print("=" * 62)

    agent = parse("agent.py")
    catalog = parse("catalog.py")

    # --- Mọi vòng lặp nền phải thật sự được khởi động trong main() ---------
    print("\n[Tác vụ nền được khởi động trong main]")
    main_fn = function_body(agent, "main")
    started = called_names(main_fn) if main_fn else set()

    for task in ("status_loop", "watch_console", "load_catalog", "perf_loop"):
        check(
            f"main() có gọi {task}()",
            task in started,
            f"Thiếu lời gọi {task} — tác vụ này sẽ không bao giờ chạy.",
        )

    # --- Mọi phương thức định nghĩa phải được dùng ở đâu đó ----------------
    print("\n[Không có phương thức nào bị bỏ quên]")
    used = referenced_names(agent)
    agent_cls = next(
        (n for n in ast.walk(agent)
         if isinstance(n, ast.ClassDef) and n.name == "Agent"), None
    )
    orphans = []
    if agent_cls:
        for node in agent_cls.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if node.name.startswith("__"):
                    continue
                if node.name not in used:
                    orphans.append(node.name)
    check(
        "mọi phương thức của Agent đều được gọi",
        not orphans,
        f"Không ai gọi: {', '.join(orphans)}" if orphans else "",
    )

    # --- Mọi lệnh app gửi lên đều phải có nhánh xử lý ----------------------
    print("\n[Lệnh mà agent hiểu]")
    source = (HERE / "agent.py").read_text(encoding="utf-8")
    for cmd in ("ping", "catalog", "rescan", "launch", "close",
                "media", "macro", "app_volume", "watch_volume", "power",
                "running", "adopt", "scene", "perf_watch"):
        check(f'có xử lý lệnh "{cmd}"', f'kind == "{cmd}"' in source)
    check("có xử lý touchpad và bàn phím ảo",
          '"mouse_move", "mouse_button", "mouse_scroll"' in source
          and '"type_text", "key"' in source)
    check("touchpad gọi thẳng, không qua luồng khác (giữ đúng thứ tự)",
          "return self.remote_input(kind, msg)" in source)
    perf_src = (HERE / "perf.py").read_text(encoding="utf-8")
    check("đọc RTSS chỉ mở vùng nhớ có sẵn, không tạo mới",
          "OpenFileMappingW" in perf_src and "CreateFileMapping" not in perf_src
          and "tagname" not in perf_src,
          "Tạo vùng nhớ cùng tên khi RTSS chưa chạy sẽ làm hỏng RTSS.")
    check("offset mảng frametime của RTSS đúng như header (924)",
          "_FT_BUF = 924" in perf_src)
    check("trạng thái gửi kèm app đang ở trước (tự đổi trang)",
          '"fg": front' in source)
    check('có xử lý lệnh "focus_window" và "close_window"',
          'kind in ("focus_window", "close_window")' in source)
    check("chỉ đụng vào cửa sổ thuộc đúng app",
          "self._owns_window," in source,
          "Thiếu thì điện thoại gửi hwnd bất kỳ là đóng được cửa sổ khác.")

    # --- Danh mục ---------------------------------------------------------
    print("\n[Danh mục ứng dụng]")
    cat_src = (HERE / "catalog.py").read_text(encoding="utf-8")
    check("có hằng số phiên bản danh mục", "CATALOG_VERSION" in cat_src)
    check("quét và lấy icon là hai bước tách rời",
          "def attach_icons" in cat_src and "def scan_start_menu" in cat_src)
    check("quét mặc định không kèm icon",
          "def scan_start_menu(with_icons: bool = False)" in cat_src,
          "Quét kèm icon sẽ chậm và làm app chờ lâu.")
    check("có khởi tạo COM cho luồng nền", "CoInitialize" in cat_src)

    check("khử trùng lặp theo file đích + tham số, không chỉ theo .exe",
          "launchers.shortcut_key(target, args)" in cat_src,
          "Chỉ so .exe thì mọi game Riot bị gộp thành 'Riot Client'.")
    check("quét cả Desktop và game từ launcher",
          "desktops()" in cat_src and "launchers.all_games" in cat_src)
    check("giữ nguyên app_id cũ cho shortcut không tham số",
          "if args:" in cat_src.split("def _app_id", 1)[1][:400])

    # --- Trạng thái -------------------------------------------------------
    print("\n[Đo trạng thái]")
    win_src = (HERE / "win_control.py").read_text(encoding="utf-8")
    check("đếm cửa sổ trong một lượt duyệt",
          "def window_table" in win_src)
    check("không đếm desktop/taskbar là cửa sổ của File Explorer",
          '"progman"' in win_src and '"shell_traywnd"' in win_src)
    check("không bao giờ giết explorer.exe",
          '_NEVER_KILL = {"explorer.exe"}' in win_src)
    check("vòng đo trạng thái dùng window_table",
          "win_control.window_table()" in source,
          "Gọi windows_of cho từng app sẽ tốn gấp hàng chục lần.")

    # --- Nguồn và bật máy từ xa ------------------------------------------
    print("\n[Nguồn và Wake-on-LAN]")
    pw_src = (HERE / "power.py").read_text(encoding="utf-8")
    check("agent lấy thông tin Wake-on-LAN lúc khởi động",
          "power.wol_info" in source)
    check("điện thoại nhận MAC lúc ghép cặp và lúc kết nối lại",
          source.count('"wol": power.public_view(self.wol)') >= 2,
          "Thiếu thì điện thoại không biết MAC để bật máy.")
    check("báo phiên bản agent cho app lúc ghép cặp và kết nối",
          source.count('"v": AGENT_VERSION') >= 2,
          "Thiếu thì app không phát hiện được agent cũ chưa chạy lại.")
    check("lệnh nguồn trả lời trước rồi mới thực hiện",
          "self.power_later(" in source)
    check("tắt máy là tắt hẳn, không qua Fast Startup",
          "/hybrid" not in pw_src)

    # --- Bảo mật ----------------------------------------------------------
    print("\n[Bảo mật]")
    sec_src = (HERE / "security.py").read_text(encoding="utf-8")
    check("chặn IP ngoài mạng nội bộ", "def is_private_ip" in sec_src)
    check("kiểm tra chữ ký", "def verify_signature" in sec_src)
    check("chống gửi lại yêu cầu cũ", "def fresh_nonce" in sec_src)
    check("agent có kiểm tra IP khi mở kết nối",
          "self.guard.check(peer)" in source)

    print("\n" + "=" * 62)
    if FAILED:
        print(f"{len(FAILED)} mục HỎNG:")
        for name in FAILED:
            print(f"  - {name}")
        print("=" * 62)
        return 1
    print("Tất cả đều ổn.")
    print("=" * 62)
    return 0


if __name__ == "__main__":
    sys.exit(main())
