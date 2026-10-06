"""Nguồn máy tính: tắt, khởi động lại, ngủ, khoá — và thông tin để bật lại
máy từ xa bằng Wake-on-LAN.

Lúc máy đã tắt thì agent cũng tắt theo, nên agent không thể tự bật máy. Việc
của agent chỉ là nói cho điện thoại biết địa chỉ MAC của card mạng có dây và
địa chỉ broadcast của mạng LAN, khi máy còn đang chạy. Điện thoại lưu lại, rồi
lúc cần thì tự gửi "gói tin thần kỳ" (magic packet) tới card mạng — card mạng
vẫn được cấp điện chờ khi máy tắt, thấy đúng MAC của mình là đánh thức máy.

Toàn bộ hàm ở đây là đồng bộ. agent.py gọi qua run_in_executor.
"""

import ctypes
import ipaddress
import json
import subprocess
import winreg

ACTIONS = ("lock", "sleep", "restart", "shutdown")

_NO_WINDOW = 0x08000000  # CREATE_NO_WINDOW: đừng nháy cửa sổ PowerShell

# Một lượt PowerShell lấy hết thông tin card mạng vật lý. Get-NetAdapter là
# nguồn duy nhất biết chắc card nào là dây, card nào là Wi-Fi, và Windows có
# cho phép card đó đánh thức máy hay không.
_ADAPTERS_PS = r"""
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$list = @()
foreach ($a in Get-NetAdapter -Physical -ErrorAction SilentlyContinue) {
    $pm = Get-NetAdapterPowerManagement -Name $a.Name -ErrorAction SilentlyContinue
    $ip = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 `
          -ErrorAction SilentlyContinue | Select-Object -First 1
    $s5 = Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue |
          Where-Object { $_.RegistryKeyword -eq 'S5WakeOnLan' } |
          Select-Object -First 1
    $list += [pscustomobject]@{
        name   = $a.Name
        desc   = $a.InterfaceDescription
        mac    = $a.MacAddress
        status = "$($a.Status)"
        media  = "$($a.PhysicalMediaType)"
        magic  = if ($pm) { "$($pm.WakeOnMagicPacket)" } else { "" }
        s5     = if ($s5) { "$($s5.RegistryValue)" } else { "" }
        ip     = if ($ip) { "$($ip.IPAddress)" } else { "" }
        prefix = if ($ip) { [int]$ip.PrefixLength } else { 0 }
    }
}
ConvertTo-Json -InputObject @($list) -Compress -Depth 3
"""


def _normalize_mac(raw):
    hexes = "".join(c for c in str(raw) if c in "0123456789abcdefABCDEF")
    if len(hexes) != 12 or hexes in ("0" * 12, "f" * 12, "F" * 12):
        return ""
    return ":".join(hexes[i:i + 2] for i in range(0, 12, 2)).upper()


def _adapters():
    out = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive",
         "-ExecutionPolicy", "Bypass", "-Command", _ADAPTERS_PS],
        capture_output=True, timeout=25, creationflags=_NO_WINDOW,
    )
    text = out.stdout.decode("utf-8", errors="replace").strip()
    if not text:
        return []
    data = json.loads(text)
    return data if isinstance(data, list) else [data]


def _reg_dword(path, name):
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path) as key:
            value, _ = winreg.QueryValueEx(key, name)
            return int(value)
    except OSError:
        return None


def fast_startup_enabled():
    """Fast Startup thật ra là ngủ đông một nửa. Bật nó thì lúc tắt máy từ
    Start Menu, nhiều card mạng — trong đó có Realtek — không được "giao
    nhiệm vụ" chờ magic packet, và máy không dậy được nữa."""
    hiberboot = _reg_dword(
        r"SYSTEM\CurrentControlSet\Control\Session Manager\Power",
        "HiberbootEnabled")
    hibernate = _reg_dword(r"SYSTEM\CurrentControlSet\Control\Power",
                           "HibernateEnabled")
    if hiberboot is None:
        return None
    # Tắt ngủ đông (powercfg /h off) thì Fast Startup cũng mất theo.
    return hiberboot == 1 and hibernate != 0


def wol_info(current_ip):
    """Gom những gì điện thoại cần để bật máy, kèm cảnh báo cấu hình.

    Không bao giờ ném lỗi: thiếu thông tin thì trả về danh sách rỗng và một
    dòng cảnh báo, agent vẫn chạy bình thường.
    """
    info = {"macs": [], "broadcast": "", "wired": False,
            "adapters": [], "warnings": []}
    try:
        adapters = _adapters()
    except Exception as exc:
        info["warnings"].append(f"Không đọc được card mạng: {exc}")
        return info

    wired, wireless = [], []
    for a in adapters:
        mac = _normalize_mac(a.get("mac", ""))
        if not mac:
            continue
        media = str(a.get("media", ""))
        entry = {
            "name": a.get("name", ""),
            "desc": a.get("desc", ""),
            "mac": mac,
            "up": str(a.get("status", "")).lower() == "up",
            "wired": "802.3" in media,
            "current": a.get("ip") == current_ip,
            "magic": str(a.get("magic", "")),
            "s5": str(a.get("s5", "")),
        }
        if entry["wired"]:
            wired.append(entry)
        elif "802.11" in media:
            wireless.append(entry)
        else:
            continue  # Bluetooth và các loại khác không đánh thức được máy
        if entry["current"] and a.get("prefix"):
            try:
                net = ipaddress.ip_network(f"{current_ip}/{a['prefix']}",
                                           strict=False)
                info["broadcast"] = str(net.broadcast_address)
            except ValueError:
                pass

    # Card dây đang cắm lên đầu: đó gần như chắc chắn là card sẽ nhận gói tin.
    wired.sort(key=lambda e: (not e["current"], not e["up"]))
    info["adapters"] = wired + wireless
    info["macs"] = [e["mac"] for e in wired]
    info["wired"] = any(e["up"] for e in wired)
    warn = info["warnings"]

    if not wired:
        warn.append("Không thấy card mạng có dây. Wake-on-LAN khi máy tắt "
                    "hẳn chỉ chạy qua dây LAN.")
    elif not info["wired"]:
        warn.append("Card mạng có dây chưa cắm cáp. Máy đang tắt chỉ nghe "
                    "được gói tin bật máy qua dây LAN, không qua Wi-Fi.")
    for e in wired:
        if e["magic"].lower() == "disabled":
            warn.append(f"Windows chưa cho {e['name']} đánh thức máy — chạy "
                        "CAI_BAT_MAY_TU_XA.bat để sửa.")
        if e["s5"] == "0":
            warn.append(f"{e['name']}: 'Shutdown Wake-On-Lan' đang tắt — "
                        "chạy CAI_BAT_MAY_TU_XA.bat để sửa.")
    if fast_startup_enabled():
        warn.append("Fast Startup đang bật: tắt máy bằng Start Menu có thể "
                    "không bật lại được. Tắt máy từ HeDeck thì không sao.")
    return info


def public_view(info):
    """Phần gửi cho điện thoại: chỉ những gì cần để gửi gói tin bật máy."""
    if not info:
        return {"macs": [], "broadcast": "", "wired": False, "warnings": []}
    return {
        "macs": info.get("macs", []),
        "broadcast": info.get("broadcast", ""),
        "wired": info.get("wired", False),
        "warnings": info.get("warnings", []),
    }


def describe(info):
    """Một dòng cho bảng thông tin của agent."""
    if not info or not info.get("macs"):
        return "chưa dùng được (không có card mạng dây)"
    state = "sẵn sàng" if info.get("wired") and not info.get("warnings") \
        else "cần xem cảnh báo"
    return f"{info['macs'][0]} · {state}"


# --------------------------------------------------------------------------
# Hành động nguồn
# --------------------------------------------------------------------------

def apply(action, force=False):
    """Thực hiện ngay. agent.py chịu trách nhiệm trả lời điện thoại trước,
    vì sau lệnh tắt máy thì không còn ai để trả lời nữa."""
    if action == "lock":
        ctypes.windll.user32.LockWorkStation()
        return
    if action == "sleep":
        # Đi qua .NET vì nó tự bật đặc quyền SeShutdownPrivilege. Gọi
        # SetSuspendState trần qua rundll32 thì máy có bật ngủ đông sẽ ngủ
        # đông thay vì ngủ, do rundll32 truyền tham số sai kiểu.
        subprocess.Popen(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command",
             "Add-Type -AssemblyName System.Windows.Forms; "
             "[System.Windows.Forms.Application]::SetSuspendState("
             "[System.Windows.Forms.PowerState]::Suspend, $false, $false)"],
            creationflags=_NO_WINDOW,
        )
        return
    if action in ("restart", "shutdown"):
        # `shutdown /s` không kèm cờ hybrid là tắt hẳn (S5), không đi qua Fast
        # Startup — đúng trạng thái mà Wake-on-LAN chạy ổn định nhất.
        cmd = ["shutdown", "/r" if action == "restart" else "/s", "/t", "0"]
        if force:
            cmd.append("/f")
        subprocess.Popen(cmd, creationflags=_NO_WINDOW)
        return
    raise ValueError(f"Hành động nguồn lạ: {action}")
