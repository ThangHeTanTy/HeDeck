"""Chạy riêng phần quét danh mục để xem nó tắc ở đâu.

Dùng khi agent kẹt mãi ở "đang quét…". Script này không mở cổng mạng, không
dính gì tới WebSocket — chỉ làm đúng việc quét và in ra từng bước.

    .venv\\Scripts\\python.exe kiem_tra_quet.py
"""

import sys
import time
import traceback

if sys.platform != "win32":
    print("Script này chỉ chạy trên Windows.")
    sys.exit(1)


def step(name, fn):
    print(f"\n[{name}]")
    t0 = time.time()
    try:
        result = fn()
        print(f"  OK ({time.time() - t0:.2f}s)")
        return result
    except Exception:
        print(f"  HỎNG ({time.time() - t0:.2f}s)")
        traceback.print_exc()
        return None


def main():
    print("=" * 60)
    print("Kiểm tra phần quét danh mục HeDeck")
    print("=" * 60)

    def check_imports():
        import pythoncom, win32com.client, win32gui, psutil  # noqa: F401
        from PIL import Image  # noqa: F401
        return True

    if not step("1. Nạp thư viện", check_imports):
        print("\nThiếu thư viện. Chạy: pip install -r requirements.txt")
        return

    import pythoncom
    step("2. Khởi tạo COM", lambda: pythoncom.CoInitialize())

    import catalog

    def check_folders():
        for root in catalog.START_MENUS:
            exists = root.exists()
            print(f"  {'có' if exists else 'KHÔNG CÓ'}: {root}")
        return True

    step("3. Kiểm tra thư mục Start Menu", check_folders)

    def check_shell():
        shell = catalog._make_shell()
        if shell is None:
            raise RuntimeError("Không tạo được WScript.Shell")
        return shell

    shell = step("4. Tạo WScript.Shell", check_shell)
    if shell is None:
        print("\nCOM hỏng. Thử chạy agent bằng quyền Administrator.")
        return

    def check_one_lnk():
        import os
        from pathlib import Path
        for root in catalog.START_MENUS:
            if not root.exists():
                continue
            for dirpath, _, files in os.walk(root):
                for f in files:
                    if f.lower().endswith(".lnk"):
                        lnk = Path(dirpath) / f
                        t0 = time.time()
                        target, _, _ = catalog._resolve_lnk(shell, lnk)
                        print(f"  {f} -> {target or '(rỗng)'} "
                              f"({(time.time() - t0) * 1000:.0f}ms)")
                        return True
        print("  Không tìm thấy shortcut nào")
        return True

    step("5. Đọc thử một shortcut", check_one_lnk)

    apps = step("6. Quét toàn bộ (chưa lấy icon)",
                lambda: catalog.scan_start_menu(with_icons=False))

    if apps:
        print(f"\n  Tổng: {len(apps)} ứng dụng. Ví dụ 5 app đầu:")
        for a in apps[:5]:
            print(f"    - {a['name']}  ({a['exe']})")

        def check_icon():
            import win_control
            t0 = time.time()
            result = win_control.extract_icon_png(apps[0]["target"])
            if result:
                data, native = result
                print(f"  {apps[0]['name']}: icon gốc {native}px, "
                      f"{len(data) / 1024:.1f} KB "
                      f"({(time.time() - t0) * 1000:.0f}ms)")
            else:
                print(f"  {apps[0]['name']}: không lấy được icon")
            return True

        step("7. Lấy thử một icon", check_icon)

        def icon_report():
            import icon_source
            rows = []
            for a in apps[:25]:
                target = a.get("target") or a.get("path")
                sizes = icon_source.sizes_available(target)
                side = 0
                origin = "-"
                best = icon_source.best_source(target)
                if best:
                    side, origin = best[1], best[2]
                rows.append((a["name"][:26], side, origin,
                             ",".join(map(str, sizes[:4])) or "-"))

            print(f"\n  {'Ứng dụng':<28}{'nét nhất':>9}  {'nguồn':<6}"
                  f"{'các cỡ có trong exe'}")
            print("  " + "-" * 72)
            for name, side, origin, sizes in rows:
                mark = " " if side >= 128 else "!"
                print(f"{mark} {name:<28}{side:>7}px  {origin:<6}{sizes}")
            low = sum(1 for _, s, _, _ in rows if s < 128)
            print(f"\n  {low}/{len(rows)} app có icon dưới 128px "
                  f"(dấu ! ở đầu dòng)")
            return True

        step("8. Độ phân giải icon của từng app", icon_report)

    print("\n" + "=" * 60)
    print("Xong. Chép toàn bộ kết quả này gửi đi nếu vẫn còn lỗi.")
    print("=" * 60)


if __name__ == "__main__":
    main()
