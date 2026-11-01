import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/deck_connection.dart';
import '../services/store.dart';
import '../theme.dart';

/// Touchpad và bàn phím ảo, điều khiển chuột/phím của thiết bị từ xa.
///
/// Cử chỉ giống touchpad của Windows:
/// - một ngón kéo: di chuột
/// - một ngón chạm: chuột trái
/// - hai ngón chạm: chuột phải; ba ngón chạm: chuột giữa
/// - hai ngón kéo: cuộn (dọc và ngang)
/// - giữ yên một ngón ~0,45 giây rồi kéo: kéo thả (giữ chuột trái)
///
/// Phía sau vùng touchpad là hình màn hình máy tính (bật/tắt ở thanh trên),
/// để điều khiển được cả khi không ngồi trước máy — kể cả ở xa qua Tailscale.
class TouchpadScreen extends StatefulWidget {
  const TouchpadScreen({super.key});

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  // --------------------------------------------------------------- cử chỉ

  final Map<int, Offset> _points = {};
  int _maxPoints = 0;
  DateTime _downAt = DateTime.now();
  double _travel = 0;
  Timer? _holdTimer;
  bool _dragging = false;

  /// Phần lẻ của chuyển động chưa đủ một pixel, cộng dồn cho lần sau.
  double _restX = 0, _restY = 0;

  /// Chuyển động đã tính nhưng chưa gửi: gom lại gửi mỗi khung hình (~60
  /// lần/giây) thay vì mỗi sự kiện chạm (có máy tới 120–240 lần/giây).
  int _pendingX = 0, _pendingY = 0;
  Timer? _flushTimer;

  double _scrollY = 0, _scrollX = 0;

  static const _tapTime = Duration(milliseconds: 230);
  static const _tapSlop = 12.0;
  static const _holdTime = Duration(milliseconds: 450);

  /// Kéo hai ngón bao nhiêu pixel thì cuộn một nấc.
  static const _scrollStep = 22.0;

  /// Giữ sẵn từ initState: dispose() không được phép tra context nữa, mà
  /// lúc thoát màn hình giữa chừng kéo thả vẫn phải nhả chuột trái.
  late final DeckConnection _conn;

  void _onDown(PointerDownEvent e) {
    _points[e.pointer] = e.position;
    if (_points.length == 1) {
      _downAt = DateTime.now();
      _travel = 0;
      _maxPoints = 1;
      _scrollX = _scrollY = 0;
      _holdTimer?.cancel();
      _holdTimer = Timer(_holdTime, () {
        if (_points.length == 1 && _travel < _tapSlop && !_dragging) {
          HapticFeedback.mediumImpact();
          _conn.mouseButton('left', 'down');
          setState(() => _dragging = true);
        }
      });
    } else {
      _holdTimer?.cancel();
    }
    _maxPoints = math.max(_maxPoints, _points.length);
  }

  void _onMove(PointerMoveEvent e) {
    final prev = _points[e.pointer];
    if (prev == null) return;
    final d = e.position - prev;
    _points[e.pointer] = e.position;
    _travel += d.distance;
    if (_travel > _tapSlop) _holdTimer?.cancel();

    if (_points.length == 1) {
      _queueMove(d);
    } else if (_points.length == 2) {
      // Mỗi ngón góp một nửa, hai ngón cùng kéo thì đúng bằng quãng kéo.
      _scrollY += d.dy / 2;
      _scrollX += d.dx / 2;
      final stepsY = (_scrollY / _scrollStep).truncate();
      final stepsX = (_scrollX / _scrollStep).truncate();
      if (stepsY != 0 || stepsX != 0) {
        _scrollY -= stepsY * _scrollStep;
        _scrollX -= stepsX * _scrollStep;
        // Cuộn tự nhiên như touchpad Windows: nội dung chạy theo ngón tay.
        // Ngón đi lên (dy âm) là cuộn xuống (con lăn âm).
        _conn.mouseScroll(dy: stepsY, dx: -stepsX);
      }
    }
  }

  void _onUp(PointerEvent e) {
    _points.remove(e.pointer);
    if (_points.isNotEmpty) return;
    _holdTimer?.cancel();
    _flush();

    if (_dragging) {
      _conn.mouseButton('left', 'up');
      setState(() => _dragging = false);
      return;
    }
    final quick = DateTime.now().difference(_downAt) < _tapTime;
    if (quick && _travel < _tapSlop * _maxPoints) {
      HapticFeedback.selectionClick();
      _conn.mouseButton(switch (_maxPoints) {
        1 => 'left',
        2 => 'right',
        _ => 'middle',
      });
    }
  }

  /// Gia tốc kiểu chuột thật: vuốt chậm thì chính xác từng pixel, vuốt nhanh
  /// thì con trỏ đi xa — một màn hình điện thoại vẫn quét hết màn hình lớn.
  void _queueMove(Offset d) {
    final speed = context.read<Store>().mouseSpeed;
    final gain = speed * (1 + math.min(d.distance, 40) * 0.05);
    _restX += d.dx * gain;
    _restY += d.dy * gain;
    final ix = _restX.truncate(), iy = _restY.truncate();
    _restX -= ix;
    _restY -= iy;
    if (ix == 0 && iy == 0) return;
    _pendingX += ix;
    _pendingY += iy;
    _flushTimer ??= Timer(const Duration(milliseconds: 16), _flush);
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingX == 0 && _pendingY == 0) return;
    _conn.mouseMove(_pendingX, _pendingY);
    _pendingX = _pendingY = 0;
  }

  // ------------------------------------------------------------ bàn phím

  /// Ký tự canh gác vô hình ở đầu ô nhập. Ô trống thì Android không báo phím
  /// xoá; có ký tự này, xoá nó nghĩa là người dùng vừa bấm xoá.
  static const _guard = '​';

  final _text = TextEditingController(text: _guard);
  final _focus = FocusNode();
  bool _keyboard = false;
  bool _resetting = false;

  /// Phần đã gõ sang thiết bị, để so và chỉ gửi phần chênh lệch.
  String _sent = '';

  @override
  void initState() {
    super.initState();
    _conn = context.read<DeckConnection>();
    _text.addListener(_onText);
    _conn.screen.addListener(_onFrame);
    WidgetsBinding.instance.addPostFrameCallback((_) => _askFrame());
  }

  // ------------------------------------------------------- màn hình máy tính

  /// Đang hiện hình màn hình máy tính sau touchpad. Nhớ trong phiên chạy app.
  static bool _showScreen = true;
  Timer? _frameTimer;
  Timer? _stallTimer;
  DateTime _askedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Tối đa ~10 khung mỗi giây; mạng chậm thì tự thưa hơn vì nhận xong khung
  /// này mới xin khung sau. Màn hình đứng yên thì hỏi thưa lại (~4 lần mỗi
  /// giây, đủ để chấm con trỏ vẫn theo kịp), đỡ cho máy tính phải chụp liên tục.
  static const _minGap = Duration(milliseconds: 100);
  static const _idleGap = Duration(milliseconds: 250);
  Uint8List? _lastJpeg;

  bool get _screenSupported =>
      _conn.agentVersion >= DeckConnection.screenAgentVersion;

  String _level() {
    final chosen = context.read<Store>().screenLevel;
    if (chosen.isNotEmpty) return chosen;
    return _conn.viaRemote ? 'low' : 'mid';
  }

  void _askFrame() {
    _frameTimer?.cancel();
    if (!mounted || !_showScreen || !_conn.isOnline || !_screenSupported) {
      return;
    }
    _askedAt = DateTime.now();
    _conn.requestScreen(_level());
    // Khung bị lạc (mất mạng chốc lát) thì xin lại, đừng đứng hình mãi.
    _stallTimer?.cancel();
    _stallTimer = Timer(const Duration(seconds: 4), _askFrame);
  }

  void _onFrame() {
    final frame = _conn.screen.value;
    if (frame == null) return;
    _stallTimer?.cancel();
    final idle = identical(frame.jpeg, _lastJpeg);
    _lastJpeg = frame.jpeg;
    final wait =
        (idle ? _idleGap : _minGap) - DateTime.now().difference(_askedAt);
    _frameTimer?.cancel();
    _frameTimer = Timer(wait.isNegative ? Duration.zero : wait, _askFrame);
  }

  void _toggleScreen() {
    setState(() => _showScreen = !_showScreen);
    if (_showScreen) {
      _askFrame();
    } else {
      _frameTimer?.cancel();
      _stallTimer?.cancel();
      _conn.stopScreen();
    }
  }

  Future<void> _qualityMenu() async {
    final store = context.read<Store>();
    final options = {
      '': t('Tự động (vừa ở nhà, tiết kiệm khi ở xa)'),
      'low': t('Tiết kiệm dữ liệu'),
      'mid': t('Vừa'),
      'high': t('Nét'),
    };
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DeckColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in options.entries)
            ListTile(
              leading: Icon(
                  store.screenLevel == e.key
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: DeckColors.accent,
                  size: 20),
              title: Text(e.value,
                  style: TextStyle(color: DeckColors.text, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ]),
      ),
    );
    if (picked != null) await store.setScreenLevel(picked);
  }

  @override
  void dispose() {
    _conn.screen.removeListener(_onFrame);
    _frameTimer?.cancel();
    _stallTimer?.cancel();
    if (_showScreen) _conn.stopScreen();
    _holdTimer?.cancel();
    _flushTimer?.cancel();
    if (_dragging) _conn.mouseButton('left', 'up');
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _resetField() {
    _resetting = true;
    _sent = '';
    _text.value = const TextEditingValue(
      text: _guard,
      selection: TextSelection.collapsed(offset: 1),
    );
    _resetting = false;
  }

  /// Gõ trực tiếp: so nội dung ô nhập với phần đã gửi, gửi chữ mới thêm
  /// hoặc số lần xoá. Bộ gõ tiếng Việt (Telex, VNI) đang ghép chữ thì chờ
  /// ghép xong mới gửi, nên "tieengs" sang máy tính thành đúng "tiếng".
  void _onText() {
    if (_resetting) return;
    final v = _text.value;
    if (v.composing.isValid && !v.composing.isCollapsed) return;

    var t = v.text;
    if (!t.startsWith(_guard)) {
      // Ký tự canh gác bị xoá: người dùng bấm xoá khi ô đã trống.
      _conn.key('backspace');
      _resetField();
      return;
    }
    t = t.substring(1);

    var same = 0;
    while (same < t.length && same < _sent.length && t[same] == _sent[same]) {
      same++;
    }
    for (var i = same; i < _sent.length; i++) {
      _conn.key('backspace');
    }
    final added = t.substring(same);
    if (added.isNotEmpty) _conn.typeText(added);
    _sent = t;

    // Ô nhập chỉ là chỗ đệm, không cần giữ dài. Dọn sau mỗi khoảng trắng
    // cho nhẹ, lúc đó bộ gõ cũng đã ghép xong chữ.
    if (_sent.length > 60 && added.endsWith(' ')) _resetField();
  }

  void _toggleKeyboard() {
    setState(() => _keyboard = !_keyboard);
    if (_keyboard) {
      _resetField();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focus.requestFocus());
    } else {
      _focus.unfocus();
    }
  }

  // ---------------------------------------------------------------- giao diện

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<DeckConnection>();
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        title: const Text('Touchpad', style: TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: _showScreen ? t('Ẩn màn hình máy tính') : t('Hiện màn hình máy tính'),
            icon: Icon(_showScreen
                ? Icons.desktop_windows_rounded
                : Icons.desktop_access_disabled_rounded),
            color: _showScreen ? DeckColors.accent : null,
            onPressed: _toggleScreen,
          ),
          if (_showScreen)
            IconButton(
              tooltip: t('Chất lượng hình'),
              icon: const Icon(Icons.high_quality_rounded),
              onPressed: _qualityMenu,
            ),
          IconButton(
            tooltip: t('Tốc độ con trỏ'),
            icon: const Icon(Icons.speed_rounded),
            onPressed: _speedDialog,
          ),
          IconButton(
            tooltip: _keyboard ? t('Ẩn bàn phím') : t('Bàn phím'),
            icon: Icon(_keyboard
                ? Icons.keyboard_hide_rounded
                : Icons.keyboard_rounded),
            color: _keyboard ? DeckColors.accent : null,
            onPressed: _toggleKeyboard,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              if (_keyboard) ...[_keyboardBar(), const SizedBox(height: 8)],
              Expanded(child: _pad(conn)),
              const SizedBox(height: 8),
              _buttons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pad(DeckConnection conn) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: Container(
        decoration: BoxDecoration(
          color: DeckColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _dragging ? DeckColors.accent : DeckColors.line,
            width: _dragging ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        child: _showScreen && conn.isOnline && _screenSupported
            ? _screenView()
            : Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _showScreen && conn.isOnline && !_screenSupported
                ? t('Cập nhật HeDeck trên máy tính để xem màn hình tại đây.')
                : !conn.isOnline
                ? t('Chưa kết nối tới thiết bị')
                : _dragging
                    ? t('Đang giữ chuột trái — kéo rồi thả tay')
                    : t('Một ngón: di chuột · chạm để nhấp\nHai ngón: cuộn · chạm để nhấp phải\nGiữ yên một ngón rồi kéo: kéo thả'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: conn.isOnline ? DeckColors.muted : DeckColors.warn,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ),
      ),
    );
  }

  /// Hình màn hình máy tính, giữ đúng tỉ lệ, có chấm đánh dấu con trỏ.
  /// Chỉ khung hình này dựng lại mỗi lần có ảnh mới.
  Widget _screenView() {
    return ValueListenableBuilder<ScreenFrame?>(
      valueListenable: _conn.screen,
      builder: (context, frame, _) {
        final jpeg = frame?.jpeg;
        if (frame == null || jpeg == null || frame.screenW <= 0) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(height: 10),
              Text(t('Đang tải màn hình máy tính…'),
                  style: TextStyle(color: DeckColors.muted, fontSize: 12)),
            ]),
          );
        }
        return LayoutBuilder(builder: (context, box) {
          final sw = frame.screenW.toDouble(), sh = frame.screenH.toDouble();
          final scale = math.min(box.maxWidth / sw, box.maxHeight / sh);
          final w = sw * scale, h = sh * scale;
          final left = (box.maxWidth - w) / 2, top = (box.maxHeight - h) / 2;
          return Stack(children: [
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
            if (frame.cursorX >= 0 && frame.cursorY >= 0)
              Positioned(
                left: left + frame.cursorX * scale - 7,
                top: top + frame.cursorY * scale - 7,
                child: IgnorePointer(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DeckColors.accent.withValues(alpha: 0.35),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 3)
                      ],
                    ),
                  ),
                ),
              ),
            if (_dragging)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t('Đang giữ chuột trái — kéo rồi thả tay'),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
          ]);
        });
      },
    );
  }

  Widget _buttons() {
    Widget btn(String label, String button, {int flex = 2}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: DeckColors.tile,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _conn.mouseButton(button);
                },
                onDoubleTap: button == 'left'
                    ? () => _conn.mouseButton('left', 'double')
                    : null,
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(label,
                        style: TextStyle(
                            color: DeckColors.text, fontSize: 13)),
                  ),
                ),
              ),
            ),
          ),
        );
    return Row(children: [
      btn(t('Trái'), 'left', flex: 3),
      btn(t('Giữa'), 'middle'),
      btn(t('Phải'), 'right', flex: 3),
    ]);
  }

  static const _keys = <(String, String)>[
    ('Esc', 'esc'),
    ('Tab', 'tab'),
    ('⌫', 'backspace'),
    ('Enter', 'enter'),
    ('←', 'left'),
    ('↑', 'up'),
    ('↓', 'down'),
    ('→', 'right'),
    ('Del', 'delete'),
    ('Home', 'home'),
    ('End', 'end'),
    ('Ctrl+C', 'ctrl+c'),
    ('Ctrl+V', 'ctrl+v'),
    ('Ctrl+Z', 'ctrl+z'),
    ('Ctrl+A', 'ctrl+a'),
    ('Alt+Tab', 'alt+tab'),
    ('Win+D', 'win+d'),
    ('Start', 'ctrl+esc'),
    ('F5', 'f5'),
    ('F11', 'f11'),
  ];

  Widget _keyboardBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          focusNode: _focus,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(color: DeckColors.text),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) {
            _conn.key('enter');
            _resetField();
            _focus.requestFocus();
          },
          decoration: InputDecoration(
            hintText: t('Gõ ở đây, chữ hiện thẳng trên thiết bị'),
            prefixIcon:
                Icon(Icons.keyboard_rounded, size: 18, color: DeckColors.muted),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _keys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final (label, combo) = _keys[i];
              return ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                backgroundColor: DeckColors.tile,
                side: BorderSide(color: DeckColors.line, width: 0.8),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _conn.key(combo);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _speedDialog() async {
    final store = context.read<Store>();
    var value = store.mouseSpeed;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: DeckColors.surface,
          title: Text(t('Tốc độ con trỏ'),
              style: TextStyle(color: DeckColors.text, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: value,
                min: 0.5,
                max: 3,
                divisions: 10,
                label: value.toStringAsFixed(2),
                onChanged: (v) => setDialog(() => value = v),
              ),
              Text(t('Màn hình thiết bị càng lớn thì nên để càng nhanh.'),
                  style: TextStyle(color: DeckColors.muted, fontSize: 11)),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                store.setMouseSpeed(value);
                Navigator.pop(ctx);
              },
              child: const Text('Xong'),
            ),
          ],
        ),
      ),
    );
  }
}
