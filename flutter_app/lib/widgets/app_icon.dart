import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Icon đã dò xong vùng có nội dung thật.
class _Trimmed {
  final ui.Image image;

  /// Vùng thật sự có pixel không trong suốt, tính theo toạ độ ảnh gốc.
  final Rect content;

  _Trimmed(this.image, this.content);
}

/// Vẽ icon ứng dụng sao cho phần có nội dung luôn nằm giữa và lấp đầy ô.
///
/// Nhiều icon Windows là ảnh vuông nhưng hình vẽ chỉ chiếm một góc, phần còn
/// lại trong suốt. Vẽ thẳng ảnh đó ra thì icon trông nhỏ và lệch. Widget này
/// quét kênh alpha một lần để tìm vùng có nội dung, rồi chỉ vẽ đúng vùng đó.
class AppIcon extends StatefulWidget {
  final Uint8List bytes;

  /// Kích thước tối đa được phép chiếm.
  final double size;

  /// Độ phân giải gốc trên laptop. Khác 0 thì icon sẽ không bao giờ được vẽ
  /// lớn hơn số pixel thật nó có — thà nhỏ hơn một chút còn hơn vỡ hình.
  final int nativePixels;

  const AppIcon({
    super.key,
    required this.bytes,
    required this.size,
    this.nativePixels = 0,
  });

  @override
  State<AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<AppIcon> {
  /// Mỗi mảng byte chỉ phải giải mã và quét một lần cho cả vòng đời app.
  static final Map<Uint8List, Future<_Trimmed?>> _cache =
      HashMap<Uint8List, Future<_Trimmed?>>(
    equals: identical,
    hashCode: identityHashCode,
  );

  _Trimmed? _ready;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AppIcon old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) {
      _ready = null;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = widget.bytes;
    final future = _cache.putIfAbsent(bytes, () => _decodeAndTrim(bytes));
    final result = await future;
    if (mounted && identical(bytes, widget.bytes)) {
      setState(() => _ready = result);
    }
  }

  static Future<_Trimmed?> _decodeAndTrim(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        return _Trimmed(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        );
      }

      final pixels = data.buffer.asUint8List();
      final w = image.width, h = image.height;
      int minX = w, minY = h, maxX = -1, maxY = -1;

      for (var y = 0; y < h; y++) {
        final row = y * w * 4;
        for (var x = 0; x < w; x++) {
          // Ngưỡng 12 để bỏ qua viền khử răng cưa gần như trong suốt
          if (pixels[row + x * 4 + 3] > 12) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      final content = maxX < 0
          ? Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())
          : Rect.fromLTRB(minX.toDouble(), minY.toDouble(),
              (maxX + 1).toDouble(), (maxY + 1).toDouble());

      return _Trimmed(image, content);
    } catch (_) {
      return null;
    }
  }

  /// Số pixel thật mà vùng nội dung của icon có.
  double _availablePixels() {
    final ready = _ready;
    if (ready == null) return 0;
    var pixels = ready.content.shortestSide;
    if (widget.nativePixels > 0) {
      // Ảnh có thể đã được phóng to từ trước khi gửi sang, nên quy về tỉ lệ
      // vùng nội dung so với cả ảnh rồi mới nhân với độ phân giải gốc.
      final ratio = ready.content.shortestSide / ready.image.width;
      pixels = math.min(pixels, widget.nativePixels * ratio);
    }
    return pixels;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    if (ready == null) {
      // Chưa giải mã xong: giữ đúng chỗ để lưới không nhảy
      return SizedBox.square(dimension: widget.size);
    }
    // Icon luôn chiếm ít nhất 82% ô — nhỏ hơn nữa thì nhìn lọt thỏm.
    // Trong khoảng đó, nếu độ phân giải gốc quá thấp thì thu bớt một chút cho
    // đỡ vỡ, nhưng không bao giờ thu xuống mức lấy thước đo pixel làm chủ.
    const floor = 0.82;
    var drawSize = widget.size;

    final pixels = _availablePixels();
    if (pixels > 0) {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      // Cho phép phóng tới 2,4 lần số pixel thật. Ở mức này mắt thường gần như
      // không thấy răng cưa, vì icon đã được nội suy bậc cao lúc vẽ.
      final comfortable = pixels / dpr * 2.4;
      drawSize = math.max(comfortable, widget.size * floor);
      drawSize = math.min(drawSize, widget.size);
    }

    return SizedBox.square(
      dimension: widget.size,
      child: Center(
        child: SizedBox.square(
          dimension: drawSize,
          child: CustomPaint(painter: _TrimmedIconPainter(ready)),
        ),
      ),
    );
  }
}

class _TrimmedIconPainter extends CustomPainter {
  final _Trimmed icon;

  _TrimmedIconPainter(this.icon);

  @override
  void paint(Canvas canvas, Size size) {
    final src = icon.content;
    if (src.isEmpty) return;

    final dst = Offset.zero & size;
    final scale = math.min(dst.width / src.width, dst.height / src.height);
    final target = Rect.fromCenter(
      center: dst.center,
      width: src.width * scale,
      height: src.height * scale,
    );

    canvas.drawImageRect(
      icon.image,
      src,
      target,
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_TrimmedIconPainter old) =>
      old.icon.image != icon.image || old.icon.content != icon.content;
}
