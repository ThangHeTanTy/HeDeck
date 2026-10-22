/// Một lần đo hiệu năng do agent gửi mỗi giây khi tab Hiệu năng đang mở.
///
/// Giá trị nào null là nguồn đo đó chưa có (chưa chạy LibreHardwareMonitor,
/// RTSS, hoặc không đọc được GPU) — giao diện hiện gạch ngang và lời nhắc.
class PerfSample {
  final double? cpuLoad;
  final List<int> cpuCores;
  final double? cpuTemp;

  /// MHz.
  final double? cpuClock;

  /// W.
  final double? cpuPower;

  final String gpuName;
  final double? gpuTemp;
  final double? gpuLoad;
  final double? gpuClock;
  final double? gpuPower;

  /// GB.
  final double? vramUsed;
  final double? vramTotal;
  final double? gpuFan;

  /// GB.
  final double? ramUsed;
  final double? ramTotal;
  final double? ramPercent;

  /// Byte mỗi giây.
  final double? netDown;
  final double? netUp;

  final String fpsApp;
  final double? fps;
  final double? frameTime;
  final double? low1;

  final bool hasLhm;
  final bool hasRtss;
  final bool hasGpu;

  const PerfSample({
    this.cpuLoad,
    this.cpuCores = const [],
    this.cpuTemp,
    this.cpuClock,
    this.cpuPower,
    this.gpuName = '',
    this.gpuTemp,
    this.gpuLoad,
    this.gpuClock,
    this.gpuPower,
    this.vramUsed,
    this.vramTotal,
    this.gpuFan,
    this.ramUsed,
    this.ramTotal,
    this.ramPercent,
    this.netDown,
    this.netUp,
    this.fpsApp = '',
    this.fps,
    this.frameTime,
    this.low1,
    this.hasLhm = false,
    this.hasRtss = false,
    this.hasGpu = false,
  });

  static double? _d(dynamic v) => (v as num?)?.toDouble();

  factory PerfSample.fromJson(Map<String, dynamic> j) {
    final cpu = (j['cpu'] as Map?)?.cast<String, dynamic>() ?? const {};
    final gpu = (j['gpu'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ram = (j['ram'] as Map?)?.cast<String, dynamic>() ?? const {};
    final net = (j['net'] as Map?)?.cast<String, dynamic>() ?? const {};
    final fps = (j['fps'] as Map?)?.cast<String, dynamic>() ?? const {};
    final src = (j['sources'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PerfSample(
      cpuLoad: _d(cpu['load']),
      cpuCores: (cpu['cores'] as List? ?? const [])
          .map((e) => (e as num).round())
          .toList(),
      cpuTemp: _d(cpu['temp']),
      cpuClock: _d(cpu['clock']),
      cpuPower: _d(cpu['power']),
      gpuName: gpu['name'] as String? ?? '',
      gpuTemp: _d(gpu['temp']),
      gpuLoad: _d(gpu['load']),
      gpuClock: _d(gpu['clock']),
      gpuPower: _d(gpu['power']),
      vramUsed: _d(gpu['mem_used']),
      vramTotal: _d(gpu['mem_total']),
      gpuFan: _d(gpu['fan']),
      ramUsed: _d(ram['used']),
      ramTotal: _d(ram['total']),
      ramPercent: _d(ram['percent']),
      netDown: _d(net['down']),
      netUp: _d(net['up']),
      fpsApp: fps['app'] as String? ?? '',
      fps: _d(fps['fps']),
      frameTime: _d(fps['frametime']),
      low1: _d(fps['low1']),
      hasLhm: src['lhm'] as bool? ?? false,
      hasRtss: src['rtss'] as bool? ?? false,
      hasGpu: src['gpu'] as bool? ?? false,
    );
  }
}
