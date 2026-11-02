import 'deck_connection.dart';
import 'store.dart';

import 'platform/relay_io.dart'
    if (dart.library.js_interop) 'platform/relay_web.dart';

export 'platform/relay_io.dart'
    if (dart.library.js_interop) 'platform/relay_web.dart';

/// Bật hoặc tắt trạm bật máy theo thiết lập, và báo agent địa chỉ của trạm.
/// Trả về địa chỉ Tailscale của điện thoại này (rỗng nếu chưa có Tailscale —
/// khi đó trạm vẫn chạy nhưng điện thoại ở xa không gọi tới được).
/// [ask]: người dùng vừa bật trạm — xin quyền thông báo và bỏ tối ưu pin.
Future<String> applyRelay(Store store, DeckConnection conn,
    {bool ask = false}) async {
  if (!store.relayEnabled || !canRunRelay) {
    await wakeRelay.stop();
    if (canRunRelay) conn.setRelay();
    return '';
  }
  await wakeRelay.start(
    key: () => store.wakeKey,
    macs: () => store.wolMacs,
    broadcast: () => store.wolBroadcast,
    ask: ask,
  );
  final ip = await tailscaleAddress();
  conn.setRelay(ip: ip);
  return ip;
}
