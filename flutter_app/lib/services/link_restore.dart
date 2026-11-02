import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform/link_io.dart'
    if (dart.library.js_interop) 'platform/link_web.dart';

/// Bản web trên iPhone: giữ ghép cặp qua đường link.
///
/// Biểu tượng HeDeck ngoài Màn hình chính có bộ nhớ riêng, tách khỏi Safari,
/// và iOS có thể xoá dữ liệu trang lâu không mở — mở lên lại đòi mã ghép cặp.
/// Nên sau khi ghép, app ghi một "vé" vào phần sau dấu # của đường link
/// (…/#hd=…): khoá của máy này và mã thiết bị. Phần sau dấu # không bao giờ
/// gửi lên mạng; iPhone lưu nó vào biểu tượng khi Thêm vào Màn hình chính.
/// Mở lên mà bộ nhớ trống thì dựng lại ghép cặp từ vé, khỏi nhập mã.
///
/// Vé chứa khoá riêng của máy này: đừng gửi đường link của biểu tượng cho
/// người khác (cũng như không đưa điện thoại đã mở khoá cho người lạ).
const _seed = 'hedeck.identity.seed';
const _public = 'hedeck.identity.public';
const _deviceId = 'deck.deviceId';
const _fingerprint = 'deck.fingerprint';
const _hostName = 'deck.hostName';

/// Gọi trước khi đọc cấu hình lúc khởi động.
Future<void> restorePairingFromLink() async {
  if (!kIsWeb) return;
  final token = restoreTokenFromLink();
  if (token == null) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_seed) != null) return; // còn dữ liệu: không đè
  try {
    final j =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token))))
            as Map<String, dynamic>;
    final page = Uri.base;
    await prefs.setString(_seed, j['s'] as String);
    await prefs.setString(_public, j['p'] as String);
    await prefs.setString(_deviceId, j['d'] as String);
    await prefs.setString(_fingerprint, j['f'] as String);
    await prefs.setString(_hostName, j['n'] as String? ?? '');
    // Máy cần kết nối là máy đã phục vụ trang này.
    await prefs.setString('deck.host', page.host);
    await prefs.setInt('deck.port', page.hasPort ? page.port : 80);
  } catch (e) {
    debugPrint('HeDeck: vé khôi phục hỏng ($e)');
  }
}

/// Ghi vé theo ghép cặp hiện tại (hoặc xoá nếu chưa ghép).
Future<void> saveRestoreLink() async {
  if (!kIsWeb) return;
  final prefs = await SharedPreferences.getInstance();
  final seed = prefs.getString(_seed);
  final pub = prefs.getString(_public);
  final device = prefs.getString(_deviceId);
  final fp = prefs.getString(_fingerprint) ?? '';
  if (seed == null || pub == null || device == null || fp.isEmpty) {
    setLinkToken(null);
    return;
  }
  final token = base64Url
      .encode(utf8.encode(jsonEncode({
        's': seed,
        'p': pub,
        'd': device,
        'f': fp,
        'n': prefs.getString(_hostName) ?? '',
      })))
      .replaceAll('=', '');
  setLinkToken(token);
}
