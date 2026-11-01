import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Con trỏ chuột vẽ giống Windows, theo loại agent báo (xem agent/screen.py):
/// 0 ẩn, 1 mũi tên, 2 chữ I, 3 bàn tay, 4 chờ, 5 mũi tên + chờ, 6 chữ thập,
/// 7 kéo 4 hướng, 8 ngang, 9 dọc, 10 chéo ↘, 11 chéo ↗, 12 cấm.
///
/// Vẽ bằng nét vector nên luôn sắc, không bị nhoè theo ảnh JPEG. Kích thước cố
/// định trên điện thoại (không thu nhỏ theo màn hình máy tính), để luôn nhìn ra.
class PcCursor extends StatelessWidget {
  final int kind;
  const PcCursor({super.key, required this.kind});

  /// Ô vẽ, đơn vị điểm trên điện thoại.
  static const box = 24.0;

  /// Điểm "chạm" của con trỏ trong ô vẽ — chỗ Windows thực sự nhấp chuột.
  /// Mũi tên nhấp ở đầu mũi, bàn tay ở đầu ngón, còn lại ở giữa.
  static Offset hotspot(int kind) => switch (kind) {
        1 || 5 => const Offset(2, 1),
        3 => const Offset(9, 1),
        _ => const Offset(box / 2, box / 2),
      };

  @override
  Widget build(BuildContext context) {
    if (kind == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
          size: const Size(box, box), painter: _CursorPainter(kind)),
    );
  }
}

class _CursorPainter extends CustomPainter {
  final int kind;
  _CursorPainter(this.kind);

  static final _fill = Paint()..color = Colors.white;
  static final _ink = Paint()..color = Colors.black;
  static final _edge = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeJoin = StrokeJoin.round;
  static final _halo = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round;
  static final _line = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case 1:
        _arrow(canvas);
      case 5:
        _arrow(canvas);
        _spinner(canvas, const Offset(16.5, 17), 4.5);
      case 2:
        _ibeam(canvas);
      case 3:
        _hand(canvas);
      case 4:
        _spinner(canvas, const Offset(12, 12), 8);
      case 6:
        _strokes(canvas, [
          [const Offset(12, 3), const Offset(12, 21)],
          [const Offset(3, 12), const Offset(21, 12)],
        ]);
      case 7:
        _double(canvas, 0);
        _double(canvas, math.pi / 2);
      case 8:
        _double(canvas, 0);
      case 9:
        _double(canvas, math.pi / 2);
      case 10:
        _double(canvas, math.pi / 4);
      case 11:
        _double(canvas, -math.pi / 4);
      case 12:
        _no(canvas);
      default:
        _arrow(canvas);
    }
  }

  /// Mũi tên trắng viền đen, như con trỏ mặc định của Windows.
  void _arrow(Canvas c) {
    final p = Path()
      ..moveTo(2, 1)
      ..lineTo(2, 18.5)
      ..lineTo(6.2, 14.6)
      ..lineTo(9.1, 21.2)
      ..lineTo(11.9, 20)
      ..lineTo(9.1, 13.6)
      ..lineTo(14.8, 13.6)
      ..close();
    c.drawPath(p.shift(const Offset(0.8, 0.8)),
        Paint()..color = Colors.black.withValues(alpha: 0.3));
    c.drawPath(p, _fill);
    c.drawPath(p, _edge);
  }

  /// Chữ I khi trỏ vào ô chữ: nét đen có viền trắng để thấy trên mọi nền.
  void _ibeam(Canvas c) {
    final segs = [
      [const Offset(12, 4), const Offset(12, 20)],
      [const Offset(8.5, 3.5), const Offset(15.5, 3.5)],
      [const Offset(8.5, 20.5), const Offset(15.5, 20.5)],
    ];
    for (final s in segs) {
      c.drawLine(s[0], s[1], _halo);
    }
    for (final s in segs) {
      c.drawLine(s[0], s[1], _line);
    }
  }

  /// Bàn tay chỉ ngón trỏ, khi trỏ vào đường link.
  void _hand(Canvas c) {
    final p = Path()
      ..moveTo(7.6, 3)
      ..arcToPoint(const Offset(10.4, 3), radius: const Radius.circular(1.4))
      ..lineTo(10.4, 10.2)
      ..lineTo(12.6, 9.6)
      ..lineTo(15, 10.2)
      ..lineTo(17.4, 10.8)
      ..quadraticBezierTo(19.6, 11.4, 19.4, 14)
      ..lineTo(18.8, 18.4)
      ..quadraticBezierTo(18.2, 21.6, 15, 21.6)
      ..lineTo(10.6, 21.6)
      ..quadraticBezierTo(8.6, 21.6, 7.6, 19.8)
      ..lineTo(4.4, 14.2)
      ..quadraticBezierTo(3.8, 12.8, 5, 12.4)
      ..quadraticBezierTo(6.2, 12, 7.6, 13.8)
      ..close();
    c.drawPath(p, _fill);
    c.drawPath(p, _edge);
    final knuckle = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    c.drawLine(const Offset(12.6, 9.8), const Offset(12.6, 13.4), knuckle);
    c.drawLine(const Offset(15, 10.4), const Offset(15, 13.6), knuckle);
  }

  /// Vòng xoay "đang bận" của Windows.
  void _spinner(Canvas c, Offset center, double r) {
    final rect = Rect.fromCircle(center: center, radius: r);
    c.drawCircle(
        center,
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.55 + 2);
    c.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = const Color(0xFFBFD7F2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.45);
    c.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 0.9,
        false,
        Paint()
          ..color = const Color(0xFF1E73D8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.45
          ..strokeCap = StrokeCap.round);
  }

  void _strokes(Canvas c, List<List<Offset>> segs) {
    for (final s in segs) {
      c.drawLine(s[0], s[1], _halo);
    }
    for (final s in segs) {
      c.drawLine(s[0], s[1], _line);
    }
  }

  /// Mũi tên hai đầu (kéo giãn cửa sổ), xoay theo [angle].
  void _double(Canvas c, double angle) {
    c.save();
    c.translate(12, 12);
    c.rotate(angle);
    final p = Path()
      ..moveTo(-10, 0)
      ..lineTo(-5.5, -4.5)
      ..lineTo(-5.5, -1.6)
      ..lineTo(5.5, -1.6)
      ..lineTo(5.5, -4.5)
      ..lineTo(10, 0)
      ..lineTo(5.5, 4.5)
      ..lineTo(5.5, 1.6)
      ..lineTo(-5.5, 1.6)
      ..lineTo(-5.5, 4.5)
      ..close();
    c.drawPath(p, _ink);
    c.drawPath(
        p,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
    c.restore();
  }

  /// Biển cấm khi kéo thả vào chỗ không được thả.
  void _no(Canvas c) {
    const center = Offset(12, 12);
    c.drawCircle(
        center,
        9.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    final red = Paint()
      ..color = const Color(0xFFD83B3B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    c.drawCircle(center, 8, red);
    c.drawLine(const Offset(6.4, 6.4), const Offset(17.6, 17.6), red);
  }

  @override
  bool shouldRepaint(_CursorPainter old) => old.kind != kind;
}
