import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../wake_on_lan.dart';
import 'wake_page.dart';

/// Điện thoại này chạy được trạm bật máy (bản web thì không).
const canRunRelay = true;

/// Địa chỉ Tailscale (100.64.0.0/10) của chính điện thoại này, rỗng nếu chưa
/// cài hoặc chưa bật Tailscale.
Future<String> tailscaleAddress() async {
  try {
    final list = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in list) {
      for (final a in iface.addresses) {
        if (_isTailscale(a.rawAddress)) return a.address;
      }
    }
  } catch (_) {}
  return '';
}

bool _isTailscale(List<int> b) =>
    b.length == 4 && b[0] == 100 && (b[1] & 0xC0) == 64;

/// Chỉ nhận lệnh từ mạng nhà hoặc mạng Tailscale — không bao giờ từ Internet
/// trực tiếp, dù router có lỡ mở cổng.
bool _trusted(InternetAddress a) {
  if (a.isLoopback || a.isLinkLocal) return true;
  final b = a.type == InternetAddressType.IPv4 ? a.rawAddress : null;
  if (b == null) return false;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] < 32) ||
      (b[0] == 192 && b[1] == 168) ||
      _isTailscale(b);
}

Future<List<int>> _mac(String keyB64, int ts, String nonce) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('wake|$ts|$nonce'),
    secretKey: SecretKey(base64Decode(keyB64)),
  );
  return mac.bytes;
}

/// Trạm bật máy: chạy trên điện thoại deck để ở nhà. Điện thoại khác (ở xa,
/// qua Tailscale) gửi lệnh có chữ ký tới đây, trạm phát tín hiệu bật máy
/// trong mạng nhà — việc mà gói tin từ Internet không làm được.
class WakeRelayServer {
  HttpServer? _server;
  final _seen = <String>[];
  Uint8List? _icon;
  late String Function() _key;
  late List<String> Function() _macs;
  late String Function() _broadcast;

  bool get running => _server != null;

  Future<void> start({
    required String Function() key,
    required List<String> Function() macs,
    required String Function() broadcast,
    int port = 8788,
  }) async {
    _key = key;
    _macs = macs;
    _broadcast = broadcast;
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handle, onError: (Object e) {
      debugPrint('HeDeck: trạm bật máy lỗi ($e)');
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    var status = 200;
    Map<String, dynamic> body = {'ok': true};
    try {
      final peer = req.connectionInfo?.remoteAddress;
      if (peer == null || !_trusted(peer)) {
        status = 403;
        body = {'ok': false, 'error': 'not_local'};
      } else if (req.method == 'GET' &&
          (req.uri.path == '/' || req.uri.path == '/index.html')) {
        // Trang "Bật PC" cho iPhone/iPad (xem wake_page.dart).
        res.headers.contentType = ContentType.html;
        res.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        res.write(wakePageHtml);
        await res.close();
        return;
      } else if (req.method == 'GET' && req.uri.path == '/icon.png') {
        _icon ??= (await rootBundle.load('assets/icon/icon.png'))
            .buffer
            .asUint8List();
        res.headers.contentType = ContentType('image', 'png');
        res.add(_icon!);
        await res.close();
        return;
      } else if (req.method != 'POST' || req.uri.path != '/wake') {
        status = 404;
        body = {'ok': false};
      } else {
        final msg = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
        final ts = (msg['ts'] as num).toInt();
        final nonce = '${msg['nonce']}';
        final sig = base64Decode('${msg['sig']}');
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final key = _key();
        final expected = key.isEmpty ? null : await _mac(key, ts, nonce);
        // Lệnh cũ quá 2 phút hoặc đã dùng rồi thì bỏ: bắt được gói tin cũng
        // không phát lại được.
        if (expected == null ||
            (now - ts).abs() > 120 ||
            nonce.length < 8 ||
            _seen.contains(nonce) ||
            !_same(expected, sig)) {
          status = 403;
          body = {'ok': false, 'error': 'bad_signature'};
        } else {
          _seen.add(nonce);
          if (_seen.length > 256) _seen.removeAt(0);
          final sent = await sendWakeOnLan(_macs(), broadcast: _broadcast());
          body = {'ok': sent > 0, 'sent': sent};
        }
      }
    } catch (e) {
      status = 400;
      body = {'ok': false, 'error': '$e'};
    }
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
    await res.close();
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Nhờ trạm bật máy ở nhà gửi tín hiệu bật máy. Trả về số gói trạm đã gửi.
Future<int> wakeViaRelay(String host, int port, String keyB64) async {
  final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final nonce = DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      (ts ^ 0x5f3759df).toRadixString(36);
  final sig = base64Encode(await _mac(keyB64, ts, nonce));
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.post(host, port, '/wake');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'ts': ts, 'nonce': nonce, 'sig': sig}));
    final res = await req.close().timeout(const Duration(seconds: 8));
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
    if (res.statusCode != 200) {
      throw HttpException('relay ${res.statusCode} ${body['error'] ?? ''}');
    }
    return (body['sent'] as num?)?.toInt() ?? 0;
  } finally {
    client.close(force: true);
  }
}

final wakeRelay = WakeRelayServer();
