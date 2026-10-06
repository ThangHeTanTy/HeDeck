import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/deck_connection.dart';
import 'services/device_identity.dart';
import 'services/store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deck dùng ngang là chính, nhưng vẫn xoay dọc được nếu cầm một tay.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Giữ màn hình sáng do MainActivity đặt cờ FLAG_KEEP_SCREEN_ON, không dùng
  // plugin — plugin wakelock hay hỏng mỗi lần Flutter đổi phiên bản Kotlin.

  final store = Store();
  await store.load();
  debugPrint('HeDeck: đã ghép cặp=${store.isPaired} '
      'host="${store.host}" trang=${store.pages.length} '
      'bố cục=${Store.cols}x${store.rows}');

  // Cặp khoá Ed25519 của máy này. Sinh trong lần chạy đầu, sau đó nằm yên
  // trong kho mã hoá của Android.
  final identity = DeviceIdentity();
  final freshKey = await identity.load();

  // Tự kiểm tra ngay trên máy: vân tay khoá hiện tại phải trùng với vân tay
  // đã lưu lúc ghép cặp. Lệch nghĩa là khoá đã đổi (cài lại app, kho khoá
  // hỏng), laptop chắc chắn không nhận ra nữa — dọn luôn thay vì để app thử
  // kết nối rồi nhận về lỗi chữ ký khó hiểu.
  final current = await identity.fingerprint();
  debugPrint('HeDeck: vân tay khoá thiết bị = $current');

  if (store.isPaired) {
    if (freshKey || (current.isNotEmpty && current != store.fingerprint)) {
      debugPrint('HeDeck: khoá đã đổi (lưu ${store.fingerprint}), '
          'cần ghép cặp lại');
      await store.forgetHost();
    }
  }

  // Mặc định, lỗi lúc dựng giao diện ở bản phát hành hiện ra một khoảng xám
  // trống — nhìn y hệt màn hình đen và không nói được gì. Thay bằng màn hình
  // đỏ có nội dung lỗi để luôn biết chuyện gì xảy ra.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('HeDeck: LỖI GIAO DIỆN — ${details.exception}');
    return Material(
      color: const Color(0xFF3A1418),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HeDeck gặp lỗi khi dựng giao diện',
                    style: TextStyle(
                        color: Color(0xFFFFB4B4),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text('${details.exception}',
                    style: const TextStyle(
                        color: Color(0xFFE8EAF0), fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(DeckApp(store: store, identity: identity));
}

class DeckApp extends StatelessWidget {
  final Store store;
  final DeviceIdentity identity;
  const DeckApp({super.key, required this.store, required this.identity});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(
          create: (_) {
            final conn = DeckConnection(identity);
            // Gán ngay từ lúc dựng, không phụ thuộc màn hình nào chạy trước.
            conn.onHostChanged = store.updateHost;
            conn.onWolInfo = (w) => store.saveWol(w.macs, w.broadcast);
            return conn;
          },
        ),
      ],
      child: MaterialApp(
        title: 'HeDeck',
        debugShowCheckedModeBanner: false,
        theme: buildDeckTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
