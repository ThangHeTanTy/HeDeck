import 'package:web_socket_channel/web_socket_channel.dart';

/// Trình duyệt không cho đặt thời gian chờ hay ping ở tầng socket. Hết giờ
/// thì tự bỏ; giữ kết nối sống đã có vòng ping riêng của DeckConnection.
Future<WebSocketChannel> openDeckSocket(Uri uri) async {
  final ch = WebSocketChannel.connect(uri);
  try {
    await ch.ready.timeout(const Duration(seconds: 6));
  } catch (_) {
    ch.sink.close();
    rethrow;
  }
  return ch;
}
