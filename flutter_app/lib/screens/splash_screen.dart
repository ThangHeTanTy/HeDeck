import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/store.dart';
import '../theme.dart';
import '../widgets/clown_logo.dart';
import 'deck_screen.dart';
import 'pair_screen.dart';

/// Gốc của app: màn hình chính luôn được dựng sẵn, màn hình mở đầu chỉ là một
/// lớp phủ bên trên rồi mờ dần đi.
///
/// Bản trước dùng `Navigator.pushReplacement` gọi từ lời gọi lại khi hoạt ảnh
/// kết thúc. Cả việc chuyển màn hình treo vào đúng một sự kiện: nó không chạy
/// thì app kẹt vĩnh viễn ở nền tối, không lỗi, không cách nào thoát. Cách này
/// không có điểm chết đó — màn hình chính đã nằm sẵn dưới lớp phủ ngay từ đầu.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showOverlay = true;

  void _dismiss() {
    if (mounted && _showOverlay) {
      setState(() => _showOverlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paired = context.watch<Store>().isPaired;

    return Material(
      color: DeckColors.bg,
      child: Stack(
        // expand: ép màn hình bên dưới nhận đúng kích thước toàn màn hình.
        // Stack mặc định đưa ràng buộc lỏng, con có thể tự co lại thành rỗng —
        // và một Scaffold rỗng nhìn y hệt màn hình đen.
        fit: StackFit.expand,
        children: [
          // Màn hình chính dựng ngay từ đầu, nằm dưới lớp phủ
          paired ? const DeckScreen() : const PairScreen(),

          if (_showOverlay) _SplashOverlay(onDone: _dismiss),
        ],
      ),
    );
  }
}

/// Lớp phủ mở đầu: chú hề hiện trên nền trắng, rồi một vòng tối lan từ giữa ra
/// phủ kín, sau đó cả lớp mờ dần để lộ màn hình bên dưới.
class _SplashOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _SplashOverlay({required this.onDone});

  @override
  State<_SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<_SplashOverlay>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1650);

  late final AnimationController _c;
  late final Animation<double> _logoIn;
  late final Animation<double> _sweep;
  late final Animation<double> _fadeOut;

  Timer? _safety;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _total);

    _logoIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOutBack),
    );
    _sweep = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.55, 0.88, curve: Curves.easeInCubic),
    );
    _fadeOut = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.88, 1.0, curve: Curves.easeOut),
    );

    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish('hoạt ảnh xong');
    });

    // Lưới an toàn: dù hoạt ảnh có trục trặc gì, lớp phủ vẫn phải biến mất.
    // Không bao giờ để người dùng ngồi nhìn một màn hình đứng yên.
    _safety = Timer(_total + const Duration(seconds: 2), () {
      _finish('hết thời gian chờ');
    });

    _c.forward();
  }

  void _finish(String reason) {
    if (_done) return;
    _done = true;
    _safety?.cancel();
    debugPrint('HeDeck: bỏ màn hình mở đầu ($reason)');
    widget.onDone();
  }

  @override
  void dispose() {
    _safety?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final opacity = (1 - _fadeOut.value).clamp(0.0, 1.0);
        if (opacity <= 0) return const SizedBox.shrink();

        return Opacity(
          opacity: opacity,
          child: Material(
            color: Colors.white,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Opacity(
                    opacity: _logoIn.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.72 + 0.28 * _logoIn.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ClownLogo(size: 132, shadow: false),
                          const SizedBox(height: 18),
                          Text(
                            'HeDeck',
                            style: TextStyle(
                              color: DeckColors.bg,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Vòng tối lan từ tâm ra, nuốt dần nền trắng
                if (_sweep.value > 0)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _SweepPainter(
                        progress: _sweep.value,
                        color: DeckColors.bg,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SweepPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SweepPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Bán kính đủ phủ tới góc xa nhất, cộng thêm chút cho chắc
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2 + 8;
    // Bắt đầu từ cỡ chú hề chứ không phải từ một chấm, cho liền mạch
    final radius = 56 + (maxRadius - 56) * progress.clamp(0.0, 1.0);
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.progress != progress || old.color != color;
}
