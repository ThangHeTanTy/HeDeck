import 'dart:io';

import 'package:flutter/foundation.dart';

import '../wake_on_lan.dart';

/// Điện thoại gửi được gói tin bật máy.
const canSendWakeOnLan = true;

/// Gửi gói tin bật máy. Trả về số gói đã gửi đi được.
///
/// Gửi broadcast chứ không gửi thẳng IP của thiết bị: máy đã tắt thì không trả
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
