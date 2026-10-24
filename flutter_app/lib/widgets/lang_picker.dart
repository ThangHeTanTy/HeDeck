import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

/// Quả địa cầu xoay chậm liên tục, và quay nhanh một vòng mỗi khi [spin]
/// đổi giá trị — báo hiệu đã đổi ngôn ngữ.
class SpinningGlobe extends StatefulWidget {
  final double size;
  final Color? color;
  final Object? spin;
  const SpinningGlobe({
    super.key,
    this.size = 22,
    this.color,
    this.spin,
  });

  @override
  State<SpinningGlobe> createState() => _SpinningGlobeState();
}

class _SpinningGlobeState extends State<SpinningGlobe>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(seconds: 9))
    ..repeat();
  late final AnimationController _burst = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(SpinningGlobe old) {
    super.didUpdateWidget(old);
    if (old.spin != widget.spin) _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _idle.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _burst]),
      builder: (context, _) {
        final burst = Curves.easeOutBack.transform(_burst.value);
        // Nảy lên rồi về cỡ cũ trong lúc quay thêm một vòng.
        final scale = 1 + 0.25 * math.sin(_burst.value * math.pi);
        return Transform.rotate(
          angle: (_idle.value + burst) * 2 * math.pi,
          child: Transform.scale(
            scale: scale,
            child: Icon(Icons.language_rounded,
                size: widget.size, color: widget.color ?? DeckColors.accent),
          ),
        );
      },
    );
  }
}

/// Chọn ngôn ngữ trong bảng tuỳ chọn: hai thẻ có cờ, thẻ đang chọn phóng to
/// và viền nhấn. Tiêu đề viết cả hai thứ tiếng, để người lỡ chọn nhầm ngôn
/// ngữ mình không đọc được vẫn tìm ra chỗ đổi lại.
class LangPicker extends StatelessWidget {
  final AppLang current;
  final ValueChanged<AppLang> onPick;
  const LangPicker({super.key, required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    Widget option(AppLang lang) {
      final on = lang == current;
      return Expanded(
        child: GestureDetector(
          onTap: on ? null : () => onPick(lang),
          child: AnimatedScale(
            scale: on ? 1.0 : 0.94,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: on ? DeckColors.tile : DeckColors.tileDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: on ? DeckColors.accent : DeckColors.line,
                  width: on ? 1.6 : 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(lang.label,
                      style: TextStyle(
                        color: on ? DeckColors.text : DeckColors.muted,
                        fontSize: 14,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      )),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SpinningGlobe(size: 16, spin: current),
              const SizedBox(width: 6),
              Text('Ngôn ngữ · Language',
                  style: TextStyle(color: DeckColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [for (final l in AppLang.values) option(l)]),
        ],
      ),
    );
  }
}

/// Nút gọn cho màn hình ghép cặp: quả địa cầu xoay + cờ hiện tại, chạm là
/// chuyển sang ngôn ngữ kế tiếp.
class LangToggle extends StatelessWidget {
  final AppLang current;
  final ValueChanged<AppLang> onPick;
  const LangToggle({super.key, required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final next = AppLang.values[(current.index + 1) % AppLang.values.length];
    return Tooltip(
      message: 'Ngôn ngữ · Language',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onPick(next),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: DeckColors.tile,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DeckColors.line, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinningGlobe(size: 16, spin: current),
              const SizedBox(width: 6),
              Text(current.flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(current.name.toUpperCase(),
                  style: TextStyle(
                      color: DeckColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
