import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:multicast_dns/multicast_dns.dart';

class FoundHost {
  final String name;
  final String ip;
  final int port;
  FoundHost(this.name, this.ip, this.port);
}

/// Tìm agent đang quảng bá dịch vụ `_hedeck._tcp` trong mạng nội bộ.
///
/// Một số router chặn multicast; nếu không thấy gì, người dùng vẫn nhập tay
/// được địa chỉ IP hiện trên cửa sổ agent.
Future<List<FoundHost>> discoverHosts({
  Duration timeout = const Duration(seconds: 4),
}) async {
  const service = '_hedeck._tcp.local';
  final found = <String, FoundHost>{};

  // multicast_dns mặc định mở socket với reusePort: true, nhưng Android không
  // hỗ trợ cờ đó — socket ném lỗi và việc dò tìm âm thầm trả về rỗng. Tự dựng
  // socket với reusePort: false để nó chạy được.
  final client = MDnsClient(
    rawDatagramSocketFactory: (
      dynamic host,
      int port, {
      bool reuseAddress = true,
      bool reusePort = true,
      int ttl = 1,
    }) =>
        RawDatagramSocket.bind(
      host,
      port,
      reuseAddress: reuseAddress,
      reusePort: false,
      ttl: ttl,
    ),
  );

  try {
    await client.start();
    final ptrStream = client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(service),
      timeout: timeout,
    );

    await for (final ptr in ptrStream) {
      await for (final srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
        timeout: timeout,
      )) {
        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
          timeout: timeout,
        )) {
          final label = srv.target.replaceAll('.local', '');
          found[ip.address.address] =
              FoundHost(label, ip.address.address, srv.port);
        }
      }
    }
  } catch (e) {
    // Dò tìm là tiện ích, không phải điều kiện bắt buộc — nhưng phải ghi lại
    // lý do, chứ im lặng thì lần sau lại mất công lần mò.
    debugPrint('HeDeck: dò tìm mDNS không thành ($e). '
        'Nhập IP thủ công vẫn dùng được.');
  } finally {
    client.stop();
  }

  return found.values.toList();
}
