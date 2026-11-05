import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../models/deck.dart';
import 'deck_connection.dart' show SessionInfo;
import '../theme.dart';

/// Cấu hình lưu trên máy: thông tin ghép cặp và bố cục các trang.
class Store extends ChangeNotifier {
  static const _kHost = 'deck.host';
  static const _kPort = 'deck.port';
  static const _kFingerprint = 'deck.fingerprint';
  static const _kDeviceId = 'deck.deviceId';
  static const _kHostName = 'deck.hostName';
  static const _kPages = 'deck.pages';
  static const _kPagesBackup = 'deck.pages.backup';
  static const _kRows = 'deck.rows';
  static const _kFlipped = 'deck.flipped';
  static const _kWolMacs = 'deck.wolMacs';
  static const _kAutoSwitch = 'deck.autoSwitch';
  static const _kTopCollapsed = 'ui.topCollapsed';
  static const _kMediaCollapsed = 'ui.mediaCollapsed';
  static const _kLang = 'deck.lang';
  static const _kDark = 'deck.dark';
  static const _kMouseSpeed = 'deck.mouseSpeed';
  static const _kWolBroadcast = 'deck.wolBroadcast';
  static const _kRemoteHost = 'deck.remoteHost';
  static const _kRelay = 'deck.relay';
  static const _kWakeKey = 'deck.wakeKey';
  static const _kRelayOn = 'deck.relayOn';
  static const _kScreenLevel = 'deck.screenLevel';

  late SharedPreferences _prefs;

  String host = '';
  int port = 8787;
  String deviceId = '';
  String fingerprint = '';
  String hostName = '';
  List<DeckPage> pages = DeckPage.starter();

  /// MAC card mạng có dây của thiết bị, để bật máy bằng Wake-on-LAN. Phải lưu
  /// lại vì lúc cần bật máy thì agent đã tắt theo, không ai trả lời nữa.
  List<String> wolMacs = [];
  String wolBroadcast = '';

  bool get canWake => wolMacs.isNotEmpty;

  /// Địa chỉ Tailscale của máy tính (100.x.y.z): dùng khi ra khỏi mạng nhà.
  /// Rỗng nếu máy tính chưa cài Tailscale.
  String remoteHost = '';

  /// Trạm bật máy: điện thoại deck để ở nhà, nhận lệnh qua Tailscale rồi phát
  /// tín hiệu bật máy trong mạng nhà. Rỗng nếu chưa có trạm.
  String relayHost = '';
  int relayPort = 8788;
  String relayDevice = '';

  /// Khoá agent cấp để ký lệnh bật máy gửi tới trạm.
  String wakeKey = '';

  bool get canWakeRemotely =>
      relayHost.isNotEmpty && wakeKey.isNotEmpty && relayDevice != deviceId;

  /// Điện thoại này làm trạm bật máy (luôn để ở nhà, cắm sạc).
  bool relayEnabled = false;

  /// Chất lượng hình màn hình máy tính trong touchpad: low, mid, high.
  /// Rỗng: tự chọn (mid trong mạng nhà, low khi ở xa).
  String screenLevel = '';

  /// Ngôn ngữ giao diện.
  AppLang lang = AppLang.vi;

  /// Chủ đề tối (mặc định, màu gốc của app) hay sáng.
  bool dark = true;

  /// Tự đổi trang theo app đang dùng trên thiết bị.
  bool autoSwitch = true;

  /// Thu gọn các nút trên thanh trên vào nút ☰.
  bool topCollapsed = false;

  /// Thu gọn thanh nhạc/âm lượng thành một nút ở góc phải dưới.
  bool mediaCollapsed = false;

  /// Tốc độ con trỏ của touchpad, 0.5..3.
  double mouseSpeed = 1.4;

  /// Số hàng của lưới: 2 (bố cục 4x2, 8 ô) hoặc 3 (4x3, 12 ô).
  int rows = 2;

  /// Các ô hai trạng thái đang ở mặt phụ, ghi theo khoá "trang:ô".
  final Set<String> flippedTiles = {};

  static const cols = 5;

  int get capacity => rows * cols;

  /// deviceId luôn tồn tại ngay từ lần chạy đầu, nên nó không chứng minh được
  /// đã ghép cặp. Vân tay chỉ có sau khi agent xác nhận, mới là dấu hiệu đúng.
  bool get isPaired => host.isNotEmpty && fingerprint.isNotEmpty;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    host = _prefs.getString(_kHost) ?? '';
    port = _prefs.getInt(_kPort) ?? 8787;
    fingerprint = _prefs.getString(_kFingerprint) ?? '';
    hostName = _prefs.getString(_kHostName) ?? '';
    rows = _prefs.getInt(_kRows) ?? 2;
    flippedTiles
      ..clear()
      ..addAll(_prefs.getStringList(_kFlipped) ?? const []);
    // Chưa chọn lần nào thì theo ngôn ngữ của điện thoại: máy tiếng Việt
    // dùng tiếng Việt, còn lại tiếng Anh.
    final savedLang = _prefs.getString(_kLang);
    lang = savedLang != null
        ? AppLang.fromCode(savedLang)
        : (PlatformDispatcher.instance.locale.languageCode == 'vi'
            ? AppLang.vi
            : AppLang.en);
    L10n.current = lang;
    dark = _prefs.getBool(_kDark) ?? true;
    DeckColors.use(dark ? DeckPalette.dark : DeckPalette.light);
    autoSwitch = _prefs.getBool(_kAutoSwitch) ?? true;
    topCollapsed = _prefs.getBool(_kTopCollapsed) ?? false;
    mediaCollapsed = _prefs.getBool(_kMediaCollapsed) ?? false;
    mouseSpeed = _prefs.getDouble(_kMouseSpeed) ?? 1.4;
    wolMacs = _prefs.getStringList(_kWolMacs) ?? [];
    wolBroadcast = _prefs.getString(_kWolBroadcast) ?? '';
    remoteHost = _prefs.getString(_kRemoteHost) ?? '';
    final relay = (_prefs.getString(_kRelay) ?? '').split('|');
    relayHost = relay.isNotEmpty ? relay[0] : '';
    relayPort = relay.length > 1 ? int.tryParse(relay[1]) ?? 8788 : 8788;
    relayDevice = relay.length > 2 ? relay[2] : '';
    wakeKey = _prefs.getString(_kWakeKey) ?? '';
    relayEnabled = _prefs.getBool(_kRelayOn) ?? false;
    screenLevel = _prefs.getString(_kScreenLevel) ?? '';
    deviceId = _prefs.getString(_kDeviceId) ?? _newDeviceId();
    await _prefs.setString(_kDeviceId, deviceId);

    final raw = _prefs.getString(_kPages);
    // Trang mẫu dựng lúc khởi tạo, khi chưa biết ngôn ngữ. Lần chạy đầu thì
    // dựng lại cho đúng tên theo ngôn ngữ vừa đọc.
    if (raw == null) pages = DeckPage.starter();
    if (raw != null) {
      // Đọc từng trang riêng: một trang hỏng (ví dụ bản cập nhật đổi cách
      // lưu ô) không được kéo theo mất cả bố cục. Có trang đọc không được thì
      // cất nguyên bản cũ sang khoá dự phòng trước khi lần lưu sau ghi đè.
      var broken = false;
      try {
        pages = [];
        for (final e in jsonDecode(raw) as List) {
          try {
            pages.add(DeckPage.fromJson(e as Map<String, dynamic>));
          } catch (_) {
            broken = true;
          }
        }
      } catch (_) {
        broken = true;
        pages = DeckPage.starter();
      }
      if (broken) {
        debugPrint('HeDeck: bố cục đã lưu có phần đọc không được, '
            'đã cất bản gốc ở $_kPagesBackup');
        await _prefs.setString(_kPagesBackup, raw);
      }
    }
    if (pages.isEmpty) pages = DeckPage.starter();
    notifyListeners();
  }

  String _newDeviceId() {
    final rnd = Random.secure();
    return List.generate(16, (_) => rnd.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> savePairing({
    required String host,
    required int port,
    required String deviceId,
    required String hostName,
    required String fingerprint,
  }) async {
    this.host = host;
    this.port = port;
    this.deviceId = deviceId;
    this.hostName = hostName;
    this.fingerprint = fingerprint;
    await _prefs.setString(_kHost, host);
    await _prefs.setInt(_kPort, port);
    await _prefs.setString(_kFingerprint, fingerprint);
    await _prefs.setString(_kDeviceId, deviceId);
    await _prefs.setString(_kHostName, hostName);
    notifyListeners();
  }

  /// Lưu địa chỉ mới khi tự dò lại thấy thiết bị chuyển sang IP khác.
  Future<void> updateHost(String host, int port) async {
    if (host == this.host && port == this.port) return;
    this.host = host;
    this.port = port;
    await _prefs.setString(_kHost, host);
    await _prefs.setInt(_kPort, port);
    notifyListeners();
  }

  Future<void> forgetHost() async {
    host = '';
    hostName = '';
    fingerprint = '';
    wolMacs = [];
    wolBroadcast = '';
    await _prefs.remove(_kHost);
    await _prefs.remove(_kFingerprint);
    await _prefs.remove(_kHostName);
    await _prefs.remove(_kWolMacs);
    await _prefs.remove(_kWolBroadcast);
    remoteHost = relayHost = relayDevice = wakeKey = '';
    await _prefs.remove(_kRemoteHost);
    await _prefs.remove(_kRelay);
    await _prefs.remove(_kWakeKey);
    notifyListeners();
  }

  /// Lưu thông tin agent gửi để dùng khi ở xa: lúc cần thì máy tính có thể
  /// đang tắt, không còn ai trả lời.
  Future<void> saveSession(SessionInfo info) async {
    var changed = false;
    if (info.remoteHost.isNotEmpty && info.remoteHost != remoteHost) {
      remoteHost = info.remoteHost;
      await _prefs.setString(_kRemoteHost, remoteHost);
      changed = true;
    }
    if (info.relayHost != relayHost ||
        info.relayPort != relayPort ||
        info.relayDevice != relayDevice) {
      relayHost = info.relayHost;
      relayPort = info.relayPort;
      relayDevice = info.relayDevice;
      await _prefs.setString(_kRelay, '$relayHost|$relayPort|$relayDevice');
      changed = true;
    }
    if (info.wakeKey.isNotEmpty && info.wakeKey != wakeKey) {
      wakeKey = info.wakeKey;
      await _prefs.setString(_kWakeKey, wakeKey);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> setRelayEnabled(bool value) async {
    relayEnabled = value;
    await _prefs.setBool(_kRelayOn, value);
    notifyListeners();
  }

  Future<void> setScreenLevel(String value) async {
    screenLevel = value;
    await _prefs.setString(_kScreenLevel, value);
    notifyListeners();
  }

  /// Lưu thông tin bật máy agent gửi về. Agent không thấy card dây nào thì
  /// giữ MAC cũ — có thể người dùng đã nhập tay, đừng xoá mất.
  Future<void> saveWol(List<String> macs, String broadcast) async {
    if (macs.isEmpty) return;
    if (listEquals(macs, wolMacs) && broadcast == wolBroadcast) return;
    wolMacs = List.of(macs);
    if (broadcast.isNotEmpty) wolBroadcast = broadcast;
    await _prefs.setStringList(_kWolMacs, wolMacs);
    await _prefs.setString(_kWolBroadcast, wolBroadcast);
    notifyListeners();
  }

  /// MAC nhập tay, dùng khi agent không tự đọc được.
  Future<void> setManualMac(String mac) async {
    wolMacs = [mac, ...wolMacs.where((m) => m != mac)];
    await _prefs.setStringList(_kWolMacs, wolMacs);
    notifyListeners();
  }

  /// Đã từng dựng bố cục trên máy này chưa, hay vẫn là trang mẫu ban đầu.
  bool get hasOwnLayout => _prefs.getString(_kPages) != null;

  /// Bố cục và thiết lập gửi lên máy tính để sao lưu. iPhone (bản web) có thể
  /// mất dữ liệu: biểu tượng ngoài Màn hình chính có bộ nhớ riêng, iOS xoá dữ
  /// liệu trang lâu không mở. Có bản sao trên máy tính thì lấy lại được.
  Map<String, dynamic> backupData() => {
        'pages': pages.map((p) => p.toJson()).toList(),
        'rows': rows,
        'flipped': flippedTiles.toList(),
        'lang': lang.name,
        'dark': dark,
        'autoSwitch': autoSwitch,
        'mouseSpeed': mouseSpeed,
        'screenLevel': screenLevel,
      };

  /// Lấy lại bố cục từ bản sao trên máy tính. Bản sao hỏng thì bỏ qua.
  Future<void> restoreBackup(Map<String, dynamic> b) async {
    final List<DeckPage> restored;
    try {
      restored = (b['pages'] as List)
          .map((e) => DeckPage.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return;
    }
    if (restored.isEmpty) return;
    pages = restored;
    final r = (b['rows'] as num?)?.toInt();
    if (r == 2 || r == 3) rows = r!;
    flippedTiles
      ..clear()
      ..addAll((b['flipped'] as List? ?? const []).whereType<String>());
    if (b['lang'] is String) {
      lang = AppLang.fromCode(b['lang'] as String);
      L10n.current = lang;
    }
    if (b['dark'] is bool) {
      dark = b['dark'] as bool;
      DeckColors.use(dark ? DeckPalette.dark : DeckPalette.light);
    }
    if (b['autoSwitch'] is bool) autoSwitch = b['autoSwitch'] as bool;
    final speed = (b['mouseSpeed'] as num?)?.toDouble();
    if (speed != null) mouseSpeed = speed;
    if (b['screenLevel'] is String) screenLevel = b['screenLevel'] as String;
    await _prefs.setInt(_kRows, rows);
    await _prefs.setStringList(_kFlipped, flippedTiles.toList());
    await _prefs.setString(_kLang, lang.name);
    await _prefs.setBool(_kDark, dark);
    await _prefs.setBool(_kAutoSwitch, autoSwitch);
    await _prefs.setDouble(_kMouseSpeed, mouseSpeed);
    await _prefs.setString(_kScreenLevel, screenLevel);
    await _persistPages();
  }

  Future<void> _persistPages() async {
    await _prefs.setString(
      _kPages,
      jsonEncode(pages.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> setTile(int pageIndex, int slot, DeckTile tile) async {
    pages[pageIndex] = pages[pageIndex].withTile(slot, tile);
    // Sửa ô thì bỏ trạng thái lật cũ, tránh ô mới hiện nhầm mặt phụ.
    flippedTiles.remove('$pageIndex:$slot');
    await _prefs.setStringList(_kFlipped, flippedTiles.toList());
    await _persistPages();
  }

  bool isFlipped(int page, int slot) => flippedTiles.contains('$page:$slot');

  /// Lật ô hai trạng thái. Trạng thái được giữ lại sau khi đóng app, vì mic
  /// vẫn đang tắt dù bạn có mở app hay không.
  Future<bool> toggleFlip(int page, int slot) async {
    final key = '$page:$slot';
    final now = !flippedTiles.contains(key);
    if (now) {
      flippedTiles.add(key);
    } else {
      flippedTiles.remove(key);
    }
    await _prefs.setStringList(_kFlipped, flippedTiles.toList());
    notifyListeners();
    return now;
  }

  Future<void> clearFlip(int page, int slot) async {
    if (flippedTiles.remove('$page:$slot')) {
      await _prefs.setStringList(_kFlipped, flippedTiles.toList());
      notifyListeners();
    }
  }

  /// Đổi ngôn ngữ. Giao diện tự dựng lại theo `lang` (xem SplashScreen).
  Future<void> setLang(AppLang value) async {
    if (value == lang) return;
    lang = value;
    L10n.current = value;
    await _prefs.setString(_kLang, value.name);
    notifyListeners();
  }

  /// Đổi chủ đề sáng/tối. Giao diện tự dựng lại theo `dark` (xem
  /// DeckApp và SplashScreen).
  Future<void> setDark(bool value) async {
    if (value == dark) return;
    dark = value;
    DeckColors.use(value ? DeckPalette.dark : DeckPalette.light);
    await _prefs.setBool(_kDark, value);
    notifyListeners();
  }

  Future<void> setAutoSwitch(bool value) async {
    autoSwitch = value;
    await _prefs.setBool(_kAutoSwitch, value);
    notifyListeners();
  }

  Future<void> setTopCollapsed(bool value) async {
    topCollapsed = value;
    notifyListeners();
    await _prefs.setBool(_kTopCollapsed, value);
  }

  Future<void> setMediaCollapsed(bool value) async {
    mediaCollapsed = value;
    notifyListeners();
    await _prefs.setBool(_kMediaCollapsed, value);
  }

  Future<void> setMouseSpeed(double value) async {
    mouseSpeed = value;
    await _prefs.setDouble(_kMouseSpeed, value);
    notifyListeners();
  }

  /// Gắn trang với app/desktop. Chỉ một trang được làm trang desktop: chọn
  /// trang mới thì trang cũ tự bỏ, khỏi phải đoán trang nào thắng.
  Future<void> setPageAuto(int index, List<String> apps, bool desktop) async {
    for (var i = 0; i < pages.length; i++) {
      if (i == index) {
        pages[i] = pages[i].withAuto(apps, desktop);
      } else if (desktop && pages[i].autoDesktop) {
        pages[i] = pages[i].withAuto(pages[i].autoApps, false);
      }
    }
    await _persistPages();
  }

  /// Trang cần nhảy tới khi app ở trước thay đổi, -1 nếu không trang nào.
  int pageForForeground(List<String> appIds, bool desktop) {
    if (desktop) return pages.indexWhere((p) => p.autoDesktop);
    for (final id in appIds) {
      final i = pages.indexWhere((p) => p.autoApps.contains(id));
      if (i >= 0) return i;
    }
    return -1;
  }

  Future<void> setRows(int value) async {
    if (value != 2 && value != 3) return;
    rows = value;
    await _prefs.setInt(_kRows, value);
    notifyListeners();
  }

  /// Tìm chỗ trống kế tiếp kể từ trang đang xem. Nếu mọi trang đã đầy thì tạo
  /// trang mới. Trả về (chỉ số trang, chỉ số ô).
  Future<(int, int)> nextFreeSlot(int fromPage) async {
    for (var i = 0; i < pages.length; i++) {
      final index = (fromPage + i) % pages.length;
      final slot = pages[index].firstEmptySlot(capacity);
      if (slot >= 0) return (index, slot);
    }
    await addPage();
    return (pages.length - 1, 0);
  }

  Future<void> addPage() async {
    pages.add(DeckPage(name: t('Trang {0}', [pages.length + 1])));
    await _persistPages();
  }

  Future<void> renamePage(int index, String name) async {
    pages[index] = pages[index].rename(name);
    await _persistPages();
  }

  Future<void> removePage(int index) async {
    if (pages.length <= 1) return;
    pages.removeAt(index);
    await _persistPages();
  }
}
