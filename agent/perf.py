"""Đo hiệu năng khi chơi game: FPS, nhiệt độ, mức tải CPU/GPU, RAM, mạng.

Ba nguồn, nguồn nào thiếu thì phần đó để trống và báo lý do, phần còn lại
vẫn chạy:

1. Có sẵn (psutil): mức tải CPU từng nhân, RAM, tốc độ mạng.
2. GPU NVIDIA qua NVML (gói nvidia-ml-py), thiếu thì gọi nvidia-smi — cả hai
   đi kèm driver NVIDIA, không cần cài thêm phần mềm.
3. Cần phần mềm ngoài, vì Windows không có API chung cho hai thứ này:
   - Nhiệt độ, xung nhịp, công suất CPU: LibreHardwareMonitor (mã nguồn mở)
     bật "Remote Web Server". Agent đọc http://127.0.0.1:8085/data.json.
   - FPS: RivaTuner Statistics Server (RTSS, đi kèm MSI Afterburner — bộ
     các cửa hàng hay dùng khi test máy). Agent đọc bộ nhớ chia sẻ
     "RTSSSharedMemoryV2" theo đúng bố cục trong RTSSSharedMemory.h.

Mọi hàm đồng bộ, agent gọi qua run_in_executor mỗi giây một lần, và chỉ
khi có điện thoại đang mở tab Hiệu năng.
"""

import ctypes
import json
import shutil
import struct
import subprocess
import time
import urllib.request

import psutil

LHM_URL = "http://127.0.0.1:8085/data.json"
_NO_WINDOW = 0x08000000


# --------------------------------------------------------------------------
# FPS từ RivaTuner Statistics Server
# --------------------------------------------------------------------------

_RTSS_NAME = "RTSSSharedMemoryV2"
_RTSS_SIG = 0x52545353  # 'RTSS'
_FILE_MAP_READ = 0x0004

# Vị trí các trường trong RTSS_SHARED_MEMORY_APP_ENTRY (RTSSSharedMemory.h).
# Mọi trường là DWORD hoặc mảng char, không có khoảng đệm.
_APP_PID = 0
_APP_NAME = 4            # char szName[260]
_APP_TIME0 = 268
_APP_TIME1 = 272
_APP_FRAMES = 276
_APP_FRAMETIME = 280     # micro giây
# Mảng 1024 frametime gần nhất (để tính 1% low) và hai trường theo sau nó.
# Lấy bằng offsetof() khi biên dịch chính RTSSSharedMemory.h, không đếm tay:
# giữa chúng có hơn 30 trường xen kẽ hai mảng MAX_PATH, đếm tay rất dễ lệch.
_FT_BUF = 924            # DWORD dwStatFrameTimeBuf[1024]
_FT_POS = 5020           # DWORD dwStatFrameTimeBufPos
_FT_RATE = 5024          # DWORD dwStatFrameTimeBufFramerate

_kernel32 = None


def _k32():
    global _kernel32
    if _kernel32 is None:
        k = ctypes.windll.kernel32
        k.OpenFileMappingW.restype = ctypes.c_void_p
        k.OpenFileMappingW.argtypes = [ctypes.c_uint32, ctypes.c_int,
                                       ctypes.c_wchar_p]
        k.MapViewOfFile.restype = ctypes.c_void_p
        k.MapViewOfFile.argtypes = [ctypes.c_void_p, ctypes.c_uint32,
                                    ctypes.c_uint32, ctypes.c_uint32,
                                    ctypes.c_size_t]
        k.UnmapViewOfFile.argtypes = [ctypes.c_void_p]
        k.CloseHandle.argtypes = [ctypes.c_void_p]
        _kernel32 = k
    return _kernel32


def _low_1pct(frame_times_us):
    """1% low: FPS trung bình của 1% khung hình chậm nhất — con số cho biết
    game có giật hay không, thứ FPS trung bình che mất."""
    times = sorted((t for t in frame_times_us if 0 < t < 2_000_000),
                   reverse=True)
    if len(times) < 100:
        return None
    worst = times[:max(1, len(times) // 100)]
    avg = sum(worst) / len(worst)
    return round(1_000_000 / avg, 1) if avg else None


def read_rtss(prefer_pid=0):
    """FPS của game đang chạy, hoặc None nếu RTSS chưa chạy.

    Mở bộ nhớ chia sẻ ở chế độ CHỈ ĐỌC, và tuyệt đối không tạo mới: tạo mới
    một vùng cùng tên khi RTSS chưa chạy sẽ làm RTSS mở nhầm vùng của mình
    lúc nó khởi động sau.
    """
    k = _k32()
    handle = k.OpenFileMappingW(_FILE_MAP_READ, 0, _RTSS_NAME)
    if not handle:
        return None
    try:
        base = k.MapViewOfFile(handle, _FILE_MAP_READ, 0, 0, 0)
        if not base:
            return None
        try:
            head = ctypes.string_at(base, 20)
            sig, ver, entry_size, arr_off, arr_size = struct.unpack("<5I", head)
            if sig != _RTSS_SIG or ver < 0x00020000 or not entry_size:
                return None
            best = None
            for i in range(min(arr_size, 256)):
                at = base + arr_off + i * entry_size
                pid, = struct.unpack("<I", ctypes.string_at(at, 4))
                if not pid:
                    continue
                t0, t1, frames, ft = struct.unpack(
                    "<4I", ctypes.string_at(at + _APP_TIME0, 16))
                if t1 <= t0 or not frames:
                    continue
                cand = (pid == prefer_pid, t1, i, pid, t0, frames, ft)
                if best is None or cand[:2] > best[:2]:
                    best = cand
            if best is None:
                return None
            _, t1, i, pid, t0, frames, ft = best
            # Mục đã lâu không cập nhật (game đã tắt) thì bỏ.
            if (k.GetTickCount() - t1) & 0xFFFFFFFF > 3000:
                return None
            at = base + arr_off + i * entry_size
            raw = ctypes.string_at(at + _APP_NAME, 260)
            raw = raw.split(b"\0", 1)[0]
            try:
                name = raw.decode("mbcs", errors="replace")  # ANSI của Windows
            except LookupError:
                name = raw.decode("utf-8", errors="replace")
            fps = 1000.0 * frames / (t1 - t0)
            low = None
            if entry_size >= _FT_RATE + 4:
                buf = struct.unpack("<1024I", ctypes.string_at(at + _FT_BUF,
                                                               4096))
                low = _low_1pct(buf)
            return {
                "pid": pid,
                "app": name.replace("\\", "/").rsplit("/", 1)[-1],
                "fps": round(fps, 1),
                "frametime": round(ft / 1000.0, 2) if ft else
                round(1000.0 / fps, 2),
                "low1": low,
            }
        finally:
            k.UnmapViewOfFile(base)
    finally:
        k.CloseHandle(handle)


# --------------------------------------------------------------------------
# LibreHardwareMonitor
# --------------------------------------------------------------------------

def _sensors(node, out):
    if "SensorId" in node:
        value = node.get("RawValue")
        if not isinstance(value, (int, float)):
            # Bản cũ chỉ có chuỗi đã định dạng, ví dụ "45,0 °C".
            text = str(node.get("Value", "")).split(" ")[0].replace(",", ".")
            try:
                value = float(text)
            except ValueError:
                value = None
        if value is not None:
            out.append((node["SensorId"].lower(), node.get("Type", ""),
                        node.get("Text", ""), float(value)))
    for child in node.get("Children", []) or []:
        _sensors(child, out)
    return out


def read_lhm():
    try:
        with urllib.request.urlopen(LHM_URL, timeout=0.6) as r:
            data = json.loads(r.read().decode("utf-8", errors="replace"))
    except Exception:
        return None
    return _sensors(data, [])


def _cpu_from_lhm(sensors):
    cpu = [s for s in sensors if s[0].startswith(("/intelcpu", "/amdcpu"))]
    if not cpu:
        return {}

    def pick(kind, names):
        group = [s for s in cpu if s[1] == kind]
        for name in names:
            for s in group:
                if s[2].lower() == name:
                    return s[3]
        return None

    temps = [s[3] for s in cpu if s[1] == "Temperature" and s[3] > 0]
    temp = pick("Temperature", ("cpu package", "core (tctl/tdie)",
                                "core max", "core average"))
    clocks = [s[3] for s in cpu if s[1] == "Clock"
              and s[2].lower().startswith("cpu core #")]
    return {
        "temp": temp if temp is not None else (max(temps) if temps else None),
        "power": pick("Power", ("cpu package", "package")),
        "clock": max(clocks) if clocks else None,
    }


def _gpu_from_lhm(sensors):
    gpu = [s for s in sensors if s[0].startswith(("/gpu-nvidia", "/gpu-amd",
                                                  "/gpu-intel"))]

    def pick(kind, name):
        for s in gpu:
            if s[1] == kind and s[2].lower() == name:
                return s[3]
        return None

    if not gpu:
        return None
    return {
        "temp": pick("Temperature", "gpu core"),
        "load": pick("Load", "gpu core"),
        "clock": pick("Clock", "gpu core"),
        "power": pick("Power", "gpu package") or pick("Power", "gpu power"),
        "mem_used": (pick("SmallData", "gpu memory used") or 0) / 1024 or None,
        "mem_total": (pick("SmallData", "gpu memory total") or 0) / 1024 or None,
        "fan": pick("Control", "gpu fan"),
    }


# --------------------------------------------------------------------------
# GPU NVIDIA
# --------------------------------------------------------------------------

class _Nvidia:
    def __init__(self):
        self.nvml = None
        self.handle = None
        self.name = ""
        self.smi = shutil.which("nvidia-smi")
        try:
            import pynvml
            pynvml.nvmlInit()
            self.handle = pynvml.nvmlDeviceGetHandleByIndex(0)
            name = pynvml.nvmlDeviceGetName(self.handle)
            self.name = name.decode() if isinstance(name, bytes) else name
            self.nvml = pynvml
        except Exception:
            self.nvml = None

    def read(self):
        if self.nvml:
            try:
                return self._read_nvml()
            except Exception:
                pass
        if self.smi:
            try:
                return self._read_smi()
            except Exception:
                pass
        return None

    def _read_nvml(self):
        n, h = self.nvml, self.handle

        def safe(fn, *a):
            try:
                return fn(h, *a)
            except Exception:
                return None

        mem = safe(n.nvmlDeviceGetMemoryInfo)
        util = safe(n.nvmlDeviceGetUtilizationRates)
        power = safe(n.nvmlDeviceGetPowerUsage)
        return {
            "name": self.name,
            "temp": safe(n.nvmlDeviceGetTemperature, n.NVML_TEMPERATURE_GPU),
            "load": util.gpu if util else None,
            "clock": safe(n.nvmlDeviceGetClockInfo, n.NVML_CLOCK_GRAPHICS),
            "power": power / 1000.0 if power is not None else None,
            "mem_used": mem.used / 2**30 if mem else None,
            "mem_total": mem.total / 2**30 if mem else None,
            "fan": safe(n.nvmlDeviceGetFanSpeed),
        }

    def _read_smi(self):
        out = subprocess.run(
            [self.smi, "--query-gpu=name,temperature.gpu,utilization.gpu,"
             "clocks.gr,power.draw,memory.used,memory.total,fan.speed",
             "--format=csv,noheader,nounits"],
            capture_output=True, timeout=3, creationflags=_NO_WINDOW,
        ).stdout.decode("utf-8", errors="replace").splitlines()
        if not out:
            return None
        cols = [c.strip() for c in out[0].split(",")]

        def num(i, scale=1.0):
            try:
                return float(cols[i]) * scale
            except (ValueError, IndexError):
                return None

        return {
            "name": cols[0], "temp": num(1), "load": num(2), "clock": num(3),
            "power": num(4), "mem_used": num(5, 1 / 1024),
            "mem_total": num(6, 1 / 1024), "fan": num(7),
        }


# --------------------------------------------------------------------------
# Gom lại
# --------------------------------------------------------------------------

def _r(value, digits=1):
    return None if value is None else round(float(value), digits)


class PerfMonitor:
    def __init__(self):
        self._gpu = None
        self._net = None
        self._net_at = 0.0
        psutil.cpu_percent(percpu=True)  # lần đầu luôn trả 0, mồi trước

    def sample(self, foreground_pid=0):
        if self._gpu is None:
            self._gpu = _Nvidia()

        per_core = psutil.cpu_percent(percpu=True)
        vm = psutil.virtual_memory()
        sensors = read_lhm()
        lhm_cpu = _cpu_from_lhm(sensors) if sensors else {}

        gpu = self._gpu.read()
        if gpu is None and sensors:
            gpu = _gpu_from_lhm(sensors)

        now = time.time()
        net = psutil.net_io_counters()
        down = up = None
        if self._net is not None and now > self._net_at:
            dt = now - self._net_at
            down = (net.bytes_recv - self._net.bytes_recv) / dt
            up = (net.bytes_sent - self._net.bytes_sent) / dt
        self._net, self._net_at = net, now

        try:
            fps = read_rtss(foreground_pid)
        except Exception:
            fps = None

        return {
            "t": "perf",
            "cpu": {
                "load": _r(sum(per_core) / len(per_core)) if per_core else None,
                "cores": [round(c) for c in per_core],
                "temp": _r(lhm_cpu.get("temp")),
                "clock": _r(lhm_cpu.get("clock"), 0),
                "power": _r(lhm_cpu.get("power")),
            },
            "gpu": None if not gpu else {
                "name": gpu.get("name") or "",
                "temp": _r(gpu.get("temp")),
                "load": _r(gpu.get("load")),
                "clock": _r(gpu.get("clock"), 0),
                "power": _r(gpu.get("power")),
                "mem_used": _r(gpu.get("mem_used"), 2),
                "mem_total": _r(gpu.get("mem_total"), 2),
                "fan": _r(gpu.get("fan")),
            },
            "ram": {
                "used": _r(vm.used / 2**30, 2),
                "total": _r(vm.total / 2**30, 2),
                "percent": _r(vm.percent),
            },
            "net": {"down": _r(down, 0), "up": _r(up, 0)},
            "fps": fps,
            "sources": {"lhm": sensors is not None, "rtss": fps is not None,
                        "gpu": gpu is not None},
        }
