import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deck.dart';

/// Cấu hình lưu trên máy: thông tin ghép cặp và bố cục các trang.
class Store extends ChangeNotifier {
  static const _kHost = 'deck.host';
  static const _kPort = 'deck.port';
  static const _kFingerprint = 'deck.fingerprint';
  static const _kDeviceId = 'deck.deviceId';
  static const _kHostName = 'deck.hostName';
  static const _kPages = 'deck.pages';
  static const _kRows = 'deck.rows';
  static const _kFlipped = 'deck.flipped';

  late SharedPreferences _prefs;

  String host = '';
  int port = 8787;
  String deviceId = '';
  String fingerprint = '';
  String hostName = '';
  List<DeckPage> pages = DeckPage.starter();

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
    deviceId = _prefs.getString(_kDeviceId) ?? _newDeviceId();
    await _prefs.setString(_kDeviceId, deviceId);

    final raw = _prefs.getString(_kPages);
    if (raw != null) {
      try {
        pages = (jsonDecode(raw) as List)
            .map((e) => DeckPage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        pages = DeckPage.starter();
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

  /// Lưu địa chỉ mới khi tự dò lại thấy laptop chuyển sang IP khác.
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
    await _prefs.remove(_kHost);
    await _prefs.remove(_kFingerprint);
    await _prefs.remove(_kHostName);
    notifyListeners();
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
    pages.add(DeckPage(name: 'Trang ${pages.length + 1}'));
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
