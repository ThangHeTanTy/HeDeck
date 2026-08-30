import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/deck.dart';
import '../theme.dart';
import 'app_icon.dart';
import 'icon_library.dart';

/// Trạng thái viền của một ô.
enum TileBorder {
  /// Chưa mở — không viền, ô chìm vào nền.
  idle,

  /// Vừa bấm mở, đang chờ cửa sổ xuất hiện — viền tím.
  pending,

  /// Đang chạy — viền xanh lục.
  live,
}

class DeckTileView extends StatefulWidget {
  final DeckTile tile;
  final RemoteApp? app;
  final AppStatus status;
  final bool pending;
  final bool editing;

  /// Ô hai trạng thái đang ở mặt phụ.
  final bool flipped;

  /// Ô trống đầu tiên trong trang, chỗ duy nhất hiện dấu cộng.
  final bool isFirstEmpty;

  final VoidCallback onTap;
  final VoidCallback onEdit;

  /// Gọi khi giữ đủ 5 giây trên một ô đang chạy.
  final VoidCallback onForceClose;

  const DeckTileView({
    super.key,
    required this.tile,
    required this.status,
    required this.onTap,
    required this.onEdit,
    required this.onForceClose,
    this.app,
    this.pending = false,
    this.editing = false,
    this.flipped = false,
    this.isFirstEmpty = false,
  });

  @override
  State<DeckTileView> createState() => _DeckTileViewState();
}

class _DeckTileViewState extends State<DeckTileView>
    with SingleTickerProviderStateMixin {
  static const holdDuration = Duration(seconds: 3);

  late final AnimationController _hold;
  bool _down = false;
  bool _closedByHold = false;

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(vsync: this, duration: holdDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _fireClose();
      });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  TileFace get _face => widget.tile.face(widget.flipped);

  /// Chỉ ô ứng dụng đang chạy mới cho giữ để tắt.
  bool get _canForceClose =>
      !widget.editing &&
      widget.tile.kind == TileKind.app &&
      widget.status.running;

  TileBorder get _borderState {
    if (widget.tile.kind != TileKind.app) return TileBorder.idle;
    if (widget.status.running) return TileBorder.live;
    if (widget.pending) return TileBorder.pending;
    return TileBorder.idle;
  }

  void _fireClose() {
    HapticFeedback.heavyImpact();
    _closedByHold = true;
    widget.onForceClose();
    _hold.reset();
    if (mounted) setState(() => _down = false);
  }

  void _startHold() {
    if (!_canForceClose) return;
    _closedByHold = false;
    _hold.forward(from: 0);
  }

  void _cancelHold() {
    if (_hold.isAnimating) _hold.stop();
    _hold.reset();
  }

  void _handleTap() {
    // Vừa tắt app xong thì lần nhả tay này không tính là một cú chạm.
    if (_closedByHold) {
      _closedByHold = false;
      return;
    }
    widget.onTap();
  }

  // ------------------------------------------------------------------ nội dung

  /// Chữ dưới icon. Trạng thái đã do màu viền lo, nên chỉ còn tên tự đặt.
  String? get _caption {
    final tile = widget.tile;
    if (tile.isEmpty) return widget.isFirstEmpty ? 'Thêm ô' : null;
    final label = _face.label;
    if (label.isNotEmpty) return label;
    // Macro không đặt tên thì hiện tổ hợp phím: icon giống nhau hết, không có
    // chữ thì chịu không phân biệt nổi.
    if (tile.kind == TileKind.macro && _face.keys.isNotEmpty) {
      return _face.keys.join(' › ');
    }
    return null;
  }

  /// Tên tự đặt hiện sáng, chữ gợi ý hiện mờ.
  bool get _captionIsName => _face.label.isNotEmpty;

  IconData get _glyph {
    // Icon người dùng chọn từ thư viện luôn được ưu tiên.
    final chosen = IconLibrary.lookup(_face.icon);
    if (chosen != null) return chosen;

    switch (widget.tile.kind) {
      case TileKind.app:
        return Icons.desktop_windows_rounded;
      case TileKind.macro:
        return Icons.keyboard_rounded;
      case TileKind.media:
        return _mediaGlyph(_face.mediaAction);
      case TileKind.appVolume:
        return switch (widget.tile.volumeAction) {
          'up' => Icons.volume_up_rounded,
          'down' => Icons.volume_down_rounded,
          _ => Icons.volume_off_rounded,
        };
      case TileKind.empty:
        return Icons.add_rounded;
    }
  }

  static IconData _mediaGlyph(String? action) => switch (action) {
        'next' => Icons.skip_next_rounded,
        'prev' => Icons.skip_previous_rounded,
        'volup' => Icons.volume_up_rounded,
        'voldown' => Icons.volume_down_rounded,
        'mute' => Icons.volume_off_rounded,
        'stop' => Icons.stop_rounded,
        _ => Icons.play_arrow_rounded,
      };

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    final caption = _caption;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _down = true);
        _startHold();
      },
      onTapUp: (_) {
        setState(() => _down = false);
        _cancelHold();
      },
      onTapCancel: () {
        setState(() => _down = false);
        _cancelHold();
      },
      onTap: _handleTap,
      // Ô đang chạy dùng cú giữ để tắt, nên sửa ô phải qua nút bút chì.
      onLongPress: _canForceClose ? null : widget.onEdit,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => _surface(tile, caption),
        ),
      ),
    );
  }

  Widget _surface(DeckTile tile, String? caption) {
    final holding = _hold.value > 0;
    final state = _borderState;
    final showCaption = caption != null || holding;

    final baseBorder = switch (state) {
      TileBorder.live => DeckColors.live,
      TileBorder.pending => DeckColors.accent,
      TileBorder.idle => widget.tile.isToggle && widget.flipped
          // Ô hai trạng thái đang bật: viền theo màu mặt phụ.
          ? DeckColors.swatch(widget.tile.back.accent)
          : Colors.transparent,
    };
    final borderWidth = (state == TileBorder.idle &&
            !(widget.tile.isToggle && widget.flipped))
        ? 0.0
        : 2.5;

    return Stack(
      // expand: mọi lớp nhận đúng kích thước ô, không co theo nội dung.
      // Đây là điều kiện để icon căn giữa chuẩn ở cả hai chiều.
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: tile.isEmpty
                ? DeckColors.tileDim
                : (widget.tile.isToggle && widget.flipped
                    // Nền sáng hơn một chút khi đang bật, thấy ngay từ xa.
                    ? Color.alphaBlend(
                        DeckColors.swatch(widget.tile.back.accent)
                            .withValues(alpha: 0.16),
                        DeckColors.tile)
                    : DeckColors.tile),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: holding ? Colors.transparent : baseBorder,
              width: holding ? 0 : borderWidth,
            ),
          ),
          // Lề mỏng nhất có thể để icon chiếm tối đa diện tích
          padding: EdgeInsets.fromLTRB(3, 3, 3, showCaption ? 4 : 3),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Cạnh lớn nhất vẽ vừa cả bề ngang lẫn bề dọc còn lại
                    final side = math.min(box.maxWidth, box.maxHeight);
                    return Align(
                      alignment: Alignment.center,
                      child: _icon(side.clamp(20.0, 320.0)),
                    );
                  },
                ),
              ),
              if (showCaption) ...[
                const SizedBox(height: 2),
                SizedBox(
                  height: 14,
                  child: Text(
                    holding
                        ? 'Tắt sau ${(3 - _hold.value * 3).ceil()}s'
                        : caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: holding
                          ? FontWeight.w600
                          : (_captionIsName
                              ? FontWeight.w500
                              : FontWeight.w400),
                      color: holding
                          ? DeckColors.danger
                          : (_captionIsName
                              ? DeckColors.text
                              : DeckColors.muted),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Viền đỏ chạy dần quanh ô khi đang giữ để tắt.
        if (holding)
          IgnorePointer(
            child: CustomPaint(
              painter: _HoldRingPainter(
                progress: _hold.value,
                color: DeckColors.danger,
                radius: 14,
              ),
            ),
          ),

        if (widget.editing && !tile.isEmpty)
          const Positioned(
            top: 5,
            right: 5,
            child: Icon(Icons.edit_rounded, size: 14, color: DeckColors.muted),
          ),
      ],
    );
  }

  Widget _icon(double box) {
    final tile = widget.tile;

    if (tile.isEmpty) {
      if (!widget.isFirstEmpty) return const SizedBox.shrink();
      return Icon(Icons.add_rounded,
          size: box.clamp(24.0, 56.0), color: DeckColors.muted);
    }

    // Chọn icon từ thư viện thì dùng icon đó, kể cả với ô ứng dụng.
    final chosen = IconLibrary.lookup(_face.icon);
    if (chosen != null) {
      return Icon(chosen,
          size: box.clamp(24.0, 140.0), color: DeckColors.swatch(_face.accent));
    }

    final bytes = widget.app?.icon;
    if (tile.kind == TileKind.app && bytes != null) {
      return AppIcon(
        bytes: bytes,
        size: box,
        nativePixels: widget.app?.iconNative ?? 0,
      );
    }

    return Icon(
      _glyph,
      size: box.clamp(24.0, 140.0),
      color: DeckColors.swatch(_face.accent),
    );
  }
}

/// Vẽ viền bo góc chạy dần từ 0 đến 100% theo tiến độ giữ.
class _HoldRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double radius;

  _HoldRingPainter({
    required this.progress,
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.25),
      Radius.circular(radius),
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color.withValues(alpha: 0.22);
    canvas.drawRRect(rrect, track);

    if (progress <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HoldRingPainter old) =>
      old.progress != progress || old.color != color;
}
