import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> openDeckSocket(Uri uri) async {
  final ch = IOWebSocketChannel.connect(
    uri,
    connectTimeout: const Duration(seconds: 6),
    pingInterval: const Duration(seconds: 15),
  );
  await ch.ready;
  return ch;
}
