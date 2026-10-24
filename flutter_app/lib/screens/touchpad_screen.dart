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
  }

  @override
  void dispose() {
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            !conn.isOnline
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
                        style: const TextStyle(
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
          style: const TextStyle(color: DeckColors.text),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) {
            _conn.key('enter');
            _resetField();
            _focus.requestFocus();
          },
          decoration: InputDecoration(
            hintText: t('Gõ ở đây, chữ hiện thẳng trên thiết bị'),
            prefixIcon:
                const Icon(Icons.keyboard_rounded, size: 18, color: DeckColors.muted),
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
                side: const BorderSide(color: DeckColors.line, width: 0.8),
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
              style: const TextStyle(color: DeckColors.text, fontSize: 17)),
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
                  style: const TextStyle(color: DeckColors.muted, fontSize: 11)),
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
