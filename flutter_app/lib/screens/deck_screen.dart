import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/deck.dart';
import '../services/deck_connection.dart';
import '../services/store.dart';
import '../services/wake_on_lan.dart';
import '../theme.dart';
import '../widgets/clown_logo.dart';
import '../widgets/deck_tile_view.dart';
import '../widgets/lang_picker.dart';
import '../widgets/theme_switch.dart';
import '../widgets/update_dialog.dart';
import '../widgets/media_bar.dart';
import 'tile_edit_screen.dart';
import 'perf_screen.dart';
import 'touchpad_screen.dart';

class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> with WidgetsBindingObserver {
  final _pager = PageController();
  Timer? _tick;

  /// App đang ở trước lần trước, để chỉ đổi trang khi nó THAY ĐỔI. Nhờ vậy
  /// người dùng tự vuốt sang trang khác thì deck để yên, không giành lại.
  String _lastForeground = '';
  late final DeckConnection _connRef;

  /// Các lần thử kết nối lại sau khi gửi tín hiệu bật máy.
  final List<Timer> _wakeTimers = [];
  int _page = 0;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    _connRef = context.read<DeckConnection>()..addListener(_followForeground);
    // Nhịp mỗi giây chỉ để vẽ lại đồng hồ đếm ngược lúc đang thử lại.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !context.read<DeckConnection>().isOnline) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connRef.removeListener(_followForeground);
    _tick?.cancel();
    for (final t in _wakeTimers) {
      t.cancel();
    }
    _pager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quay lại từ nền: thử ngay thay vì chờ hết chu kỳ lùi.
    if (state == AppLifecycleState.resumed) {
      context.read<DeckConnection>().reconnectNow();
    }
  }

  /// Tự đổi trang theo app đang dùng, như profile của Stream Deck: vào Liên
  /// Minh thì nhảy sang trang Game, về desktop thì về trang Làm việc.
  void _followForeground() {
    final conn = _connRef;
    if (!mounted || !conn.isOnline) return;
    final key = conn.foregroundDesktop
        ? 'desktop'
        : (conn.foregroundApps.isEmpty
            ? ''
            : (List.of(conn.foregroundApps)..sort()).join(','));
    // App lạ không gắn trang nào: đứng yên, nhưng vẫn ghi nhận để lần sau
    // quay lại app cũ thì đổi trang được.
    if (key == _lastForeground) return;
    _lastForeground = key;

    final store = context.read<Store>();
    if (!store.autoSwitch || _editing || key.isEmpty) return;
    final target =
        store.pageForForeground(conn.foregroundApps, conn.foregroundDesktop);
    if (target < 0 || target == _page || target >= store.pages.length) return;
    // Đang mở màn hình khác (sửa ô, touchpad) thì không chuyển, kẻo người
    // dùng quay về thấy trang lạ mà không hiểu vì sao.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _pager.animateToPage(target,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  /// Gom các app có ô âm lượng trên mọi trang, báo cho agent theo dõi.
  void _syncVolumeWatch() {
    final store = context.read<Store>();
    final conn = context.read<DeckConnection>();
    if (!conn.isOnline) return;
    final ids = <String>{};
    for (final page in store.pages) {
      for (final tile in page.tiles) {
        if (tile.kind == TileKind.appVolume && tile.appId != null) {
          ids.add(tile.appId!);
        }
      }
    }
    conn.watchVolume(ids);
  }

  Future<void> _connect() async {
    final store = context.read<Store>();
    final conn = context.read<DeckConnection>();
    if (!store.isPaired ||
        conn.isOnline ||
        conn.state == ConnState.needsPairing) {
      return;
    }

    // Thiết bị đổi IP thì tự dò lại và lưu địa chỉ mới, khỏi ghép cặp lại.
    conn.onHostChanged = store.updateHost;

    await conn.start(
      host: store.host,
      port: store.port,
      deviceId: store.deviceId,
    );
    if (mounted) _syncVolumeWatch();
  }

  /// Xoá ghép cặp. Gốc app theo dõi `store.isPaired` nên sẽ tự chuyển sang
  /// màn hình ghép cặp — không cần tự đẩy màn hình ở đây.
  Future<void> _repair() async {
    final store = context.read<Store>();
    final conn = context.read<DeckConnection>();
    await conn.stop();
    await store.forgetHost();
  }

  // ------------------------------------------------------------ hành động ô

  Future<void> _fire(int pageIndex, int slot, DeckTile tile) async {
    final conn = context.read<DeckConnection>();
    final store = context.read<Store>();
    if (!conn.isOnline) {
      _snack(t('Chưa kết nối tới thiết bị'));
      return;
    }
    HapticFeedback.mediumImpact();

    // Ô hai trạng thái: mặt đang hiện quyết định hành động, bấm xong thì lật.
    final flipped = store.isFlipped(pageIndex, slot);
    final face = tile.face(flipped);

    switch (tile.kind) {
      case TileKind.app:
        if (tile.appId != null) conn.launch(tile.appId!);
        break;
      case TileKind.macro:
        if (face.keys.isNotEmpty) conn.macro(face.keys);
        break;
      case TileKind.media:
        if (face.mediaAction != null) conn.media(face.mediaAction!);
        break;
      case TileKind.appVolume:
        if (tile.appId != null && tile.volumeAction != null) {
          conn.appVolume(tile.appId!, tile.volumeAction!);
        }
        break;
      case TileKind.scene:
        if (tile.steps.isEmpty) return;
        conn.scene(tile.steps);
        final label = tile.front.label;
        _snack(label.isEmpty ? t('Đang chạy chế độ…') : t('Đang chạy "{0}"…', [label]));
        break;
      case TileKind.empty:
        return;
    }

    if (tile.isToggle) await store.toggleFlip(pageIndex, slot);
  }

  void _forceClose(DeckTile tile) {
    final conn = context.read<DeckConnection>();
    if (!conn.isOnline || tile.appId == null) return;
    conn.close(tile.appId!);
    final name = conn.catalogById[tile.appId]?.name ?? t('Ứng dụng');
    _snack(t('Đã tắt {0}', [name]));
  }

  /// Danh sách đầy đủ các cửa sổ của một app, như khi rê chuột lên biểu
  /// tượng trên taskbar. Tự cập nhật: đóng cửa sổ nào là dòng đó biến mất và
  /// các số phía sau dồn lên, khớp với hàng số trên ô.
  Future<void> _windowSheet(DeckTile tile) async {
    final appId = tile.appId;
    if (appId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DeckColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8),
          child: Consumer<DeckConnection>(
            builder: (_, conn, __) {
              final name = conn.catalogById[appId]?.name ?? t('Ứng dụng');
              final status = conn.statusOf(appId);
              final wins = status.wins;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      t('{0} · {1} cửa sổ', [name, status.windows]),
                      style: TextStyle(
                          color: DeckColors.muted, fontSize: 12),
                    ),
                  ),
                  if (wins.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: Text(
                        status.running
                            ? t('Chỉ còn một cửa sổ — chạm vào ô để mở nó.')
                            : t('Ứng dụng đã đóng hết.'),
                        style: TextStyle(
                            color: DeckColors.text, fontSize: 13),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: wins.length,
                        itemBuilder: (_, i) {
                          final w = wins[i];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    w.active ? DeckColors.live : DeckColors.bg,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: DeckColors.live),
                              ),
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      color: w.active
                                          ? DeckColors.bg
                                          : DeckColors.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                            title: Text(
                              w.title.isEmpty ? t('(không có tiêu đề)') : w.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: DeckColors.text, fontSize: 13),
                            ),
                            subtitle: w.active
                                ? Text(t('Đang ở trước'),
                                    style: TextStyle(
                                        color: DeckColors.live, fontSize: 11))
                                : null,
                            trailing: IconButton(
                              tooltip: t('Đóng cửa sổ này'),
                              icon: Icon(Icons.close_rounded,
                                  size: 20, color: DeckColors.danger),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                conn.closeWindow(appId, w.hwnd);
                              },
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              conn.focusWindow(appId, w.hwnd);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _edit(int pageIndex, int slot, DeckTile tile) async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context).push<DeckTile>(
      MaterialPageRoute(builder: (_) => TileEditScreen(tile: tile)),
    );
    if (result == null || !mounted) return;
    await context.read<Store>().setTile(pageIndex, slot, result);
    if (mounted) _syncVolumeWatch();
  }

  /// Nút cộng ở thanh dưới: tìm chỗ trống gần nhất, hết chỗ thì tự tạo trang mới.
  Future<void> _addTile() async {
    final store = context.read<Store>();
    final wasLast = store.pages.length;
    final (pageIndex, slot) = await store.nextFreeSlot(_page);

    if (pageIndex != _page) {
      if (store.pages.length > wasLast) HapticFeedback.selectionClick();
      await _pager.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      setState(() => _page = pageIndex);
    }
    await _edit(pageIndex, slot, DeckTile.empty);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: DeckColors.tile,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

  // ---------------------------------------------------------- nguồn máy tính

  /// Bảng nguồn: máy đang tắt thì bật, đang chạy thì khoá/ngủ/tắt.
  Future<void> _powerSheet() async {
    final store = context.read<Store>();
    final conn = context.read<DeckConnection>();
    final online = conn.isOnline;
    final warnings = online ? (conn.wol?.warnings ?? const []) : const [];

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DeckColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  t('Nguồn · {0}', [store.hostName.isEmpty ? t('máy tính') : store.hostName]),
                  style: TextStyle(color: DeckColors.muted, fontSize: 12),
                ),
              ),
              if (!online) ...[
                ListTile(
                  enabled: store.canWake,
                  leading: Icon(Icons.power_settings_new_rounded,
                      size: 22,
                      color:
                          store.canWake ? DeckColors.live : DeckColors.muted),
                  title: Text(t('Bật máy'),
                      style: TextStyle(color: DeckColors.text, fontSize: 14)),
                  subtitle: Text(
                    store.canWake
                        ? t('Wake-on-LAN tới {0}', [store.wolMacs.first])
                        : t('Chưa biết địa chỉ MAC. Kết nối một lần lúc máy đang bật, hoặc nhập tay bên dưới.'),
                    style:
                        TextStyle(color: DeckColors.muted, fontSize: 11),
                  ),
                  onTap: () => Navigator.pop(context, 'wake'),
                ),
              ] else ...[
                _sheetItem(Icons.lock_rounded, t('Khoá máy'), 'lock'),
                _sheetItem(Icons.bedtime_rounded, t('Ngủ'), 'sleep'),
                _sheetItem(
                    Icons.restart_alt_rounded, t('Khởi động lại'), 'restart'),
                _sheetItem(
                    Icons.power_settings_new_rounded, t('Tắt máy'), 'shutdown'),
              ],
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: DeckColors.warn),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(w,
                            style: TextStyle(
                                color: DeckColors.warn,
                                fontSize: 11,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
              Divider(height: 17, color: DeckColors.line),
              _sheetItem(Icons.settings_ethernet_rounded,
                  t('Địa chỉ MAC để bật máy'), 'mac'),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'wake':
        await _wake();
        break;
      case 'mac':
        await _askMac();
        break;
      case 'lock':
      case 'sleep':
        conn.power(choice);
        _snack(choice == 'lock' ? t('Đã khoá máy') : t('Máy đang đi ngủ…'));
        break;
      case 'restart':
      case 'shutdown':
        final force = await _confirmPower(choice);
        if (force == null || !mounted) return;
        conn.power(choice, force: force);
        _snack(choice == 'restart' ? t('Đang khởi động lại…') : t('Đang tắt máy…'));
        break;
    }
  }

  Future<void> _wake() async {
    final store = context.read<Store>();
    final conn = context.read<DeckConnection>();
    if (!store.canWake) {
      _snack(t('Chưa có địa chỉ MAC của máy tính'));
      return;
    }
    HapticFeedback.mediumImpact();
    try {
      final sent =
          await sendWakeOnLan(store.wolMacs, broadcast: store.wolBroadcast);
      if (sent == 0) {
        _snack(t('Không gửi được — điện thoại có đang nối Wi-Fi nhà không?'));
        return;
      }
    } catch (e) {
      _snack(t('Gửi tín hiệu bật máy lỗi: {0}', [e]));
      return;
    }
    _snack(t('Đã gửi tín hiệu bật máy. Windows cần khoảng 20–60 giây để lên.'));

    // Đừng để vòng thử lại đang lùi tới 20 giây làm chậm thêm: chủ động gõ
    // cửa vài lần quanh lúc Windows thường khởi động xong.
    for (final t in _wakeTimers) {
      t.cancel();
    }
    _wakeTimers
      ..clear()
      ..addAll([20, 35, 50, 75].map((s) => Timer(Duration(seconds: s), () {
            if (mounted) conn.reconnectNow();
          })));
  }

  /// Hỏi lại trước khi tắt hoặc khởi động lại. Trả về null nếu huỷ, còn lại
  /// là có buộc đóng app chưa lưu hay không.
  Future<bool?> _confirmPower(String action) {
    final restart = action == 'restart';
    var force = false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: DeckColors.surface,
          title: Text(restart ? t('Khởi động lại máy?') : t('Tắt máy?'),
              style: TextStyle(color: DeckColors.text, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restart
                    ? t('Máy sẽ khởi động lại ngay.')
                    : t('Máy sẽ tắt hẳn. Bật lại bằng nút nguồn trên HeDeck nếu đã cài Wake-on-LAN.'),
                style: TextStyle(
                    color: DeckColors.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: force,
                activeColor: DeckColors.danger,
                onChanged: (v) => setDialog(() => force = v ?? false),
                title: Text(t('Buộc đóng app chưa lưu'),
                    style: TextStyle(color: DeckColors.text, fontSize: 13)),
                subtitle: Text(
                    t('Không chọn thì Windows có thể dừng lại hỏi lưu file.'),
                    style: TextStyle(color: DeckColors.muted, fontSize: 11)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(t('Huỷ'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: DeckColors.danger),
              onPressed: () => Navigator.pop(ctx, force),
              child: Text(restart ? t('Khởi động lại') : t('Tắt máy')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askMac() async {
    final store = context.read<Store>();
    final ctl = TextEditingController(
        text: store.wolMacs.isEmpty ? '' : store.wolMacs.first);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeckColors.surface,
        title: Text(t('Địa chỉ MAC'),
            style: TextStyle(color: DeckColors.text, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctl,
              autofocus: true,
              style: TextStyle(color: DeckColors.text),
              decoration: const InputDecoration(hintText: 'AA:BB:CC:DD:EE:FF'),
            ),
            const SizedBox(height: 10),
            Text(
              t('Agent tự gửi MAC mỗi lần kết nối. Chỉ cần nhập tay nếu cửa sổ agent báo không đọc được. Xem bằng lệnh: getmac /v'),
              style:
                  TextStyle(color: DeckColors.muted, fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t('Huỷ'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: Text(t('Lưu'))),
        ],
      ),
    );
    if (text == null || !mounted) return;
    final mac = normalizeMac(text);
    if (mac == null) {
      _snack(t('MAC không hợp lệ — cần 12 chữ số hex'));
      return;
    }
    await store.setManualMac(mac);
    _snack(t('Đã lưu MAC {0}', [mac]));
  }

  // ---------------------------------------------------------------- menu

  Future<void> _menu() async {
    final store = context.read<Store>();
    final conn = context.read<DeckConnection>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DeckColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _layoutRow(store),
                Divider(height: 1, color: DeckColors.line),
                // Đóng bảng trước rồi mới đổi: đổi ngôn ngữ dựng lại cả màn
                // hình chính, bảng còn mở thì trỏ vào màn hình đã bỏ.
                LangPicker(
                  current: store.lang,
                  onPick: (l) => Navigator.pop(context, 'lang:${l.name}'),
                ),
                // Nút trượt tự chạy hết hoạt ảnh rồi mới báo; lúc đó mới
                // đóng bảng và đổi chủ đề, lý do giống đổi ngôn ngữ.
                ListTile(
                  leading: Icon(
                      store.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 20,
                      color: DeckColors.muted),
                  title: Text(t('Giao diện'),
                      style: TextStyle(color: DeckColors.text, fontSize: 14)),
                  subtitle: Text(
                      store.dark ? t('Tối · mặt trăng') : t('Sáng · mặt trời'),
                      style: TextStyle(color: DeckColors.muted, fontSize: 11)),
                  trailing: ThemeSwitch(
                    dark: store.dark,
                    onChanged: (d) =>
                        Navigator.pop(context, d ? 'theme:dark' : 'theme:light'),
                  ),
                ),
                Divider(height: 1, color: DeckColors.line),
                _autoSwitchRow(store),
                _sheetItem(Icons.bolt_rounded, t('Tự mở trang này khi…'), 'auto'),
                Divider(height: 1, color: DeckColors.line),
                _sheetItem(Icons.refresh_rounded,
                    t('Quét lại ứng dụng trên thiết bị'), 'rescan'),
                _sheetItem(Icons.add_rounded, t('Thêm trang'), 'addPage'),
                _sheetItem(Icons.drive_file_rename_outline_rounded,
                    t('Đổi tên trang này'), 'rename'),
                if (store.pages.length > 1)
                  _sheetItem(
                      Icons.delete_outline_rounded, t('Xoá trang này'), 'delPage'),
                _sheetItem(
                    Icons.link_off_rounded, t('Quên thiết bị này'), 'forget'),
                Divider(height: 1, color: DeckColors.line),
                _sheetItem(Icons.system_update_rounded,
                    t('Kiểm tra cập nhật'), 'update'),
                _aboutBlock(),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice.startsWith('theme:')) {
      await store.setDark(choice == 'theme:dark');
      return; // màn hình này vừa được dựng lại, không dùng context nữa
    }
    if (choice.startsWith('lang:')) {
      await store.setLang(AppLang.fromCode(choice.substring(5)));
      return; // màn hình này vừa được dựng lại, không dùng context nữa
    }

    switch (choice) {
      case 'auto':
        await _autoPageSheet(_page);
        break;
      case 'rescan':
        conn.rescan();
        _snack(t('Đang quét lại Start Menu…'));
        break;
      case 'addPage':
        await store.addPage();
        break;
      case 'rename':
        final name = await _askName(store.pages[_page].name);
        if (name != null && name.trim().isNotEmpty) {
          await store.renamePage(_page, name.trim());
        }
        break;
      case 'delPage':
        await store.removePage(_page);
        if (!mounted) return;
        setState(() => _page = 0);
        _pager.jumpToPage(0);
        break;
      case 'update':
        await showUpdateDialog(context);
        break;
      case 'forget':
        await conn.stop();
        await store.forgetHost();
        break;
    }
  }

  Widget _autoSwitchRow(Store store) {
    return StatefulBuilder(
      builder: (context, setSheetState) => SwitchListTile(
        secondary: Icon(Icons.auto_mode_rounded,
            size: 20, color: DeckColors.muted),
        title: Text(t('Tự đổi trang theo app đang dùng'),
            style: TextStyle(color: DeckColors.text, fontSize: 14)),
        subtitle: Text(t('Như Stream Deck: vào game là sang trang Game'),
            style: TextStyle(color: DeckColors.muted, fontSize: 11)),
        value: store.autoSwitch,
        onChanged: (v) async {
          await store.setAutoSwitch(v);
          setSheetState(() {});
        },
      ),
    );
  }

  /// Chọn app (và/hoặc màn hình desktop) làm trang tự mở.
  Future<void> _autoPageSheet(int pageIndex) async {
    final store = context.read<Store>();
    final page = store.pages[pageIndex];
    final apps = List<String>.of(page.autoApps);
    var desktop = page.autoDesktop;

    final save = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: DeckColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final conn = sheetContext.watch<DeckConnection>();

          Future<void> add(bool running) async {
            final id = await showModalBottomSheet<String>(
              context: sheetContext,
              backgroundColor: DeckColors.surface,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => running
                  ? const RunningPickerSheet()
                  : const CatalogPickerSheet(),
            );
            if (id != null && !apps.contains(id)) setSheet(() => apps.add(id));
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.85),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t('Tự mở trang "{0}" khi…', [page.name]),
                        style: TextStyle(
                            color: DeckColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      t('Deck chỉ đổi trang lúc bạn chuyển sang app khác trên thiết bị. Tự vuốt sang trang khác thì nó để yên.'),
                      style: TextStyle(
                          color: DeckColors.muted, fontSize: 11, height: 1.4),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('…đang ở màn hình desktop'),
                          style:
                              TextStyle(color: DeckColors.text, fontSize: 14)),
                      subtitle: Text(
                          t('Thu nhỏ hết cửa sổ hoặc Win+D. Chỉ một trang được chọn mục này.'),
                          style:
                              TextStyle(color: DeckColors.muted, fontSize: 11)),
                      value: desktop,
                      onChanged: (v) => setSheet(() => desktop = v),
                    ),
                    const SizedBox(height: 4),
                    Text(t('…đang dùng một trong các app:'),
                        style:
                            TextStyle(color: DeckColors.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    if (apps.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(t('Chưa chọn app nào'),
                            style: TextStyle(
                                color: DeckColors.muted, fontSize: 13)),
                      ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final id in apps)
                          InputChip(
                            label: Text(
                                conn.catalogById[id]?.name ??
                                    t('App không còn trên thiết bị'),
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: DeckColors.tile,
                            onDeleted: () => setSheet(() => apps.remove(id)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                conn.catalog.isEmpty ? null : () => add(false),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(t('Thêm app')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: conn.isOnline ? () => add(true) : null,
                            icon: const Icon(Icons.web_asset_rounded, size: 18),
                            label: Text(t('Đang mở')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: Text(t('Lưu')),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (save != true || !mounted) return;
    await store.setPageAuto(pageIndex, apps, desktop);
    _snack(apps.isEmpty && !desktop
        ? t('Trang này không tự mở nữa')
        : t('Đã lưu — deck sẽ tự mở trang này'));
  }

  /// Chọn bố cục ngay trong bảng menu, không cần đóng ra mở lại.
  Widget _layoutRow(Store store) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        Widget option(int rows, String label) {
          final on = store.rows == rows;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                await store.setRows(rows);
                setSheetState(() {});
                if (mounted) setState(() {});
              },
              child: Container(
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
                child: Column(
                  children: [
                    Text(label,
                        style: TextStyle(
                          color: on ? DeckColors.text : DeckColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 2),
                    Text(t('{0} ô mỗi trang', [rows * Store.cols]),
                        style: TextStyle(
                            color: DeckColors.muted, fontSize: 11)),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Bố cục lưới'),
                  style: TextStyle(color: DeckColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [option(2, t('5 × 2')), option(3, t('5 × 3'))]),
            ],
          ),
        );
      },
    );
  }

  Widget _aboutBlock() {
    final store = context.read<Store>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Row(
        children: [
          const ClownLogo(size: 40, shadow: false),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('Hề IT'),
                style: TextStyle(
                  color: DeckColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Thanghetanty@gmail.com',
                style: TextStyle(
                  color: DeckColors.muted,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
              if (context.read<DeckConnection>().isOnline) ...[
                const SizedBox(height: 6),
                Builder(builder: (_) {
                  final conn = context.read<DeckConnection>();
                  final old = conn.agentOutdated;
                  return Text(
                    old
                        ? t('Agent v{0} — cần v{1}, hãy chạy lại agent', [conn.agentVersion, DeckConnection.minAgentVersion])
                        : 'Agent v${conn.agentVersion}',
                    style: TextStyle(
                      color: old ? DeckColors.warn : DeckColors.muted,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  );
                }),
              ],
              if (store.fingerprint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 12, color: DeckColors.live),
                    const SizedBox(width: 5),
                    Text(
                      t('Vân tay {0}', [store.fingerprint]),
                      style: TextStyle(
                        color: DeckColors.live,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetItem(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon, size: 20, color: DeckColors.muted),
        title: Text(label,
            style: TextStyle(color: DeckColors.text, fontSize: 14)),
        onTap: () => Navigator.pop(context, value),
      );

  Future<String?> _askName(String current) {
    final ctl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeckColors.surface,
        title: Text(t('Tên trang'),
            style: TextStyle(color: DeckColors.text, fontSize: 17)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          style: TextStyle(color: DeckColors.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t('Huỷ'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: Text(t('Lưu'))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final conn = context.watch<DeckConnection>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  // Chừa chỗ bên trái cho logo nằm đè lên
                  SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 62),
                      child: _statusBar(conn, store),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _pager,
                      itemCount: store.pages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _grid(i, store, conn),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _bottomBar(store),
                ],
              ),
            ),
            // Vẽ sau cùng nên luôn nằm trên lưới ô, không bị che mất góc
            Positioned(left: 8, top: 2, child: _logo()),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(DeckConnection conn, Store store) {
    final (color, label) = switch (conn.state) {
      ConnState.online when conn.agentOutdated => (
          DeckColors.warn,
          t('Agent trên thiết bị là bản cũ — gõ C trong cửa sổ agent để cập nhật, hoặc tắt rồi mở lại agent')
        ),
      ConnState.online => (
          conn.catalogStuck ? DeckColors.warn : DeckColors.live,
          conn.catalogStuck
              ? t('Thiết bị chưa quét xong — xem cửa sổ agent')
              : (conn.catalogLoading && conn.catalog.isEmpty
                  ? t('Đang lấy danh sách ứng dụng…')
                  : (conn.hostName.isEmpty ? store.hostName : conn.hostName))
        ),
      ConnState.connecting => (DeckColors.warn, t('Đang tìm thiết bị…')),
      ConnState.failed => (
          DeckColors.warn,
          conn.retryInSeconds > 0
              ? t('Chưa thấy thiết bị · thử lại sau {0}s', [conn.retryInSeconds])
              : t('Đang thử lại…')
        ),
      ConnState.needsPairing => (DeckColors.danger, t('Cần ghép cặp lại')),
      ConnState.offline => (DeckColors.muted, t('Ngoại tuyến')),
    };

    return Row(
      children: [
        // Gom cả nhóm bên trái vào một Expanded: phần thừa dồn hết vào đây,
        // nhờ vậy hai nút bên phải luôn bám sát mép, không phụ thuộc Spacer.
        Expanded(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: DeckColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (conn.isOnline && conn.latencyMs != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  // Bản tối giữ màu gốc; bản sáng dùng nền nhạt của màu
                  // trạng thái, chữ đậm cho đủ tương phản trên nền trắng.
                  decoration: BoxDecoration(
                    color: DeckColors.isDark
                        ? const Color(0xFF0F6E56)
                        : DeckColors.live.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Wi-Fi · ${conn.latencyMs} ms',
                      style: TextStyle(
                          color: DeckColors.isDark
                              ? const Color(0xFF9FE1CB)
                              : DeckColors.live,
                          fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        if (conn.state == ConnState.needsPairing)
          _barButton(
            icon: Icons.link_rounded,
            tooltip: t('Ghép cặp lại'),
            color: DeckColors.danger,
            onTap: _repair,
          )
        else if (!conn.isOnline)
          _barButton(
            icon: Icons.refresh_rounded,
            tooltip: t('Thử kết nối lại ngay'),
            color: DeckColors.warn,
            onTap: conn.reconnectNow,
          ),
        _barButton(
          icon: Icons.monitor_heart_rounded,
          tooltip: t('Hiệu năng: FPS, nhiệt độ'),
          color: DeckColors.muted,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PerfScreen())),
        ),
        _barButton(
          icon: Icons.mouse_rounded,
          tooltip: t('Touchpad và bàn phím'),
          color: DeckColors.muted,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const TouchpadScreen())),
        ),
        _barButton(
          icon: Icons.power_settings_new_rounded,
          tooltip: conn.isOnline ? t('Nguồn máy tính') : t('Bật máy tính'),
          // Máy tắt mà bật được thì nút sáng xanh, mời bấm.
          color: !conn.isOnline && store.canWake
              ? DeckColors.live
              : DeckColors.muted,
          onTap: _powerSheet,
        ),
        _barButton(
          icon: _editing ? Icons.check_rounded : Icons.edit_rounded,
          tooltip: _editing ? 'Xong' : t('Sửa bố cục'),
          color: _editing ? DeckColors.accent : DeckColors.muted,
          onTap: () => setState(() => _editing = !_editing),
        ),
        _barButton(
          icon: Icons.settings_rounded,
          tooltip: t('Tuỳ chọn'),
          color: DeckColors.muted,
          onTap: _menu,
        ),
      ],
    );
  }

  /// Logo chú hề ở góc trái trên. Đây là điểm chạm to và dễ với nhất trên
  /// màn hình nên gán luôn cho menu tuỳ chọn thay vì để làm vật trang trí.
  Widget _logo() {
    return Tooltip(
      message: t('Tuỳ chọn HeDeck'),
      child: InkWell(
        onTap: _menu,
        borderRadius: BorderRadius.circular(30),
        child: Transform.rotate(
          angle: -13 * math.pi / 180,
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: ClownLogo(size: 54, shadow: true),
          ),
        ),
      ),
    );
  }

  /// Nút gọn cho thanh trên: bỏ vùng chạm 48px mặc định của IconButton, vốn
  /// đẩy icon lùi hẳn vào trong so với mép màn hình.
  Widget _barButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _grid(int pageIndex, Store store, DeckConnection conn) {
    final page = store.pages[pageIndex];
    final capacity = store.capacity;
    final firstEmpty = page.firstEmptySlot(capacity);

    return LayoutBuilder(
      builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight;
        // Dọc màn hình thì lật lưới lại cho ô khỏi bị dẹt.
        final cols = landscape ? Store.cols : store.rows;
        final rows = landscape ? store.rows : Store.cols;
        const gap = 8.0;

        // Ô giãn theo cả hai chiều cho kín vùng trống. Bản trước ép ô vuông
        // theo chiều chật hơn: 5x2 gần kín màn hình nhưng 5x3 (cạnh vuông
        // nhỏ đi một phần ba) chỉ còn hai phần ba bề ngang, dồn vào giữa.
        // Giới hạn tỉ lệ rộng/cao để màn hình rất dài không làm ô dẹt lép.
        const minRatio = 0.7, maxRatio = 2.3;
        var cellW = (c.maxWidth - gap * (cols - 1)) / cols;
        var cellH = (c.maxHeight - gap * (rows - 1)) / rows;
        if (cellW / cellH > maxRatio) cellW = cellH * maxRatio;
        if (cellW / cellH < minRatio) cellH = cellW / minRatio;
        final gridW = cellW * cols + gap * (cols - 1);
        final gridH = cellH * rows + gap * (rows - 1);

        return Center(
          child: SizedBox(
            width: gridW,
            height: gridH,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: capacity,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: cellW / cellH,
              ),
              itemBuilder: (_, slot) {
                final tile = page.tiles[slot];
                return DeckTileView(
                  tile: tile,
                  app: tile.appId == null ? null : conn.catalogById[tile.appId],
                  status: conn.statusOf(tile.appId),
                  pending: conn.isPending(tile.appId),
                  editing: _editing,
                  flipped: store.isFlipped(pageIndex, slot),
                  isFirstEmpty: slot == firstEmpty,
                  onTap: () => (_editing || tile.isEmpty)
                      ? _edit(pageIndex, slot, tile)
                      : _fire(pageIndex, slot, tile),
                  onEdit: () => _edit(pageIndex, slot, tile),
                  onForceClose: () => _forceClose(tile),
                  onPickWindow: tile.appId == null
                      ? null
                      : (w) => conn.focusWindow(tile.appId!, w.hwnd),
                  onWindowList: () => _windowSheet(tile),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar(Store store) {
    final page = store.pages[_page];
    final used = page.tiles
        .take(store.capacity)
        .where((t) => !t.isEmpty)
        .length;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Row(
                children: List.generate(
                  store.pages.length,
                  (i) => GestureDetector(
                    onTap: () => _pager.animateToPage(i,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? DeckColors.accent : DeckColors.line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (page.hasAuto) ...[
                // Trang này tự mở theo app: nhìn là biết.
                Icon(Icons.bolt_rounded,
                    size: 14, color: DeckColors.accent),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  '${page.name} · $used/${store.capacity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DeckColors.muted, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _addTile,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child:
                      Icon(Icons.add_rounded, size: 18, color: DeckColors.muted),
                ),
              ),
            ],
          ),
        ),
        const MediaBar(),
      ],
    );
  }
}
