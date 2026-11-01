/// Trình duyệt không mở được cổng để làm trạm, cũng không gửi được gói tin
/// bật máy. Bản web chỉ có các hàm rỗng để cùng code build được.
const canRunRelay = false;

Future<String> tailscaleAddress() async => '';

class WakeRelayServer {
  bool get running => false;

  Future<void> start({
    required String Function() key,
    required List<String> Function() macs,
    required String Function() broadcast,
    int port = 8788,
  }) async {}

  Future<void> stop() async {}
}

Future<int> wakeViaRelay(String host, int port, String keyB64) =>
    Future.error(UnsupportedError('web'));

final wakeRelay = WakeRelayServer();
