import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../services/deck_connection.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/icon_library.dart';

/// Trả về DeckTile mới, hoặc DeckTile.empty nếu người dùng xoá ô.
class TileEditScreen extends StatefulWidget {
  final DeckTile tile;
  const TileEditScreen({super.key, required this.tile});

  @override
  State<TileEditScreen> createState() => _TileEditScreenState();
}

class _TileEditScreenState extends State<TileEditScreen> {
  late TileKind _kind;
  String? _appId;
  String _volumeAction = 'up';
  bool _isToggle = false;

  /// Mặt đang sửa: 0 là mặt chính, 1 là mặt phụ.
  int _editingFace = 0;

  late List<TextEditingController> _label;
  late List<TextEditingController> _macro;
  late List<String> _icon;
  late List<int> _accent;
  late List<String> _media;

  String _search = '';

  static const _macroPresets = <String, (String, String)>{
    'Chuyển cửa sổ': ('alt+tab', 'swap'),
    'Hiện desktop': ('win+d', 'desktop'),
    'Khoá máy': ('win+l', 'lock'),
    'Chụp màn hình': ('win+shift+s', 'image'),
    'Bảng lệnh VS Code': ('ctrl+shift+p', 'code'),
    'Đóng cửa sổ': ('alt+f4', 'close'),
    'Lưu': ('ctrl+s', 'save'),
    'Hoàn tác': ('ctrl+z', 'undo'),
  };

  @override
  void initState() {
    super.initState();
    final t = widget.tile;
    _kind = t.kind == TileKind.empty ? TileKind.app : t.kind;
    _appId = t.appId;
    _volumeAction = t.volumeAction ?? 'up';
    _isToggle = t.isToggle;

    _label = [
      TextEditingController(text: t.front.label),
      TextEditingController(text: t.back.label),
    ];
    _macro = [
      TextEditingController(text: t.front.keys.join(', ')),
      TextEditingController(text: t.back.keys.join(', ')),
    ];
    _icon = [t.front.icon, t.back.icon];
    _accent = [t.front.accent, t.back.accent];
    _media = [t.front.mediaAction ?? 'playpause', t.back.mediaAction ?? 'mute'];
  }

  @override
  void dispose() {
    for (final c in [..._label, ..._macro]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _keysOf(int face) => _macro[face]
      .text
      .split(RegExp(r'[,\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  TileFace _buildFace(int i) => TileFace(
        label: _label[i].text.trim(),
        icon: _icon[i],
        accent: _accent[i],
        keys: _kind == TileKind.macro ? _keysOf(i) : const [],
        mediaAction: _kind == TileKind.media ? _media[i] : null,
      );

  void _save() {
    if ((_kind == TileKind.app || _kind == TileKind.appVolume) &&
        _appId == null) {
      _toast('Chọn một ứng dụng trước đã');
      return;
    }
    if (_kind == TileKind.macro && _keysOf(0).isEmpty) {
      _toast('Nhập ít nhất một tổ hợp phím cho mặt chính');
      return;
    }
    if (_isToggle && _kind == TileKind.macro && _keysOf(1).isEmpty) {
      _toast('Ô hai trạng thái cần tổ hợp phím cho cả mặt phụ');
      return;
    }

    Navigator.pop(
      context,
      DeckTile(
        kind: _kind,
        appId: (_kind == TileKind.app || _kind == TileKind.appVolume)
            ? _appId
            : null,
        volumeAction: _kind == TileKind.appVolume ? _volumeAction : null,
        front: _buildFace(0),
        back: _isToggle ? _buildFace(1) : const TileFace(),
        isToggle: _isToggle,
      ),
    );
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: DeckColors.tile),
      );

  /// Ô hai trạng thái chỉ có nghĩa với macro và media — bấm để bật, bấm lại
  /// để tắt. Ô mở ứng dụng vốn đã tự đổi trạng thái theo cửa sổ thật.
  bool get _canToggle =>
      _kind == TileKind.macro || _kind == TileKind.media;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        title: const Text('Sửa ô', style: TextStyle(fontSize: 17)),
        actions: [
          if (!widget.tile.isEmpty)
            IconButton(
              tooltip: 'Xoá ô',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => Navigator.pop(context, DeckTile.empty),
            ),
          TextButton(onPressed: _save, child: const Text('Lưu')),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            _kindPicker(),
            const SizedBox(height: 16),
            if (_canToggle) _togglePicker(),
            if (_isToggle && _canToggle) ...[
              const SizedBox(height: 14),
              _facePicker(),
            ],
            const SizedBox(height: 16),
            if (_kind == TileKind.app || _kind == TileKind.appVolume)
              _appPicker(),
            if (_kind == TileKind.appVolume) ...[
              const SizedBox(height: 16),
              _volumePicker(),
            ],
            if (_kind == TileKind.macro) _macroEditor(),
            if (_kind == TileKind.media) _mediaPicker(),
            const SizedBox(height: 18),
            TextField(
              controller: _label[_editingFace],
              style: const TextStyle(color: DeckColors.text),
              decoration: InputDecoration(
                labelText: _isToggle && _canToggle
                    ? 'Tên hiển thị · ${_editingFace == 0 ? "mặt chính" : "mặt phụ"}'
                    : 'Tên hiển thị',
                hintText: 'Để trống thì chỉ hiện icon',
              ),
            ),
            const SizedBox(height: 18),
            _iconPicker(),
            const SizedBox(height: 18),
            _colorPicker(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ loại ô

  Widget _kindPicker() {
    Widget chip(TileKind kind, String label, IconData icon) {
      final on = _kind == kind;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _kind = kind;
            if (!_canToggle) _isToggle = false;
            _editingFace = 0;
          }),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? DeckColors.tile : DeckColors.tileDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? DeckColors.accent : DeckColors.line,
                width: on ? 1.6 : 0.8,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 19, color: on ? DeckColors.accent : DeckColors.muted),
                const SizedBox(height: 5),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: on ? DeckColors.text : DeckColors.muted,
                        fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(TileKind.app, 'Ứng dụng', Icons.desktop_windows_rounded),
        chip(TileKind.macro, 'Macro', Icons.keyboard_rounded),
        chip(TileKind.media, 'Media', Icons.music_note_rounded),
        chip(TileKind.appVolume, 'Âm lượng', Icons.volume_up_rounded),
      ],
    );
  }

  // --------------------------------------------------------- hai trạng thái

  Widget _togglePicker() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DeckColors.line, width: 0.8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ô hai trạng thái',
                    style: TextStyle(color: DeckColors.text, fontSize: 14)),
                SizedBox(height: 2),
                Text('Bấm để bật, bấm lại để tắt. Mỗi mặt có icon và màu riêng.',
                    style: TextStyle(color: DeckColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: _isToggle,
            activeColor: DeckColors.accent,
            onChanged: (v) => setState(() {
              _isToggle = v;
              if (!v) _editingFace = 0;
            }),
          ),
        ],
      ),
    );
  }

  Widget _facePicker() {
    Widget tab(int index, String label) {
      final on = _editingFace == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _editingFace = index),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? DeckColors.tile : DeckColors.tileDim,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: on ? DeckColors.swatch(_accent[index]) : DeckColors.line,
                width: on ? 1.6 : 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(IconLibrary.lookup(_icon[index]) ?? Icons.circle_outlined,
                    size: 16, color: DeckColors.swatch(_accent[index])),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                        color: on ? DeckColors.text : DeckColors.muted,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [tab(0, 'Mặt chính'), tab(1, 'Mặt phụ')]);
  }

  // ----------------------------------------------------------- chọn ứng dụng

  Widget _appPicker() {
    final conn = context.watch<DeckConnection>();
    final q = _search.toLowerCase();
    final apps = conn.catalog
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: DeckColors.text),
                decoration: const InputDecoration(
                  hintText: 'Tìm ứng dụng trên laptop',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: DeckColors.muted),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Quét lại Start Menu',
              icon: const Icon(Icons.refresh_rounded, color: DeckColors.muted),
              onPressed: conn.isOnline ? conn.rescan : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!conn.isOnline)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Chưa kết nối tới laptop nên không lấy được danh sách.',
                style: TextStyle(color: DeckColors.muted, fontSize: 13)),
          )
        else if (conn.catalogLoading && conn.catalog.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: DeckColors.muted),
                ),
                SizedBox(width: 10),
                Text('Đang lấy danh sách từ laptop…',
                    style: TextStyle(color: DeckColors.muted, fontSize: 13)),
              ],
            ),
          )
        else if (conn.catalog.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Laptop chưa gửi được danh sách ứng dụng. Bấm nút làm mới bên '
              'phải, hoặc xem cửa sổ agent có báo lỗi không.',
              style:
                  TextStyle(color: DeckColors.muted, fontSize: 13, height: 1.4),
            ),
          )
        else if (apps.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Không có ứng dụng nào khớp.',
                style: TextStyle(color: DeckColors.muted, fontSize: 13)),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: DeckColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DeckColors.line, width: 0.8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: apps.length,
              itemBuilder: (_, i) {
                final app = apps[i];
                final on = app.id == _appId;
                return ListTile(
                  dense: true,
                  leading: app.icon != null
                      ? AppIcon(
                          bytes: app.icon!,
                          size: 26,
                          nativePixels: app.iconNative,
                        )
                      : const Icon(Icons.apps_rounded,
                          size: 22, color: DeckColors.muted),
                  title: Text(app.name,
                      style: TextStyle(
                          color: on ? DeckColors.accent : DeckColors.text,
                          fontSize: 14)),
                  subtitle: Text(app.exe,
                      style: const TextStyle(
                          color: DeckColors.muted, fontSize: 11)),
                  trailing: on
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: DeckColors.accent)
                      : null,
                  onTap: () => setState(() => _appId = app.id),
                );
              },
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------- âm lượng riêng

  Widget _volumePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ô này làm gì với âm lượng của app đó',
            style: TextStyle(color: DeckColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: appVolumeLabels.entries.map((e) {
            final on = _volumeAction == e.key;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _volumeAction = e.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: on ? DeckColors.tile : DeckColors.tileDim,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: on ? DeckColors.accent : DeckColors.line,
                      width: on ? 1.6 : 0.8,
                    ),
                  ),
                  child: Text(
                    switch (e.key) {
                      'up' => 'Tăng 5%',
                      'down' => 'Giảm 5%',
                      _ => 'Tắt tiếng',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: on ? DeckColors.text : DeckColors.muted,
                        fontSize: 12),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ macro

  Widget _macroEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _macro[_editingFace],
          maxLines: 2,
          style: const TextStyle(color: DeckColors.text),
          decoration: InputDecoration(
            labelText: _isToggle
                ? 'Tổ hợp phím · ${_editingFace == 0 ? "mặt chính" : "mặt phụ"}'
                : 'Tổ hợp phím',
            hintText: 'ctrl+shift+p',
            helperText: 'Nhiều bước thì ngăn bằng dấu phẩy',
            helperStyle:
                const TextStyle(color: DeckColors.muted, fontSize: 11),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _macroPresets.entries
              .map(
                (e) => GestureDetector(
                  onTap: () => setState(() {
                    _macro[_editingFace].text = e.value.$1;
                    if (_label[_editingFace].text.isEmpty) {
                      _label[_editingFace].text = e.key;
                    }
                    if (_icon[_editingFace].isEmpty) {
                      _icon[_editingFace] = e.value.$2;
                    }
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: DeckColors.tile,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: DeckColors.line, width: 0.8),
                    ),
                    child: Text(e.key,
                        style: const TextStyle(
                            color: DeckColors.text, fontSize: 12)),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ media

  Widget _mediaPicker() {
    return Column(
      children: mediaLabels.entries.map((e) {
        final on = _media[_editingFace] == e.key;
        return InkWell(
          onTap: () => setState(() => _media[_editingFace] = e.key),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  on
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: on ? DeckColors.accent : DeckColors.muted,
                ),
                const SizedBox(width: 12),
                Text(e.value,
                    style: TextStyle(
                      color: on ? DeckColors.text : DeckColors.muted,
                      fontSize: 14,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ------------------------------------------------------------- chọn icon

  Widget _iconPicker() {
    final chosen = _icon[_editingFace];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Icon',
                  style: TextStyle(color: DeckColors.muted, fontSize: 12)),
            ),
            if (chosen.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _icon[_editingFace] = ''),
                child: const Text('Dùng icon mặc định',
                    style: TextStyle(color: DeckColors.accent, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openIconSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: DeckColors.tile,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DeckColors.line, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(
                  IconLibrary.lookup(chosen) ?? Icons.image_search_rounded,
                  size: 26,
                  color: chosen.isEmpty
                      ? DeckColors.muted
                      : DeckColors.swatch(_accent[_editingFace]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    chosen.isEmpty
                        ? 'Chọn từ ${IconLibrary.count} icon'
                        : chosen,
                    style: TextStyle(
                      color: chosen.isEmpty ? DeckColors.muted : DeckColors.text,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: DeckColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openIconSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DeckColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _IconSheet(current: _icon[_editingFace]),
    );
    if (picked != null && mounted) {
      setState(() => _icon[_editingFace] = picked);
    }
  }

  // -------------------------------------------------------------- chọn màu

  Widget _colorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Màu nhấn',
            style: TextStyle(color: DeckColors.muted, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(
            DeckColors.swatches.length,
            (i) => GestureDetector(
              onTap: () => setState(() => _accent[_editingFace] = i),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: DeckColors.swatch(i),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accent[_editingFace] == i
                        ? DeckColors.text
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bảng chọn icon, có ô tìm và chia theo nhóm.
class _IconSheet extends StatefulWidget {
  final String current;
  const _IconSheet({required this.current});

  @override
  State<_IconSheet> createState() => _IconSheetState();
}

class _IconSheetState extends State<_IconSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final results = searching ? IconLibrary.search(_query) : const [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: DeckColors.text),
              decoration: const InputDecoration(
                hintText: 'Tìm icon: micro, ghi hình, khoá…',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: DeckColors.muted),
              ),
            ),
          ),
          Expanded(
            child: searching
                ? _grid(results.cast<(String, String)>(), controller)
                : ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    children: [
                      for (final group in IconLibrary.groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 12, 0, 8),
                          child: Text(group.key,
                              style: const TextStyle(
                                  color: DeckColors.muted, fontSize: 12)),
                        ),
                        _wrap(group.value),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<(String, String)> items, ScrollController controller) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy icon nào',
            style: TextStyle(color: DeckColors.muted, fontSize: 13)),
      );
    }
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [_wrap(items)],
    );
  }

  Widget _wrap(List<(String, String)> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((e) {
        final on = e.$1 == widget.current;
        return GestureDetector(
          onTap: () => Navigator.pop(context, e.$1),
          child: Tooltip(
            message: e.$2,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: DeckColors.tile,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: on ? DeckColors.accent : DeckColors.line,
                  width: on ? 1.8 : 0.8,
                ),
              ),
              child: Icon(IconLibrary.lookup(e.$1),
                  size: 26,
                  color: on ? DeckColors.accent : DeckColors.text),
            ),
          ),
        );
      }).toList(),
    );
  }
}
