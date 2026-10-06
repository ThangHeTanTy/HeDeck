import 'dart:io';

import 'package:flutter/foundation.dart';

/// Thông tin bật máy mà agent gửi về khi laptop còn đang chạy.
class WolInfo {
  /// MAC của các card mạng có dây, card đang cắm cáp đứng đầu.
  final List<String> macs;

  /// Địa chỉ broadcast của mạng LAN, ví dụ 192.168.1.255. Rỗng nếu chưa biết.
  final String broadcast;

  /// Laptop đang cắm dây LAN. Không cắm dây thì máy tắt hẳn sẽ không nghe
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

/// Gửi gói tin bật máy. Trả về số gói đã gửi đi được.
///
/// Gửi broadcast chứ không gửi thẳng IP của laptop: máy đã tắt thì không trả
/// lời ARP, router không biết IP đó nằm ở đâu, gói tin gửi thẳng sẽ lạc. Gửi
/// broadcast thì mọi card mạng trong LAN đều nhận, card nào thấy đúng MAC của
/// mình thì đánh thức máy.
///
/// Gửi cả hai cổng 9 và 7, mỗi nơi ba lần — UDP không bảo đảm tới nơi, Wi-Fi
/// lại hay rơi gói broadcast, gửi dư không hại gì.
Future<int> sendWakeOnLan(List<String> macs, {String broadcast = ''}) async {
  final packets = macs.map(parseMac).whereType<Uint8List>().map(magicPacket);
  if (packets.isEmpty) return 0;

  final targets = <InternetAddress>{
    InternetAddress('255.255.255.255'),
    if (broadcast.isNotEmpty && InternetAddress.tryParse(broadcast) != null)
      InternetAddress(broadcast),
  };

  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true;
  var sent = 0;
  try {
    for (var round = 0; round < 3; round++) {
      for (final packet in packets) {
        for (final target in targets) {
          for (final port in const [9, 7]) {
            try {
              if (socket.send(packet, target, port) > 0) sent++;
            } catch (e) {
              debugPrint('HeDeck: gửi gói bật máy tới $target:$port lỗi ($e)');
            }
          }
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  } finally {
    socket.close();
  }
  return sent;
}
