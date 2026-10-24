import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
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

  /// Các bước của ô chế độ.
  late List<SceneStep> _steps;

  /// Mặt đang sửa: 0 là mặt chính, 1 là mặt phụ.
  int _editingFace = 0;

  late List<TextEditingController> _label;
  late List<TextEditingController> _macro;
  late List<String> _icon;
  late List<int> _accent;
  late List<String> _media;

  String _search = '';

  // Getter chứ không phải hằng: tên phải theo ngôn ngữ đang chọn.
  static Map<String, (String, String)> get _macroPresets => {
    t('Chuyển cửa sổ'): ('alt+tab', 'swap'),
    t('Hiện desktop'): ('win+d', 'desktop'),
    t('Khoá máy'): ('win+l', 'lock'),
    t('Chụp màn hình'): ('win+shift+s', 'image'),
    t('Bảng lệnh VS Code'): ('ctrl+shift+p', 'code'),
    t('Đóng cửa sổ'): ('alt+f4', 'close'),
    t('Lưu'): ('ctrl+s', 'save'),
    t('Hoàn tác'): ('ctrl+z', 'undo'),
  };

  @override
  void initState() {
    super.initState();
    final t = widget.tile;
    _kind = t.kind == TileKind.empty ? TileKind.app : t.kind;
    _appId = t.appId;
    _volumeAction = t.volumeAction ?? 'up';
    _isToggle = t.isToggle;
    _steps = List.of(t.steps);

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
      _toast(t('Chọn một ứng dụng trước đã'));
      return;
    }
    if (_kind == TileKind.macro && _keysOf(0).isEmpty) {
      _toast(t('Nhập ít nhất một tổ hợp phím cho mặt chính'));
      return;
    }
    if (_kind == TileKind.scene && _steps.isEmpty) {
      _toast(t('Thêm ít nhất một ứng dụng cho chế độ này'));
      return;
    }
    if (_isToggle && _kind == TileKind.macro && _keysOf(1).isEmpty) {
      _toast(t('Ô hai trạng thái cần tổ hợp phím cho cả mặt phụ'));
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
        steps: _kind == TileKind.scene ? _steps : const [],
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
        title: Text(t('Sửa ô'), style: const TextStyle(fontSize: 17)),
        actions: [
          if (!widget.tile.isEmpty)
            IconButton(
              tooltip: t('Xoá ô'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => Navigator.pop(context, DeckTile.empty),
            ),
          TextButton(onPressed: _save, child: Text(t('Lưu'))),
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
            if (_kind == TileKind.scene) _sceneEditor(),
            if (_kind == TileKind.media) _mediaPicker(),
            const SizedBox(height: 18),
            TextField(
              controller: _label[_editingFace],
              style: const TextStyle(color: DeckColors.text),
              decoration: InputDecoration(
                labelText: _isToggle && _canToggle
                    ? t('Tên hiển thị · {0}', [_editingFace == 0 ? t('mặt chính') : t('mặt phụ')])
                    : t('Tên hiển thị'),
                hintText: t('Để trống thì chỉ hiện icon'),
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
        chip(TileKind.app, t('Ứng dụng'), Icons.desktop_windows_rounded),
        chip(TileKind.macro, 'Macro', Icons.keyboard_rounded),
        chip(TileKind.media, 'Media', Icons.music_note_rounded),
        chip(TileKind.appVolume, t('Âm lượng'), Icons.volume_up_rounded),
        chip(TileKind.scene, t('Chế độ'), Icons.auto_awesome_rounded),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Ô hai trạng thái'),
                    style: const TextStyle(color: DeckColors.text, fontSize: 14)),
                const SizedBox(height: 2),
                Text(t('Bấm để bật, bấm lại để tắt. Mỗi mặt có icon và màu riêng.'),
                    style: const TextStyle(color: DeckColors.muted, fontSize: 11)),
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

    return Row(children: [tab(0, t('Mặt chính')), tab(1, t('Mặt phụ'))]);
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
                decoration: InputDecoration(
                  hintText: t('Tìm ứng dụng trên thiết bị'),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: DeckColors.muted),
                ),
              ),
            ),
            IconButton(
              tooltip: t('Quét lại Start Menu'),
              icon: const Icon(Icons.refresh_rounded, color: DeckColors.muted),
              onPressed: conn.isOnline ? conn.rescan : null,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: conn.isOnline
                ? () async {
                    final id = await _pickRunning();
                    if (id != null && mounted) setState(() => _appId = id);
                  }
                : null,
            icon: const Icon(Icons.web_asset_rounded, size: 18),
            label: Text(t('Chọn từ cửa sổ đang mở trên PC')),
          ),
        ),
        const SizedBox(height: 10),
        if (!conn.isOnline)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(t('Chưa kết nối tới thiết bị nên không lấy được danh sách.'),
                style: const TextStyle(color: DeckColors.muted, fontSize: 13)),
          )
        else if (conn.catalogLoading && conn.catalog.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: DeckColors.muted),
                ),
                const SizedBox(width: 10),
                Text(t('Đang lấy danh sách từ thiết bị…'),
                    style: const TextStyle(color: DeckColors.muted, fontSize: 13)),
              ],
            ),
          )
        else if (conn.catalog.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              t('Thiết bị chưa gửi được danh sách ứng dụng. Bấm nút làm mới bên phải, hoặc xem cửa sổ agent có báo lỗi không.'),
              style:
                  const TextStyle(color: DeckColors.muted, fontSize: 13, height: 1.4),
            ),
          )
        else if (apps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(t('Không có ứng dụng nào khớp.'),
                style: const TextStyle(color: DeckColors.muted, fontSize: 13)),
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
        Text(t('Ô này làm gì với âm lượng của app đó'),
            style: const TextStyle(color: DeckColors.muted, fontSize: 12)),
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
                      'up' => t('Tăng 5%'),
                      'down' => t('Giảm 5%'),
                      _ => t('Tắt tiếng'),
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
                ? t('Tổ hợp phím · {0}', [_editingFace == 0 ? t('mặt chính') : t('mặt phụ')])
                : t('Tổ hợp phím'),
            hintText: 'ctrl+shift+p',
            helperText: t('Nhiều bước thì ngăn bằng dấu phẩy'),
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

  // --------------------------------------------------------------- chế độ

  Widget _sceneEditor() {
    final conn = context.watch<DeckConnection>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('Bấm ô là chạy lần lượt từ trên xuống. "Mở" bỏ qua app đã chạy sẵn, "Đóng" tắt hẳn app.'),
          style: const TextStyle(color: DeckColors.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _steps.length; i++) _stepRow(conn, i),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addStep(fromRunning: false),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(t('Thêm ứng dụng')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: conn.isOnline
                    ? () => _addStep(fromRunning: true)
                    : null,
                icon: const Icon(Icons.web_asset_rounded, size: 18),
                label: Text(t('Từ cửa sổ đang mở')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepRow(DeckConnection conn, int i) {
    final step = _steps[i];
    final app = conn.catalogById[step.appId];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DeckColors.line, width: 0.8),
      ),
      child: Row(
        children: [
          Text('${i + 1}',
              style: const TextStyle(color: DeckColors.muted, fontSize: 12)),
          const SizedBox(width: 10),
          if (app?.icon != null)
            AppIcon(bytes: app!.icon!, size: 22, nativePixels: app.iconNative)
          else
            const Icon(Icons.apps_rounded, size: 20, color: DeckColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              app?.name ?? t('App không còn trên thiết bị'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: app == null ? DeckColors.danger : DeckColors.text,
                  fontSize: 13),
            ),
          ),
          // Mở / Đóng: chạm để đổi.
          GestureDetector(
            onTap: () => setState(() =>
                _steps[i] = SceneStep(step.appId, close: !step.close)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (step.close ? DeckColors.danger : DeckColors.live)
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(step.close ? t('Đóng') : t('Mở'),
                  style: TextStyle(
                      color: step.close ? DeckColors.danger : DeckColors.live,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            tooltip: t('Bỏ bước này'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline_rounded,
                size: 18, color: DeckColors.muted),
            onPressed: () => setState(() => _steps.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Future<void> _addStep({required bool fromRunning}) async {
    final id = fromRunning ? await _pickRunning() : await _pickCatalogApp();
    if (id == null || !mounted) return;
    setState(() => _steps.add(SceneStep(id)));
  }

  /// Chọn một app trong danh sách đã quét. Trả về app_id.
  Future<String?> _pickCatalogApp() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: DeckColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const CatalogPickerSheet(),
    );
  }

  /// Chọn một chương trình đang mở trên thiết bị. Chưa có trong danh sách thì
  /// nhờ agent thêm vào trước. Trả về app_id.
  Future<String?> _pickRunning() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: DeckColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const RunningPickerSheet(),
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
                child: Text(t('Dùng icon mặc định'),
                    style: const TextStyle(color: DeckColors.accent, fontSize: 12)),
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
                        ? t('Chọn từ {0} icon', [IconLibrary.count])
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
        Text(t('Màu nhấn'),
            style: const TextStyle(color: DeckColors.muted, fontSize: 12)),
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

/// Danh sách chương trình đang có cửa sổ trên thiết bị, giống thanh taskbar.
class RunningPickerSheet extends StatefulWidget {
  const RunningPickerSheet({super.key});

  @override
  State<RunningPickerSheet> createState() => _RunningSheetState();
}

class _RunningSheetState extends State<RunningPickerSheet> {
  late Future<List<RunningProgram>> _list;
  String? _adopting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _list = context.read<DeckConnection>().listRunning();
  }

  Future<void> _choose(RunningProgram p) async {
    if (p.appId != null) {
      Navigator.pop(context, p.appId);
      return;
    }
    setState(() {
      _adopting = p.token;
      _error = null;
    });
    try {
      final id = await context.read<DeckConnection>().adopt(p.token);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adopting = null;
        _error = e.toString().replaceFirst(RegExp(r'^\w+Error: '), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(t('Đang mở trên PC'),
                style: const TextStyle(
                    color: DeckColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              t('Mở app trên PC trước rồi chọn ở đây. App chưa có trong danh sách sẽ được thêm và giữ lại cả khi quét lại.'),
              style:
                  const TextStyle(color: DeckColors.muted, fontSize: 11, height: 1.4),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(_error!,
                  style:
                      const TextStyle(color: DeckColors.danger, fontSize: 12)),
            ),
          Expanded(
            child: FutureBuilder<List<RunningProgram>>(
              future: _list,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(t('Không lấy được danh sách: {0}', [snap.error]),
                        style: const TextStyle(
                            color: DeckColors.muted, fontSize: 13)),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: DeckColors.muted),
                  );
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Text(t('Không thấy cửa sổ nào đang mở'),
                        style:
                            const TextStyle(color: DeckColors.muted, fontSize: 13)),
                  );
                }
                return ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final p = items[i];
                    final busy = _adopting == p.token;
                    return ListTile(
                      enabled: _adopting == null,
                      leading: p.icon != null
                          ? AppIcon(
                              bytes: p.icon!,
                              size: 28,
                              nativePixels: p.iconNative)
                          : const Icon(Icons.web_asset_rounded,
                              size: 24, color: DeckColors.muted),
                      title: Text(p.name,
                          style: const TextStyle(
                              color: DeckColors.text, fontSize: 14)),
                      subtitle: Text(
                        p.windows > 1
                            ? t('{0} cửa sổ · {1}', [p.windows, p.exe])
                            : (p.title.isEmpty ? p.exe : p.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: DeckColors.muted, fontSize: 11),
                      ),
                      trailing: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: DeckColors.muted))
                          : (p.appId != null
                              ? Text(t('Đã có'),
                                  style: const TextStyle(
                                      color: DeckColors.live, fontSize: 11))
                              : const Icon(Icons.add_rounded,
                                  size: 20, color: DeckColors.accent)),
                      onTap: () => _choose(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Chọn nhanh một app trong danh sách đã quét, có ô tìm.
class CatalogPickerSheet extends StatefulWidget {
  const CatalogPickerSheet({super.key});

  @override
  State<CatalogPickerSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends State<CatalogPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<DeckConnection>();
    final q = _q.toLowerCase();
    final apps = conn.catalog
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(color: DeckColors.text),
              decoration: InputDecoration(
                hintText: t('Tìm ứng dụng trên thiết bị'),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: DeckColors.muted),
              ),
            ),
          ),
          Expanded(
            child: apps.isEmpty
                ? Center(
                    child: Text(t('Không có ứng dụng nào'),
                        style:
                            const TextStyle(color: DeckColors.muted, fontSize: 13)))
                : ListView.builder(
                    controller: controller,
                    itemCount: apps.length,
                    itemBuilder: (_, i) {
                      final app = apps[i];
                      return ListTile(
                        dense: true,
                        leading: app.icon != null
                            ? AppIcon(
                                bytes: app.icon!,
                                size: 26,
                                nativePixels: app.iconNative)
                            : const Icon(Icons.apps_rounded,
                                size: 22, color: DeckColors.muted),
                        title: Text(app.name,
                            style: const TextStyle(
                                color: DeckColors.text, fontSize: 14)),
                        onTap: () => Navigator.pop(context, app.id),
                      );
                    },
                  ),
          ),
        ],
      ),
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
              decoration: InputDecoration(
                hintText: t('Tìm icon: micro, ghi hình, khoá…'),
                prefixIcon: const Icon(Icons.search_rounded,
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
                          child: Text(t(group.key),
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
      return Center(
        child: Text(t('Không tìm thấy icon nào'),
            style: const TextStyle(color: DeckColors.muted, fontSize: 13)),
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
            message: t(e.$2),
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
