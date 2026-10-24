import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/perf.dart';
import '../services/deck_connection.dart';
import '../theme.dart';

/// Màu trạng thái, cố định, không dùng cho việc khác. Luôn đi kèm icon và
/// chữ ("Mát / Ấm / Nóng") — không bao giờ để màu tự nói một mình.
const _good = Color(0xFF0CA30C);
const _warning = Color(0xFFFAB219);
const _critical = Color(0xFFD03B3B);

/// Tab Hiệu năng: FPS, nhiệt độ, mức tải CPU/GPU, RAM, mạng — kiểu màn hình
/// các cửa hàng dùng khi test cấu hình. Cập nhật mỗi giây, giữ 60 giây gần
/// nhất để vẽ đường xu hướng.
class PerfScreen extends StatefulWidget {
  const PerfScreen({super.key});

  @override
  State<PerfScreen> createState() => _PerfScreenState();
}

class _PerfScreenState extends State<PerfScreen> {
  static const _historyLength = 60;
  final Map<String, List<double?>> _history = {};
  late final DeckConnection _conn;

  @override
  void initState() {
    super.initState();
    _conn = context.read<DeckConnection>();
    _conn.onPerf = _record;
    _conn.perfWatch(true);
  }

  @override
  void dispose() {
    // Rời tab là báo agent thôi đo, trả lại trọn CPU cho game.
    _conn.onPerf = null;
    _conn.perfWatch(false);
    super.dispose();
  }

  void _record(PerfSample s) {
    void push(String key, double? v) {
      final list = _history.putIfAbsent(key, () => []);
      list.add(v);
      if (list.length > _historyLength) list.removeAt(0);
    }

    push('fps', s.fps);
    push('cpuTemp', s.cpuTemp);
    push('cpuLoad', s.cpuLoad);
    push('gpuTemp', s.gpuTemp);
    push('gpuLoad', s.gpuLoad);
  }

  List<double?> _h(String key) => _history[key] ?? const [];

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<DeckConnection>();
    final s = conn.perf;

    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        title: Text(t('Hiệu năng'), style: const TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: !conn.isOnline
            ? _Center(t('Chưa kết nối tới thiết bị'))
            : conn.agentOutdated
                ? _Center(t('Agent trên thiết bị là bản cũ — tắt cửa sổ agent rồi chạy lại run_agent.bat'))
                : s == null
                    ? _Center(t('Đang đo…'), busy: true)
                    : LayoutBuilder(
                        builder: (context, box) =>
                            box.maxWidth >= 720 ? _wide(s) : _narrow(s),
                      ),
      ),
    );
  }

  // ------------------------------------------------------------- bố cục

  Widget _wide(PerfSample s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fpsCard(s),
                    const SizedBox(height: 10),
                    _ramCard(s),
                    const SizedBox(height: 10),
                    _netCard(s),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _cpuCard(s)),
              const SizedBox(width: 10),
              Expanded(child: _gpuCard(s)),
            ],
          ),
          ..._hints(s),
        ],
      ),
    );
  }

  Widget _narrow(PerfSample s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        _fpsCard(s),
        const SizedBox(height: 10),
        _cpuCard(s),
        const SizedBox(height: 10),
        _gpuCard(s),
        const SizedBox(height: 10),
        _ramCard(s),
        const SizedBox(height: 10),
        _netCard(s),
        ..._hints(s),
      ],
    );
  }

  // ----------------------------------------------------------------- thẻ

  Widget _fpsCard(PerfSample s) {
    final history = _h('fps');
    final top = history.whereType<double>().fold<double>(60, math.max);
    return _Card(
      title: 'FPS',
      trailing: s.fpsApp.isEmpty
          ? null
          : Flexible(
              child: Text(s.fpsApp.replaceAll('.exe', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: DeckColors.muted, fontSize: 12)),
            ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Con số chính duy nhất của màn hình.
            Text(
              s.fps == null ? '—' : s.fps!.round().toString(),
              style: const TextStyle(
                  color: DeckColors.text,
                  fontSize: 60,
                  fontWeight: FontWeight.w700,
                  height: 1),
            ),
            const SizedBox(width: 8),
            const Text('FPS',
                style: TextStyle(color: DeckColors.muted, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _Metric('1% low', s.low1 == null ? '—' : '${s.low1!.round()}'),
          _Metric(
              'Frametime',
              s.frameTime == null
                  ? '—'
                  : '${s.frameTime!.toStringAsFixed(1)} ms'),
        ]),
        const SizedBox(height: 10),
        _Spark(values: history, min: 0, max: top * 1.15, label: t('FPS 60 giây')),
      ],
    );
  }

  Widget _cpuCard(PerfSample s) {
    return _Card(
      title: 'CPU',
      trailing: _TempBadge(s.cpuTemp, warnAt: 70, critAt: 85),
      children: [
        _bigTemp(s.cpuTemp),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _Metric(t('Tải'), _pct(s.cpuLoad)),
          _Metric(
              'Xung',
              s.cpuClock == null
                  ? '—'
                  : '${(s.cpuClock! / 1000).toStringAsFixed(2)} GHz'),
          _Metric(t('Công suất'), _unit(s.cpuPower, 'W')),
        ]),
        const SizedBox(height: 10),
        _Meter(value: s.cpuLoad, max: 100, label: t('Tải CPU')),
        const SizedBox(height: 10),
        _Spark(
            values: _h('cpuTemp'),
            min: 30,
            max: 100,
            label: t('Nhiệt độ 60 giây')),
        if (s.cpuCores.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Cores(s.cpuCores),
        ],
      ],
    );
  }

  Widget _gpuCard(PerfSample s) {
    return _Card(
      title: 'GPU',
      trailing: _TempBadge(s.gpuTemp, warnAt: 70, critAt: 83),
      children: [
        if (s.gpuName.isNotEmpty)
          Text(s.gpuName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: DeckColors.muted, fontSize: 11)),
        _bigTemp(s.gpuTemp),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _Metric(t('Tải'), _pct(s.gpuLoad)),
          _Metric('Xung', _unit(s.gpuClock, 'MHz')),
          _Metric(t('Công suất'), _unit(s.gpuPower, 'W')),
          _Metric(t('Quạt'), _pct(s.gpuFan)),
        ]),
        const SizedBox(height: 10),
        _Meter(value: s.gpuLoad, max: 100, label: t('Tải GPU')),
        const SizedBox(height: 8),
        _Meter(
          value: s.vramUsed,
          max: s.vramTotal ?? 0,
          label: 'VRAM',
          warnWhenFull: true,
          text: s.vramUsed == null || s.vramTotal == null
              ? '—'
              : '${s.vramUsed!.toStringAsFixed(1)} / '
                  '${s.vramTotal!.toStringAsFixed(0)} GB',
        ),
        const SizedBox(height: 10),
        _Spark(
            values: _h('gpuTemp'),
            min: 30,
            max: 100,
            label: t('Nhiệt độ 60 giây')),
      ],
    );
  }

  Widget _ramCard(PerfSample s) {
    return _Card(
      title: 'RAM',
      children: [
        _Meter(
          value: s.ramPercent,
          max: 100,
          label: t('Đang dùng'),
          warnWhenFull: true,
          text: s.ramUsed == null || s.ramTotal == null
              ? '—'
              : '${s.ramUsed!.toStringAsFixed(1)} / '
                  '${s.ramTotal!.toStringAsFixed(0)} GB · ${_pct(s.ramPercent)}',
        ),
      ],
    );
  }

  Widget _netCard(PerfSample s) {
    return _Card(
      title: t('Mạng'),
      children: [
        Wrap(spacing: 18, runSpacing: 4, children: [
          _Metric(t('Tải xuống'), _speed(s.netDown),
              icon: Icons.south_rounded),
          _Metric(t('Tải lên'), _speed(s.netUp), icon: Icons.north_rounded),
        ]),
      ],
    );
  }

  Widget _bigTemp(double? t) => Text(
        t == null ? '—' : '${t.round()}°C',
        style: const TextStyle(
            color: DeckColors.text, fontSize: 32, fontWeight: FontWeight.w600),
      );

  /// Lời nhắc cài phần mềm còn thiếu, chỉ hiện đúng phần đang thiếu.
  List<Widget> _hints(PerfSample s) {
    final tips = <(IconData, String)>[
      if (!s.hasRtss)
        (
          Icons.speed_rounded,
          t('FPS cần RivaTuner Statistics Server (RTSS) — cài kèm MSI Afterburner. Mở RTSS trước khi vào game, FPS hiện sau vài giây.')
        ),
      if (!s.hasLhm)
        (
          Icons.thermostat_rounded,
          t('Nhiệt độ, xung và công suất CPU cần LibreHardwareMonitor: chạy bằng quyền Administrator, vào Options → Remote Web Server → Run (cổng 8085).')
        ),
      if (!s.hasGpu)
        (
          Icons.memory_rounded,
          t('Không đọc được GPU. Card NVIDIA cần driver mới; card khác cần LibreHardwareMonitor như trên.')
        ),
    ];
    if (tips.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      for (final (icon, text) in tips)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: DeckColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: DeckColors.muted, fontSize: 12, height: 1.45)),
              ),
            ],
          ),
        ),
    ];
  }

  // -------------------------------------------------------------- định dạng

  static String _pct(double? v) => v == null ? '—' : '${v.round()}%';

  static String _unit(double? v, String unit) =>
      v == null ? '—' : '${v.round()} $unit';

  static String _speed(double? bytesPerSecond) {
    final b = bytesPerSecond;
    if (b == null) return '—';
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB/s';
    if (b >= 1 << 10) return '${(b / (1 << 10)).toStringAsFixed(0)} KB/s';
    return '${b.round()} B/s';
  }
}

// ---------------------------------------------------------------- thành phần

class _Center extends StatelessWidget {
  final String text;
  final bool busy;
  const _Center(this.text, {this.busy = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: DeckColors.muted),
                ),
                const SizedBox(height: 12),
              ],
              Text(text,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: DeckColors.muted, fontSize: 13)),
            ],
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _Card({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DeckColors.line, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: DeckColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const _Metric(this.label, this.value, {this.icon});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: DeckColors.muted),
                const SizedBox(width: 2),
              ],
              Text(label,
                  style:
                      const TextStyle(color: DeckColors.muted, fontSize: 11)),
            ],
          ),
          Text(value,
              style: const TextStyle(
                  color: DeckColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
        ],
      );
}

/// Nhãn nhiệt độ: icon + chữ, màu chỉ là kênh phụ.
class _TempBadge extends StatelessWidget {
  final double? temp;
  final double warnAt;
  final double critAt;
  const _TempBadge(this.temp, {required this.warnAt, required this.critAt});

  @override
  Widget build(BuildContext context) {
    final v = temp;
    if (v == null) return const SizedBox.shrink();
    final (color, icon, label) = v >= critAt
        ? (_critical, Icons.local_fire_department_rounded, t('Nóng'))
        : v >= warnAt
            ? (_warning, Icons.warning_amber_rounded, t('Ấm'))
            : (_good, Icons.check_circle_rounded, t('Mát'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: DeckColors.text, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Thanh đo: nền là sắc nhạt của chính màu thanh. Chỉ thanh nào đầy là
/// có vấn đề (RAM, VRAM) mới chuyển màu cảnh báo khi quá 90% — GPU chạy
/// gần 100% lúc chơi game là tốt, không phải cảnh báo.
class _Meter extends StatelessWidget {
  final double? value;
  final double max;
  final String label;
  final String? text;
  final bool warnWhenFull;
  const _Meter({
    required this.value,
    required this.max,
    required this.label,
    this.text,
    this.warnWhenFull = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        (value == null || max <= 0) ? 0.0 : (value! / max).clamp(0.0, 1.0);
    final color =
        warnWhenFull && ratio >= 0.9 ? _warning : DeckColors.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: DeckColors.muted, fontSize: 11)),
            const Spacer(),
            Text(text ?? (value == null ? '—' : '${(ratio * 100).round()}%'),
                style: const TextStyle(color: DeckColors.text, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}

/// Đường xu hướng 60 giây. Thang đo cố định theo loại số đo (nhiệt độ luôn
/// 30–100°C) để hình dạng đường không đánh lừa khi giá trị chỉ nhích nhẹ.
class _Spark extends StatelessWidget {
  final List<double?> values;
  final double min;
  final double max;
  final String label;
  const _Spark({
    required this.values,
    required this.min,
    required this.max,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final known = values.whereType<double>();
    final lo = known.isEmpty ? null : known.reduce(math.min);
    final hi = known.isEmpty ? null : known.reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: DeckColors.muted, fontSize: 10)),
            const Spacer(),
            if (lo != null)
              Text(t('thấp {0} · cao {1}', [lo.round(), hi!.round()]),
                  style:
                      const TextStyle(color: DeckColors.muted, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: CustomPaint(
            painter: _SparkPainter(values, min, max),
          ),
        ),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double?> values;
  final double min;
  final double max;
  _SparkPainter(this.values, this.min, this.max);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = DeckColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 0.5),
        Offset(size.width, size.height - 0.5), base);
    if (values.isEmpty || max <= min) return;

    final step = size.width / (_PerfScreenState._historyLength - 1);
    // Dồn về bên phải: điểm mới nhất luôn ở mép phải.
    final start = _PerfScreenState._historyLength - values.length;
    double y(double v) =>
        size.height - ((v - min) / (max - min)).clamp(0.0, 1.0) * size.height;

    final line = Paint()
      ..color = DeckColors.muted
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path();
    var pen = false;
    Offset? last;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        pen = false; // thiếu số đo thì ngắt đường, không nối bừa
        continue;
      }
      final p = Offset((start + i) * step, y(v));
      pen ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
      pen = true;
      last = p;
    }
    canvas.drawPath(path, line);
    if (last != null && values.last != null) {
      canvas.drawCircle(last, 4, Paint()..color = DeckColors.surface);
      canvas.drawCircle(last, 3, Paint()..color = DeckColors.accent);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}

/// Tải từng luồng CPU, mỗi cột một luồng.
class _Cores extends StatelessWidget {
  final List<int> cores;
  const _Cores(this.cores);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('Tải {0} luồng', [cores.length]),
            style: const TextStyle(color: DeckColors.muted, fontSize: 10)),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final c in cores)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: 2 + 26 * (c.clamp(0, 100) / 100),
                      decoration: const BoxDecoration(
                        color: DeckColors.accent,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
