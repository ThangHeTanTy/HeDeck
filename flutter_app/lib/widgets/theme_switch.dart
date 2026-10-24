import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Nút trượt chọn chủ đề: bật là tối (mặt trăng, bên phải, trời đêm có
/// sao), tắt là sáng (mặt trời, bên trái, trời xanh có mây). Bấm hoặc kéo
/// qua lại đều được.
///
/// Núm trượt chạy hết hoạt ảnh rồi mới gọi [onChanged], vì đổi chủ đề dựng
/// lại cả giao diện — gọi ngay thì người dùng không kịp thấy nút trượt.
class ThemeSwitch extends StatefulWidget {
  final bool dark;
  final ValueChanged<bool> onChanged;
  final double width;

  const ThemeSwitch({
    super.key,
    required this.dark,
    required this.onChanged,
    this.width = 60,
  });

  @override
  State<ThemeSwitch> createState() => _ThemeSwitchState();
}

class _ThemeSwitchState extends State<ThemeSwitch>
    with SingleTickerProviderStateMixin {
  static const _slide = Duration(milliseconds: 420);

  late bool _on = widget.dark;

  /// Vị trí núm khi đang kéo, 0 (trái) .. 1 (phải). Null khi không kéo.
  double? _drag;
  Timer? _commit;

  /// Chạy liên tục: tia mặt trời xoay, sao lấp lánh.
  late final AnimationController _ambient = AnimationController(
      vsync: this, duration: const Duration(seconds: 12))
    ..repeat();

  @override
  void didUpdateWidget(ThemeSwitch old) {
    super.didUpdateWidget(old);
    if (old.dark != widget.dark) _on = widget.dark;
  }

  @override
  void dispose() {
    _commit?.cancel();
    _ambient.dispose();
    super.dispose();
  }

  void _set(bool on) {
    HapticFeedback.selectionClick();
    setState(() {
      _on = on;
      _drag = null;
    });
    _commit?.cancel();
    if (on != widget.dark) {
      _commit = Timer(_slide, () => widget.onChanged(on));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = w / 2, pad = h * 0.1, knob = h - pad * 2;
    final travel = w - h;
    final t = _drag ?? (_on ? 1.0 : 0.0);

    return Semantics(
      toggled: _on,
      label: _on ? 'Dark' : 'Light',
      child: GestureDetector(
        onTap: () => _set(!_on),
        onHorizontalDragUpdate: (d) => setState(() {
          _drag = ((_drag ?? (_on ? 1.0 : 0.0)) + d.delta.dx / travel)
              .clamp(0.0, 1.0);
        }),
        onHorizontalDragEnd: (_) => _set((_drag ?? 0) > 0.5),
        onHorizontalDragCancel: () => setState(() => _drag = null),
        child: AnimatedContainer(
          duration: _slide,
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(h / 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _on
                  ? const [Color(0xFF121A3A), Color(0xFF283A6E)]
                  : const [Color(0xFF7CC4F5), Color(0xFFB9E2FB)],
            ),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x2E000000), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Stack(
            children: [
              // Mây: trôi xuống và mờ đi khi chuyển sang đêm.
              for (final (x, y, cw, ch, o) in const [
                (0.58, 0.26, 0.30, 0.22, 0.95),
                (0.52, 0.56, 0.22, 0.18, 0.8),
              ])
                AnimatedPositioned(
                  duration: _slide,
                  curve: Curves.easeInOut,
                  left: w * x,
                  top: h * y + (_on ? h : 0),
                  width: w * cw,
                  height: h * ch,
                  child: AnimatedOpacity(
                    duration: _slide,
                    opacity: _on ? 0 : o,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(h),
                      ),
                    ),
                  ),
                ),
              // Sao: chỉ hiện ban đêm, nhấp nháy lệch nhịp nhau.
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: _slide,
                  opacity: _on ? 1 : 0,
                  child: AnimatedBuilder(
                    animation: _ambient,
                    builder: (_, __) => CustomPaint(
                      painter: _StarsPainter(_ambient.value),
                    ),
                  ),
                ),
              ),
              // Núm trượt
              AnimatedPositioned(
                duration: _drag == null ? _slide : Duration.zero,
                curve: Curves.easeOutBack,
                left: pad + travel * t,
                top: pad,
                width: knob,
                height: knob,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => RotationTransition(
                    turns: Tween(begin: -0.25, end: 0.0).animate(a),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: _on
                      ? const CustomPaint(
                          key: ValueKey('moon'),
                          size: Size.infinite,
                          painter: _MoonPainter(),
                        )
                      : AnimatedBuilder(
                          key: const ValueKey('sun'),
                          animation: _ambient,
                          builder: (_, __) => CustomPaint(
                            size: Size.infinite,
                            painter: _SunPainter(_ambient.value),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  final double spin;
  const _SunPainter(this.spin);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rays = Paint()
      ..color = const Color(0xFFFFC233)
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = spin * 2 * math.pi + i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 0.78, c + d * r * 0.98, rays);
    }
    canvas.drawCircle(c, r * 0.55, Paint()..color = const Color(0xFFFFD23F));
    canvas.drawCircle(
        c,
        r * 0.55,
        Paint()
          ..color = const Color(0xFFF5A623)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06);
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.spin != spin;
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, r * 0.92, Paint()..color = const Color(0xFFEDEAE0));
    final crater = Paint()..color = const Color(0xFFD3CEBE);
    for (final (x, y, s) in const [
      (-0.3, -0.25, 0.2),
      (0.25, 0.25, 0.26),
      (0.32, -0.38, 0.12),
      (-0.35, 0.35, 0.1),
    ]) {
      canvas.drawCircle(c + Offset(x * r, y * r), s * r, crater);
    }
  }

  @override
  bool shouldRepaint(_MoonPainter old) => false;
}

class _StarsPainter extends CustomPainter {
  final double phase;
  const _StarsPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, s, off) in const [
      (0.16, 0.28, 1.0, 0.0),
      (0.30, 0.62, 1.0, 0.25),
      (0.44, 0.22, 1.0, 0.5),
      (0.24, 0.44, 0.7, 0.75),
    ]) {
      final tw = 0.65 + 0.35 * math.cos((phase * 5 + off) * 2 * math.pi);
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        size.height * 0.045 * s,
        Paint()..color = Colors.white.withValues(alpha: tw),
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.phase != phase;
}
