import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
import 'screens/splash_screen.dart';
import 'services/deck_connection.dart';
import 'services/device_identity.dart';
import 'services/store.dart';
import 'theme.dart';
import 'widgets/clown_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
                Text(t('HeDeck gặp lỗi khi dựng giao diện'),
                    style: const TextStyle(
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

  // Lỗi bất đồng bộ không ai bắt: ghi ra log thay vì chết lặng.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('HeDeck: LỖI CHƯA BẮT — $error\n$stack');
    return true;
  };

  // Vẽ ngay lập tức, chưa chờ gì cả. Trước đây main() chờ đọc cấu hình, nạp
  // khoá, khoá xoay màn hình... rồi mới runApp: chỉ cần một bước treo trên
  // điện thoại thật là Flutter không bao giờ vẽ khung hình nào — người dùng
  // nhìn nền trắng của Android mãi mãi, không logo, không lỗi, không log.
  runApp(const BootApp());
}

/// Màn hình khởi động: hiện logo ngay, rồi nạp từng bước ở phía sau. Bước
/// nào lỗi hoặc treo quá lâu thì hiện tên bước và lỗi lên màn hình, kèm nút
/// thử lại — không bao giờ để một màn hình trống không lời giải thích.
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  Store? _store;
  DeviceIdentity? _identity;
  String _step = '';
  String? _error;
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  /// Chạy một bước có giới hạn thời gian và ghi log trước/sau, để đọc log là
  /// biết ngay app dừng ở đâu.
  Future<T> _run<T>(String step, Future<T> Function() fn,
      {Duration limit = const Duration(seconds: 10)}) async {
    if (mounted) setState(() => _step = step);
    debugPrint('HeDeck: khởi động — $step…');
    final started = DateTime.now();
    final result = await fn().timeout(limit,
        onTimeout: () => throw TimeoutException(
            t('"{0}" không xong sau {1} giây', [step, limit.inSeconds])));
    debugPrint('HeDeck: khởi động — $step xong '
        '(${DateTime.now().difference(started).inMilliseconds} ms)');
    return result;
  }

  Future<void> _boot() async {
    setState(() {
      _error = null;
      _slow = false;
    });
    // Chỉ hiện dòng "Đang …" khi khởi động chậm bất thường, máy nhanh thì
    // người dùng chỉ thấy logo rồi vào thẳng.
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _slow = true);
    });

    // Không chờ: xoay màn hình, toàn màn hình là chuyện trang trí, hỏng thì
    // app vẫn phải chạy. Giữ màn hình sáng do MainActivity đặt cờ
    // FLAG_KEEP_SCREEN_ON, không dùng plugin wakelock.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]).catchError(
        (Object e) => debugPrint('HeDeck: không khoá được hướng ($e)'));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
        .catchError((Object e) =>
            debugPrint('HeDeck: không ẩn được thanh hệ thống ($e)'));

    try {
      final store = Store();
      await _run(t('Đọc cấu hình đã lưu'), store.load);
      debugPrint('HeDeck: đã ghép cặp=${store.isPaired} '
          'host="${store.host}" trang=${store.pages.length} '
          'bố cục=${Store.cols}x${store.rows}');

      // Cặp khoá Ed25519 của máy này. Sinh trong lần chạy đầu, sau đó nằm
      // yên trong vùng dữ liệu riêng của app.
      final identity = DeviceIdentity();
      final freshKey = await _run(t('Nạp khoá điện thoại'), identity.load,
          limit: const Duration(seconds: 20));

      // Vân tay khoá hiện tại phải trùng với vân tay đã lưu lúc ghép cặp.
      // Lệch nghĩa là khoá đã đổi (cài lại app, dữ liệu hỏng), thiết bị chắc
      // chắn không nhận ra nữa — dọn luôn thay vì để app thử kết nối rồi nhận
      // về lỗi chữ ký khó hiểu.
      final current = await _run(t('Tính vân tay khoá'), identity.fingerprint);
      debugPrint('HeDeck: vân tay khoá điện thoại = $current');
      if (store.isPaired &&
          (freshKey || (current.isNotEmpty && current != store.fingerprint))) {
        debugPrint('HeDeck: khoá đã đổi (lưu ${store.fingerprint}), '
            'cần ghép cặp lại');
        await _run(t('Xoá ghép cặp cũ'), store.forgetHost);
      }

      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _store = store;
        _identity = identity;
      });
    } catch (e, st) {
      _slowTimer?.cancel();
      debugPrint('HeDeck: KHỞI ĐỘNG HỎNG ở "$_step" — $e\n$st');
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store, identity = _identity;
    if (store != null && identity != null) {
      return DeckApp(store: store, identity: identity);
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildDeckTheme(),
      home: _BootScreen(
        step: _step,
        slow: _slow,
        error: _error,
        onRetry: _boot,
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  final String step;
  final bool slow;
  final String? error;
  final VoidCallback onRetry;

  const _BootScreen({
    required this.step,
    required this.slow,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Cùng nền trắng và chú hề như màn hình mở đầu, nên lúc chuyển sang
    // không thấy giật.
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ClownLogo(size: 96, shadow: false),
                const SizedBox(height: 14),
                Text('HeDeck',
                    style: TextStyle(
                        color: DeckColors.bg,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                if (error != null) ...[
                  Text(t('Không khởi động được ở bước: {0}', [step]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFB3261E),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF444444),
                            fontSize: 12,
                            height: 1.5)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: onRetry, child: Text(t('Thử lại'))),
                  const SizedBox(height: 8),
                  Text(
                      t('Lặp lại nhiều lần thì chụp màn hình này gửi Hề IT.'),
                      style: const TextStyle(color: Color(0xFF777777), fontSize: 11)),
                ] else if (slow)
                  Text('$step…',
                      style: const TextStyle(
                          color: Color(0xFF777777), fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      // Đổi chủ đề thì dựng lại ThemeData (nút, ô nhập, nền trang...).
      child: Selector<Store, bool>(
        selector: (_, s) => s.dark,
        builder: (_, __, ___) => MaterialApp(
          title: 'HeDeck',
          debugShowCheckedModeBanner: false,
          theme: buildDeckTheme(),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
