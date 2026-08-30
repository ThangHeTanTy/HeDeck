import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Đầu chú hề HeDeck, vẽ thẳng bằng đường nét nên nét ở mọi kích thước và
/// không kèm nền — chỉ mỗi chú hề nổi trên nền tối.
class ClownLogo extends StatelessWidget {
  final double size;

  /// Góc nghiêng, tính bằng độ. Âm là nghiêng sang trái.
  final double tiltDegrees;

  /// Đổ bóng phía sau để tạo cảm giác nổi khối.
  final bool shadow;

  const ClownLogo({
    super.key,
    this.size = 54,
    this.tiltDegrees = 0,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final art = CustomPaint(
      size: Size(size, size * _ClownPainter.boxH / _ClownPainter.boxW),
      painter: _ClownPainter(shadow: shadow),
    );
    if (tiltDegrees == 0) return art;
    return Transform.rotate(
      angle: tiltDegrees * math.pi / 180,
      child: art,
    );
  }
}

class _ClownPainter extends CustomPainter {
  final bool shadow;

  _ClownPainter({required this.shadow});

  // Khung toạ độ gốc, ôm sát chú hề để không thừa lề
  static const boxX = 13.0;
  static const boxY = 5.0;
  static const boxW = 74.0;
  static const boxH = 76.0;

  static const _hairLeft = Color(0xFF7F77DD);
  static const _hairRight = Color(0xFFF0997B);
  static const _hairLow = Color(0xFF5DCAA5);
  static const _skin = Color(0xFFF7E7D8);
  static const _hat = Color(0xFF7F77DD);
  static const _hatBrim = Color(0xFF564FA8);
  static const _pom = Color(0xFF5DCAA5);
  static const _eye = Color(0xFF1C1F28);
  static const _cheek = Color(0xFFF3BAB2);
  static const _mouth = Color(0xFFC44A52);
  static const _nose = Color(0xFFE24B4A);
  static const _noseHi = Color(0xFFFF9691);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / boxW, size.height / boxH);
    canvas.translate(-boxX, -boxY);

    if (shadow) _paintShadow(canvas);

    void dot(double cx, double cy, double r, Color c) =>
        canvas.drawCircle(Offset(cx, cy), r, Paint()..color = c);

    // Tóc xù
    dot(30, 52, 15, _hairLeft);
    dot(70, 52, 15, _hairRight);
    dot(36, 64, 11, _hairLow);
    dot(64, 64, 11, _hairLow);

    // Khuôn mặt
    dot(50, 54, 25, _skin);

    // Mũ chóp và vành mũ
    canvas.drawPath(
      Path()
        ..moveTo(35, 32)
        ..lineTo(62, 32)
        ..lineTo(54, 12)
        ..close(),
      Paint()..color = _hat,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 29, 34, 7),
        const Radius.circular(3),
      ),
      Paint()..color = _hatBrim,
    );
    dot(54, 11, 4.5, _pom);

    // Mắt và má
    dot(42, 50, 3.6, _eye);
    dot(58, 50, 3.6, _eye);
    dot(38, 60, 4, _cheek);
    dot(62, 60, 4, _cheek);

    // Miệng cười
    canvas.drawPath(
      Path()
        ..moveTo(42, 61)
        ..quadraticBezierTo(50, 69, 58, 61),
      Paint()
        ..color = _mouth
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );

    // Mũi đỏ, vẽ sau cùng để nằm trên miệng
    dot(50, 58, 5.4, _nose);
    dot(48.4, 56.4, 1.7, _noseHi);

    canvas.restore();
  }

  /// Bóng vẽ từ hình bóng đơn giản của tóc, mặt và mũ.
  ///
  /// Xếp chồng vài lớp mờ dần thay vì dùng `MaskFilter.blur`. Bộ lọc làm mờ là
  /// một trong những thứ Impeller hỗ trợ kém nhất, và trên GPU ảo nó có thể
  /// làm hỏng cả khung hình. Cách này cho ra bóng gần giống mà chạy được ở
  /// mọi nơi.
  void _paintShadow(Canvas canvas) {
    const layers = 5;
    for (var i = layers; i >= 1; i--) {
      final spread = i * 1.4;
      final paint = Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.09);

      canvas.save();
      canvas.translate(0, 4);
      canvas.drawCircle(const Offset(30, 52), 15 + spread, paint);
      canvas.drawCircle(const Offset(70, 52), 15 + spread, paint);
      canvas.drawCircle(const Offset(36, 64), 11 + spread, paint);
      canvas.drawCircle(const Offset(64, 64), 11 + spread, paint);
      canvas.drawCircle(const Offset(50, 54), 25 + spread, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ClownPainter old) => old.shadow != shadow;
}
