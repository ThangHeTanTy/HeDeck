import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../services/deck_connection.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/clown_logo.dart';
import '../widgets/deck_tile_view.dart';
import '../widgets/media_bar.dart';
import 'tile_edit_screen.dart';

class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> with WidgetsBindingObserver {
  final _pager = PageController();
  Timer? _tick;
  int _page = 0;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    // Nhịp mỗi giây chỉ để vẽ lại đồng hồ đếm ngược lúc đang thử lại.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !context.read<DeckConnection>().isOnline) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
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

    // Laptop đổi IP thì tự dò lại và lưu địa chỉ mới, khỏi ghép cặp lại.
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
      _snack('Chưa kết nối tới laptop');
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
      case TileKind.empty:
        return;
    }

    if (tile.isToggle) await store.toggleFlip(pageIndex, slot);
  }

  void _forceClose(DeckTile tile) {
    final conn = context.read<DeckConnection>();
    if (!conn.isOnline || tile.appId == null) return;
    conn.close(tile.appId!);
    final name = conn.catalogById[tile.appId]?.name ?? 'Ứng dụng';
    _snack('Đã tắt $name');
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

  // ---------------------------------------------------------------- menu

  Future<void> _menu() async {
    final store = context.read<Store>();
    final conn = context.read<DeckConnection>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DeckColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _layoutRow(store),
            const Divider(height: 1, color: DeckColors.line),
            _sheetItem(Icons.refresh_rounded, 'Quét lại ứng dụng trên laptop', 'rescan'),
            _sheetItem(Icons.add_rounded, 'Thêm trang', 'addPage'),
            _sheetItem(Icons.drive_file_rename_outline_rounded, 'Đổi tên trang này', 'rename'),
            if (store.pages.length > 1)
              _sheetItem(Icons.delete_outline_rounded, 'Xoá trang này', 'delPage'),
            _sheetItem(Icons.link_off_rounded, 'Quên laptop này', 'forget'),
            const Divider(height: 1, color: DeckColors.line),
            _aboutBlock(),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'rescan':
        conn.rescan();
        _snack('Đang quét lại Start Menu…');
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
      case 'forget':
        await conn.stop();
        await store.forgetHost();
        break;
    }
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
                    Text('${rows * Store.cols} ô mỗi trang',
                        style: const TextStyle(
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
              const Text('Bố cục lưới',
                  style: TextStyle(color: DeckColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [option(2, '5 × 2'), option(3, '5 × 3')]),
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
              const Text(
                'Hề IT',
                style: TextStyle(
                  color: DeckColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Thanghetanty@gmail.com',
                style: TextStyle(
                  color: DeckColors.muted,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
              if (store.fingerprint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 12, color: DeckColors.live),
                    const SizedBox(width: 5),
                    Text(
                      'Vân tay ${store.fingerprint}',
                      style: const TextStyle(
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
            style: const TextStyle(color: DeckColors.text, fontSize: 14)),
        onTap: () => Navigator.pop(context, value),
      );

  Future<String?> _askName(String current) {
    final ctl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeckColors.surface,
        title: const Text('Tên trang',
            style: TextStyle(color: DeckColors.text, fontSize: 17)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          style: const TextStyle(color: DeckColors.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Lưu')),
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
      ConnState.online => (
          conn.catalogStuck ? DeckColors.warn : DeckColors.live,
          conn.catalogStuck
              ? 'Laptop chưa quét xong — xem cửa sổ agent'
              : (conn.catalogLoading && conn.catalog.isEmpty
                  ? 'Đang lấy danh sách ứng dụng…'
                  : (conn.hostName.isEmpty ? store.hostName : conn.hostName))
        ),
      ConnState.connecting => (DeckColors.warn, 'Đang tìm laptop…'),
      ConnState.failed => (
          DeckColors.warn,
          conn.retryInSeconds > 0
              ? 'Chưa thấy laptop · thử lại sau ${conn.retryInSeconds}s'
              : 'Đang thử lại…'
        ),
      ConnState.needsPairing => (DeckColors.danger, 'Cần ghép cặp lại'),
      ConnState.offline => (DeckColors.muted, 'Ngoại tuyến'),
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
                  style: const TextStyle(
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
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F6E56),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Wi-Fi · ${conn.latencyMs} ms',
                      style: const TextStyle(
                          color: Color(0xFF9FE1CB), fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        if (conn.state == ConnState.needsPairing)
          _barButton(
            icon: Icons.link_rounded,
            tooltip: 'Ghép cặp lại',
            color: DeckColors.danger,
            onTap: _repair,
          )
        else if (!conn.isOnline)
          _barButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Thử kết nối lại ngay',
            color: DeckColors.warn,
            onTap: conn.reconnectNow,
          ),
        _barButton(
          icon: _editing ? Icons.check_rounded : Icons.edit_rounded,
          tooltip: _editing ? 'Xong' : 'Sửa bố cục',
          color: _editing ? DeckColors.accent : DeckColors.muted,
          onTap: () => setState(() => _editing = !_editing),
        ),
        _barButton(
          icon: Icons.settings_rounded,
          tooltip: 'Tuỳ chọn',
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
      message: 'Tuỳ chọn HeDeck',
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

        // Ô vuông: cạnh lấy theo chiều chật hơn, rồi căn giữa cả lưới.
        final side = math.min(
          (c.maxWidth - gap * (cols - 1)) / cols,
          (c.maxHeight - gap * (rows - 1)) / rows,
        );
        final gridW = side * cols + gap * (cols - 1);
        final gridH = side * rows + gap * (rows - 1);

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
                childAspectRatio: 1,
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
              Flexible(
                child: Text(
                  '${page.name} · $used/${store.capacity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DeckColors.muted, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _addTile,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
