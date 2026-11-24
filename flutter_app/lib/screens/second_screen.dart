import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/deck_connection.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/pc_cursor.dart';

/// Màn hình phụ: điện thoại hiện một màn hình hoặc một cửa sổ của máy tính,
/// chạm thẳng lên hình để điều khiển như màn hình cảm ứng.
///
/// - Chọn một **cửa sổ** (Discord, OBS, Spotify...): chỉ cửa sổ đó, kể cả khi
///   nó bị cửa sổ khác che trên máy tính.
/// - Chọn một **màn hình**: màn hình thứ hai, hoặc màn hình ảo (cài bằng
///   nút "Thêm màn hình ảo" trên cửa sổ HeDeck ở máy tính) — khi đó điện
///   thoại là màn hình mở rộng thật, kéo
///   cửa sổ sang là hiện ở đây.
///
/// Cử chỉ:
/// - chạm: nhấp chuột trái (chạm nhanh hai lần: nhấp đúp)
/// - kéo một ngón: cuộn
/// - giữ yên rồi thả: chuột phải; giữ yên rồi kéo: kéo thả
/// - chụm hai ngón: phóng to vùng quanh con trỏ
class SecondScreen extends StatefulWidget {
  const SecondScreen({super.key});

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  late final DeckConnection _conn;
  late final Store _store;

  /// Nguồn đang xem, gửi kèm mỗi lần xin khung và mỗi lần chạm.
  Map<String, int>? _source;
  String _sourceLabel = '';

  // ---------------------------------------------------------- khung hình

  Timer? _frameTimer;
  Timer? _stallTimer;
  DateTime _askedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Uint8List? _lastJpeg;

  /// Đang có hình thay đổi thì xin dày; đứng yên thì thưa lại cho đỡ tốn.
  static const _minGap = Duration(milliseconds: 60);
  static const _idleGap = Duration(milliseconds: 220);

  double _zoom = 1;

  /// Hình đang nằm ở đâu trên màn hình điện thoại, để đổi điểm chạm ra vị
  /// trí trên máy tính. Ghi lại mỗi lần vẽ.
  Rect _pic = Rect.zero;
  ScreenFrame? _shown;

  // -------------------------------------------------------------- cử chỉ

  final Map<int, Offset> _points = {};
  Offset _start = Offset.zero;
  DateTime _downAt = DateTime.now();
  double _travel = 0;
  Timer? _holdTimer;
  bool _held = false, _dragging = false, _scrolling = false;

  /// Đã đặt hai ngón (chụm): bỏ qua ngón còn lại cho tới khi nhấc hết tay.
  bool _multi = false;
  double _scrollRest = 0;
  double _pinchStart = 0, _zoomAtPinch = 1;

  static const _tapTime = Duration(milliseconds: 260);
  static const _slop = 10.0;
  static const _holdTime = Duration(milliseconds: 480);
  static const _scrollStep = 36.0;

  // ------------------------------------------------------------ nút nổi

  bool _controlsBright = true;

  /// Dải hướng dẫn cử chỉ, hiện vài giây mỗi lần chọn nguồn: chạm thẳng lên
  /// hình khác touchpad (kéo là cuộn chứ không phải di chuột).
  bool _hint = false;
  Timer? _hintTimer;
  Timer? _dimTimer;

  @override
  void initState() {
    super.initState();
    _conn = context.read<DeckConnection>();
    _store = context.read<Store>();
    _conn.screen.addListener(_onFrame);
    _conn.screenLost.addListener(_onLost);
    _conn.screenLost.value = null;
    _conn.addListener(_onConn);
    _wake();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start0());
  }

  /// Đã hỏi danh sách nguồn lần đầu chưa (chỉ hỏi khi đã kết nối và agent
  /// đủ mới).
  bool _started = false;
  bool _wasOnline = false;

  void _onConn() {
    final online = _conn.isOnline;
    if (online && !_wasOnline) {
      // Vừa kết nối (lại): mở lần đầu, hoặc xin khung tiếp.
      if (!_started) {
        _start0();
      } else {
        _askFrame();
      }
    }
    _wasOnline = online;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _conn.screen.removeListener(_onFrame);
    _conn.screenLost.removeListener(_onLost);
    _conn.removeListener(_onConn);
    _frameTimer?.cancel();
    _stallTimer?.cancel();
    _holdTimer?.cancel();
    _dimTimer?.cancel();
    _hintTimer?.cancel();
    final src = _source;
    if (_dragging && src != null) _conn.pointer(src, 0, 0, 'up');
    if (src != null) _conn.stopScreen();
    super.dispose();
  }

  bool get _supported =>
      _conn.agentVersion >= DeckConnection.secondScreenAgentVersion;

  /// Mở lần đầu: dùng lại nguồn đã chọn lần trước nếu còn, không thì hỏi.
  Future<void> _start0() async {
    _wasOnline = _conn.isOnline;
    if (_started || !_conn.isOnline || !_supported) return;
    _started = true;
    ScreenSources list;
    try {
      list = await _conn.listSources();
    } catch (e) {
      _started = false;
      _snack('$e');
      return;
    }
    if (!mounted) return;
    final saved = _store.secondSource;
    if (saved.startsWith('m:')) {
      final id = int.tryParse(saved.substring(2));
      final m = list.monitors.where((m) => m.id == id).firstOrNull;
      // Chỉ tự mở lại màn hình phụ thật; màn hình chính thì hỏi lại cho
      // chắc (có thể lần trước chỉ xem tạm).
      if (m != null && !m.primary) {
        _use(_monitorSource(m), _monitorLabel(m));
        return;
      }
    } else if (saved.startsWith('w:')) {
      final exe = saved.substring(2);
      final w = list.windows.where((w) => w.exe == exe).firstOrNull;
      if (w != null) {
        _use({'window': w.id}, w.title);
        return;
      }
    }
    _pick(list);
  }

  Map<String, int> _monitorSource(ScreenMonitor m) => {'monitor': m.id};

  String _monitorLabel(ScreenMonitor m) =>
      '${t('Màn hình {0}', [m.id + 1])} · ${m.width}×${m.height}';

  void _use(Map<String, int> source, String label, {String? remember}) {
    setState(() {
      _source = source;
      _sourceLabel = label;
      _zoom = 1;
      _shown = null;
    });
    _conn.screen.value = null;
    if (remember != null) _store.setSecondSource(remember);
    _askFrame();
    _showHint();
  }

  void _showHint() {
    setState(() => _hint = true);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _hint = false);
    });
  }

  // --------------------------------------------------------- khung hình

  String _level() {
    final chosen = _store.screenLevel;
    if (chosen.isNotEmpty) return chosen;
    // Màn hình phụ đặt cạnh máy, thường cùng Wi-Fi: mặc định nét hơn touchpad.
    return _conn.viaRemote ? 'mid' : 'high';
  }

  void _askFrame() {
    _frameTimer?.cancel();
    final src = _source;
    if (!mounted || src == null || !_conn.isOnline) return;
    _askedAt = DateTime.now();
    _conn.requestScreen(_level(), zoom: _zoom, source: src);
    _stallTimer?.cancel();
    _stallTimer = Timer(const Duration(seconds: 4), _askFrame);
  }

  void _onFrame() {
    final frame = _conn.screen.value;
    if (frame == null || _source == null) return;
    _stallTimer?.cancel();
    final idle = identical(frame.jpeg, _lastJpeg);
    _lastJpeg = frame.jpeg;
    final wait =
        (idle ? _idleGap : _minGap) - DateTime.now().difference(_askedAt);
    _frameTimer?.cancel();
    _frameTimer = Timer(wait.isNegative ? Duration.zero : wait, _askFrame);
  }

  void _onLost() {
    final why = _conn.screenLost.value;
    if (why == null || !mounted) return;
    _conn.screenLost.value = null;
    _frameTimer?.cancel();
    _stallTimer?.cancel();
    setState(() => _source = null);
    _snack(why);
    _openPicker();
  }

  // ------------------------------------------------------------- chọn nguồn

  Future<void> _openPicker() async {
    try {
      final list = await _conn.listSources();
      if (mounted) _pick(list);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _pick(ScreenSources list) async {
    final media = MediaQuery.of(context);
    final phoneW = (media.size.longestSide * media.devicePixelRatio).round();
    final phoneH = (media.size.shortestSide * media.devicePixelRatio).round();
    final hasSecond = list.monitors.length > 1;

    final picked = await showModalBottomSheet<VoidCallback>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DeckColors.surface,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(t('Hiện gì trên điện thoại?'),
                  style: TextStyle(
                      color: DeckColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            _header(t('Màn hình')),
            for (final m in list.monitors)
              ListTile(
                leading: Icon(
                    m.virtual
                        ? Icons.cast_connected_rounded
                        : Icons.desktop_windows_rounded,
                    color: m.primary ? DeckColors.muted : DeckColors.accent),
                title: Text(_monitorLabel(m),
                    style: TextStyle(color: DeckColors.text)),
                subtitle: Text(
                    [
                      if (m.primary) t('màn hình chính'),
                      if (m.virtual) t('màn hình ảo — kéo cửa sổ sang đây'),
                      if (!m.primary && !m.virtual) m.name,
                    ].join(' · '),
                    style: TextStyle(color: DeckColors.muted, fontSize: 12)),
                onTap: () => Navigator.pop(
                    ctx,
                    () => _use(_monitorSource(m), _monitorLabel(m),
                        remember: 'm:${m.id}')),
              ),
            if (!hasSecond)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                    t('Muốn điện thoại thành màn hình mở rộng thật (kéo cửa sổ sang)? Trên cửa sổ HeDeck ở máy tính, bấm "Thêm màn hình ảo", rồi trong cài đặt màn hình của Windows chọn "Extend" và độ phân giải gần với điện thoại này: {0}×{1}.',
                        [phoneW, phoneH]),
                    style: TextStyle(
                        color: DeckColors.muted, fontSize: 12, height: 1.45)),
              ),
            _header(t('Cửa sổ')),
            if (list.windows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(t('Không có cửa sổ nào đang mở'),
                    style: TextStyle(color: DeckColors.muted, fontSize: 12)),
              ),
            for (final w in list.windows)
              ListTile(
                dense: true,
                leading: Icon(Icons.web_asset_rounded, color: DeckColors.muted),
                title: Text(w.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DeckColors.text)),
                subtitle: Text(w.exe,
                    style: TextStyle(color: DeckColors.muted, fontSize: 12)),
                onTap: () => Navigator.pop(
                    ctx,
                    () => _use({'window': w.id}, w.title,
                        remember: 'w:${w.exe}')),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (picked != null) {
      picked();
    } else if (_source == null && mounted) {
      // Đóng bảng chọn mà chưa có gì để xem thì quay về deck.
      Navigator.of(context).maybePop();
    }
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                color: DeckColors.muted,
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600)),
      );

  // ------------------------------------------------------------- cử chỉ

  /// Điểm chạm → vị trí theo tỉ lệ 0..1 trong nguồn. Null nếu chạm ra ngoài
  /// hình (vùng đen hai bên).
  Offset? _toSource(Offset p) {
    final f = _shown;
    if (f == null || _pic.isEmpty || !_pic.contains(p)) return null;
    final sx = f.cropX + (p.dx - _pic.left) / _pic.width * f.cropW;
    final sy = f.cropY + (p.dy - _pic.top) / _pic.height * f.cropH;
    return Offset(sx / f.screenW, sy / f.screenH);
  }

  void _send(Offset at, String action, {int dy = 0}) {
    final src = _source;
    final p = _toSource(at);
    if (src == null || p == null) return;
    _conn.pointer(src, p.dx, p.dy, action, dy: dy);
  }

  void _down(PointerDownEvent e) {
    _wake();
    _points[e.pointer] = e.localPosition;
    if (_points.length == 1) {
      _multi = false;
      _start = e.localPosition;
      _downAt = DateTime.now();
      _travel = 0;
      _held = _dragging = _scrolling = false;
      _scrollRest = 0;
      _holdTimer?.cancel();
      _holdTimer = Timer(_holdTime, () {
        if (_travel < _slop && _points.length == 1) {
          _held = true;
          HapticFeedback.mediumImpact();
        }
      });
    } else if (_points.length == 2) {
      _multi = true;
      _holdTimer?.cancel();
      // Đang kéo thả mà đặt thêm ngón: nhả chuột cho khỏi kẹt.
      if (_dragging) {
        _send(_start, 'up');
        _dragging = false;
      }
      final pts = _points.values.toList();
      _pinchStart = (pts[0] - pts[1]).distance;
      _zoomAtPinch = _zoom;
    }
  }

  void _move(PointerMoveEvent e) {
    final prev = _points[e.pointer];
    if (prev == null) return;
    _points[e.pointer] = e.localPosition;

    if (_points.length >= 2) {
      final pts = _points.values.toList();
      final d = (pts[0] - pts[1]).distance;
      if (_pinchStart > 0) {
        final z = (_zoomAtPinch * d / _pinchStart).clamp(1.0, 4.0);
        setState(() => _zoom = (z * 10).round() / 10);
      }
      return;
    }

    if (_multi) return;
    final delta = e.localPosition - prev;
    _travel += delta.distance;
    if (_held) {
      // Giữ yên rồi kéo: kéo thả (giữ chuột trái).
      if (!_dragging) {
        _dragging = true;
        _send(_start, 'down');
      }
      _send(e.localPosition, 'move');
      return;
    }
    if (_travel < _slop) return;
    _holdTimer?.cancel();
    // Kéo một ngón: cuộn, như vuốt trên màn hình cảm ứng. Ngón đi xuống thì
    // nội dung đi xuống (cuộn lên).
    _scrolling = true;
    _scrollRest += delta.dy;
    final notches = (_scrollRest / _scrollStep).truncate();
    if (notches != 0) {
      _scrollRest -= notches * _scrollStep;
      _send(_start, 'scroll', dy: notches);
    }
  }

  void _up(PointerEvent e) {
    _points.remove(e.pointer);
    if (_points.isNotEmpty) return;
    _holdTimer?.cancel();
    if (_multi) {
      // Vừa chụm hai ngón: không tính là chạm hay nhấp.
    } else if (_dragging) {
      _send(e.localPosition, 'up');
    } else if (_held && _travel < _slop) {
      _send(_start, 'right');
    } else if (!_scrolling &&
        _travel < _slop &&
        DateTime.now().difference(_downAt) < _tapTime) {
      HapticFeedback.selectionClick();
      _send(_start, 'click');
    }
    _held = _dragging = _scrolling = false;
  }

  // ------------------------------------------------------------- nút nổi

  void _wake() {
    if (!_controlsBright) setState(() => _controlsBright = true);
    _dimTimer?.cancel();
    _dimTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsBright = false);
    });
  }

  Future<void> _menu() async {
    _wake();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DeckColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_sourceLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(_sourceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DeckColors.muted, fontSize: 12)),
            ),
          ListTile(
            leading: Icon(Icons.swap_horiz_rounded, color: DeckColors.text),
            title: Text(t('Đổi màn hình / cửa sổ'),
                style: TextStyle(color: DeckColors.text)),
            onTap: () => Navigator.pop(ctx, 'pick'),
          ),
          if (_zoom > 1)
            ListTile(
              leading: Icon(Icons.zoom_out_map_rounded, color: DeckColors.text),
              title: Text(t('Bỏ phóng to'),
                  style: TextStyle(color: DeckColors.text)),
              onTap: () => Navigator.pop(ctx, 'unzoom'),
            ),
          ListTile(
            leading: Icon(Icons.touch_app_rounded, color: DeckColors.text),
            title: Text(t('Cách điều khiển'),
                style: TextStyle(color: DeckColors.text)),
            onTap: () => Navigator.pop(ctx, 'hint'),
          ),
          ListTile(
            leading: Icon(Icons.grid_view_rounded, color: DeckColors.text),
            title: Text(t('Về deck'), style: TextStyle(color: DeckColors.text)),
            onTap: () => Navigator.pop(ctx, 'back'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'pick':
        _openPicker();
      case 'unzoom':
        setState(() => _zoom = 1);
      case 'hint':
        _showHint();
      case 'back':
        Navigator.of(context).maybePop();
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------------------------------------------------------- vẽ

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: _body(),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _hint && _source != null ? 1 : 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                        t(
                            'Chạm: nhấp · Kéo: cuộn · Giữ rồi thả: chuột phải · Giữ rồi kéo: kéo thả · Chụm: phóng to'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, height: 1.4)),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 10,
          child: SafeArea(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _controlsBright ? 0.95 : 0.35,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _menu,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cast_rounded,
                          size: 16, color: Colors.white),
                      if (_controlsBright && _sourceLabel.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(_sourceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                      ],
                      if (_zoom > 1) ...[
                        const SizedBox(width: 6),
                        Text('${_zoom.toStringAsFixed(1)}×',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _body() {
    if (!_supported) {
      return _message(Icons.system_update_alt_rounded,
          t('Cập nhật HeDeck trên máy tính để dùng màn hình phụ'));
    }
    if (!_conn.isOnline) {
      return _message(Icons.wifi_off_rounded, t('Chưa kết nối máy tính'));
    }
    if (_source == null) return const SizedBox.shrink();
    return ValueListenableBuilder<ScreenFrame?>(
      valueListenable: _conn.screen,
      builder: (context, frame, _) {
        final jpeg = frame?.jpeg;
        if (frame == null || jpeg == null || frame.screenW <= 0) {
          return const Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return LayoutBuilder(builder: (context, box) {
          final cw = frame.cropW.toDouble(), ch = frame.cropH.toDouble();
          final scale = math.min(box.maxWidth / cw, box.maxHeight / ch);
          final w = cw * scale, h = ch * scale;
          final left = (box.maxWidth - w) / 2, top = (box.maxHeight - h) / 2;
          _pic = Rect.fromLTWH(left, top, w, h);
          _shown = frame;
          final hot = PcCursor.hotspot(frame.cursorKind);
          final px = left + (frame.cursorX - frame.cropX) * scale;
          final py = top + (frame.cursorY - frame.cropY) * scale;
          final showCursor = frame.cursorX >= 0 &&
              frame.cursorKind != 0 &&
              _pic.contains(Offset(px, py));
          return Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(
              left: left,
              top: top,
              width: w,
              height: h,
              child: Image.memory(jpeg,
                  gaplessPlayback: true,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium),
            ),
            if (showCursor)
              Positioned(
                left: px - hot.dx,
                top: py - hot.dy,
                child: IgnorePointer(child: PcCursor(kind: frame.cursorKind)),
              ),
          ]);
        });
      },
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white54, size: 32),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
      );
}
