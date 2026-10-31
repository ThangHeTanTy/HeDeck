import 'package:flutter/foundation.dart';

// Gửi gói tin cần socket UDP, trình duyệt không có. Bản web dùng bản giả
// báo không gửi được, để cùng một bộ code build được cả APK lẫn web.
export 'platform/wol_send_io.dart'
    if (dart.library.js_interop) 'platform/wol_send_web.dart';

/// Thông tin bật máy mà agent gửi về khi thiết bị còn đang chạy.
class WolInfo {
  /// MAC của các card mạng có dây, card đang cắm cáp đứng đầu.
  final List<String> macs;

  /// Địa chỉ broadcast của mạng LAN, ví dụ 192.168.1.255. Rỗng nếu chưa biết.
  final String broadcast;

  /// Thiết bị đang cắm dây LAN. Không cắm dây thì máy tắt hẳn sẽ không nghe
  /// được gói tin bật máy.
  final bool wired;

  final List<String> warnings;

  const WolInfo({
    this.macs = const [],
    this.broadcast = '',
    this.wired = false,
    this.warnings = const [],
  });

  factory WolInfo.fromJson(Map<String, dynamic> j) => WolInfo(
        macs: (j['macs'] as List? ?? const [])
            .whereType<String>()
            .where((m) => parseMac(m) != null)
            .toList(),
        broadcast: j['broadcast'] as String? ?? '',
        wired: j['wired'] as bool? ?? false,
        warnings: (j['warnings'] as List? ?? const [])
            .whereType<String>()
            .toList(),
      );
}

/// Đọc MAC dạng `AA:BB:CC:DD:EE:FF`, `AA-BB-…` hay `AABBCCDDEEFF`.
Uint8List? parseMac(String text) {
  final hex = text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (hex.length != 12) return null;
  final bytes = Uint8List(6);
  for (var i = 0; i < 6; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  if (bytes.every((b) => b == 0) || bytes.every((b) => b == 0xFF)) return null;
  return bytes;
}

/// Viết MAC về một dạng thống nhất để lưu và hiển thị.
String? normalizeMac(String text) {
  final bytes = parseMac(text);
  if (bytes == null) return null;
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}

/// Magic packet: 6 byte 0xFF rồi MAC lặp lại 16 lần, tổng 102 byte.
Uint8List magicPacket(Uint8List mac) {
  final out = Uint8List(6 + 16 * 6);
  out.fillRange(0, 6, 0xFF);
  for (var i = 0; i < 16; i++) {
    out.setRange(6 + i * 6, 12 + i * 6, mac);
  }
  return out;
}
