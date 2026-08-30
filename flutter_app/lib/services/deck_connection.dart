import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/deck.dart';
import 'device_identity.dart';
import 'discovery.dart';

enum ConnState {
  offline,
  connecting,
  online,
  failed,

  /// Agent không nhận ra thiết bị này nữa. Thử lại bao nhiêu lần cũng vô ích,
  /// phải ghép cặp lại — nên trạng thái này tách riêng khỏi `failed`.
  needsPairing,
}

class PairResult {
  final String deviceId;
  final String hostName;
  final String fingerprint;
  PairResult(this.deviceId, this.hostName, this.fingerprint);
}

/// Kênh liên lạc duy nhất tới agent trên laptop.
class DeckConnection extends ChangeNotifier {
  DeckConnection(this.identity);

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _ping;
  Timer? _retry;
  Timer? _catalogPoll;

  ConnState state = ConnState.offline;
  String? lastError;
  int? latencyMs;
  String hostName = '';

  Map<String, AppStatus> statuses = {};

  /// Agent đang quét Start Menu. Danh mục sẽ tự đến khi xong.
  bool catalogLoading = false;

  /// Số lần đã hỏi lại danh mục mà vẫn chưa có. Dùng để biết khi nào nên
  /// nhắc người dùng xem cửa sổ agent.
  int catalogPolls = 0;

  bool get catalogStuck => catalogLoading && catalogPolls >= 7;

  /// App vừa được bấm mở, đang chờ cửa sổ xuất hiện. Ô sẽ viền tím.
  final Map<String, Timer> _pending = {};

  /// Sau ngần này mà agent chưa báo app có cửa sổ thì bỏ trạng thái chờ.
  static const pendingTimeout = Duration(seconds: 15);
  List<RemoteApp> catalog = [];
  Map<String, RemoteApp> catalogById = {};

  final DeviceIdentity identity;

  String _host = '';
  int _port = 8787;
  String _deviceId = '';

  /// Gọi khi tự dò lại thấy laptop ở địa chỉ IP mới, để lưu lại.
  void Function(String host, int port)? onHostChanged;

  /// Số lần thử liên tiếp không thành. Đủ nhiều thì đi dò lại địa chỉ.
  int _misses = 0;

  /// Thời điểm sẽ thử lại, để giao diện đếm ngược cho người dùng thấy.
  DateTime? retryAt;

  int get retryInSeconds {
    final at = retryAt;
    if (at == null) return 0;
    final left = at.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }
  bool _stopped = true;
  int _backoff = 1;
  Completer<PairResult>? _pairing;

  bool get isOnline => state == ConnState.online;

  AppStatus statusOf(String? appId) =>
      appId == null ? const AppStatus() : (statuses[appId] ?? const AppStatus());

  bool isPending(String? appId) => appId != null && _pending.containsKey(appId);

  void _markPending(String appId) {
    _pending[appId]?.cancel();
    _pending[appId] = Timer(pendingTimeout, () {
      _pending.remove(appId);
      notifyListeners();
    });
    notifyListeners();
  }

  void _clearPending(String appId) {
    final timer = _pending.remove(appId);
    timer?.cancel();
  }

  // ---------------------------------------------------------------- ghép cặp

  /// Mở kết nối tạm, đổi mã 6 số lấy token dài hạn.
  Future<PairResult> pair({
    required String host,
    required int port,
    required String code,
    required String deviceId,
    required String deviceName,
  }) async {
    // Ghép cặp là đường thoát duy nhất khỏi needsPairing, nên dọn trạng thái
    // ngay từ đầu.
    _stopped = false;
    if (state == ConnState.needsPairing) _setState(ConnState.connecting);

    // Khoá phải sẵn sàng TRƯỚC khi mở kết nối. Trước đây nếu vì lý do nào đó
    // khoá chưa có, app vẫn gửi đi chuỗi rỗng và agent trả về "Thiếu khoá
    // công khai" — thông báo đúng nhưng không chỉ ra nguyên nhân ở đâu.
    await identity.ensureReady();

    await _teardown();
    _pairing = Completer<PairResult>();
    try {
      final ch = await _open(host, port);
      _bind(ch);
      _send({
        't': 'pair',
        'code': code,
        'device_id': deviceId,
        'device_name': deviceName,
        // Chỉ khoá công khai được gửi đi. Khoá bí mật ở lại trong máy.
        'pubkey': identity.publicKeyBase64,
      });
      final result = await _pairing!.future.timeout(const Duration(seconds: 12));
      _host = host;
      _port = port;
      _deviceId = result.deviceId;
      _stopped = false;
      _backoff = 1;
      _misses = 0;
      retryAt = null;
      lastError = null;
      _setState(ConnState.online);
      _startPing();
      requestCatalog();
      return result;
    } finally {
      _pairing = null;
    }
  }

  // ----------------------------------------------------------- kết nối thường

  Future<void> start({
    required String host,
    required int port,
    required String deviceId,
  }) async {
    // Đã biết agent không nhận ra thiết bị này thì thử lại chỉ tốn công và
    // làm agent đếm thêm một lần thất bại. Chờ người dùng ghép cặp lại.
    if (state == ConnState.needsPairing) return;

    _host = host;
    _port = port;
    _deviceId = deviceId;
    _stopped = false;
    _backoff = 1;
    _misses = 0;
    lastError = null;

    // Thử địa chỉ đã lưu trước — gần như luôn đúng và nhanh hơn dò tìm.
    await _connectOnce();
    if (isOnline || _stopped || _isTunnelled) return;

    // Không được thì dò ngay lập tức thay vì đợi ba lần hụt. Laptop đổi IP là
    // chuyện thường, không việc gì bắt người dùng chờ cả phút.
    _retry?.cancel();
    await _rediscoverThenConnect();
  }

  Future<void> stop() async {
    _stopped = true;
    _retry?.cancel();
    await _teardown();
    _setState(ConnState.offline);
  }

  Future<void> _connectOnce() async {
    if (_stopped) return;
    _setState(ConnState.connecting);
    try {
      final ch = await _open(_host, _port);
      _bind(ch);
      await _sendAuth();
      _startPing();
    } catch (e) {
      lastError = _friendly(e);
      _setState(ConnState.failed);
      _scheduleRetry();
    }
  }

  Future<WebSocketChannel> _open(String host, int port) async {
    final ch = IOWebSocketChannel.connect(
      Uri.parse('ws://$host:$port'),
      connectTimeout: const Duration(seconds: 6),
      pingInterval: const Duration(seconds: 15),
    );
    await ch.ready;
    return ch;
  }

  void _bind(WebSocketChannel ch) {
    _ch = ch;
    _sub = ch.stream.listen(
      _onMessage,
      onDone: _onClosed,
      onError: (e) {
        lastError = _friendly(e);
        _onClosed();
      },
      cancelOnError: true,
    );
  }

  Future<void> _sendAuth() async {
    await identity.ensureReady();
    final ts = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final nonce = _randomHex(12);
    final signature = await identity.sign('$_deviceId|$ts|$nonce');
    _send({
      't': 'auth',
      'device_id': _deviceId,
      'ts': ts,
      'nonce': nonce,
      'sig': signature,
      // Gửi kèm để agent đối chiếu: khoá lệch thì nó nói thẳng là cần ghép
      // cặp lại, thay vì báo chữ ký sai rồi cả hai bên cùng đoán.
      'pubkey': identity.publicKeyBase64,
    });
  }

  // ------------------------------------------------------------------- lệnh

  void _send(Map<String, dynamic> msg) {
    final ch = _ch;
    if (ch == null) return;
    ch.sink.add(jsonEncode(msg));
  }

  void requestCatalog() => _send({'t': 'catalog'});

  /// Agent báo đang quét thì cứ vài giây hỏi lại một lần. Nếu gói tin thông
  /// báo hoàn tất bị lạc vì lý do nào đó, app vẫn tự thoát khỏi cảnh chờ.
  void _startCatalogPoll() {
    _catalogPoll?.cancel();
    _catalogPoll = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!isOnline || !catalogLoading) {
        t.cancel();
        _catalogPoll = null;
        return;
      }
      requestCatalog();
    });
  }

  void rescan() => _send({'t': 'rescan'});

  void launch(String appId, {bool toggle = true}) {
    // Chỉ đánh dấu chờ khi app thật sự chưa chạy; bấm vào app đang chạy là
    // thu nhỏ chứ không phải mở, không nên đổi viền sang tím.
    if (!statusOf(appId).running) _markPending(appId);
    _send({'t': 'launch', 'app_id': appId, 'toggle': toggle});
  }

  void close(String appId) {
    _clearPending(appId);
    _send({'t': 'close', 'app_id': appId});
    notifyListeners();
  }

  void macro(List<String> keys) => _send({'t': 'macro', 'keys': keys});

  void media(String action) => _send({'t': 'media', 'action': action});

  void appVolume(String appId, String action) =>
      _send({'t': 'app_volume', 'app_id': appId, 'action': action});

  /// Báo cho agent biết những app nào đang có ô âm lượng, để nó chỉ đo mức
  /// âm lượng của bấy nhiêu app thay vì tất cả.
  void watchVolume(Iterable<String> appIds) =>
      _send({'t': 'watch_volume', 'app_ids': appIds.toList()});

  // -------------------------------------------------------------- nhận tin

  void _onMessage(dynamic raw) {
    late final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['t']) {
      case 'paired':
        _pairing?.complete(PairResult(
          msg['device_id'] as String,
          msg['host_name'] as String? ?? '',
          msg['fingerprint'] as String? ?? '',
        ));
        hostName = msg['host_name'] as String? ?? '';
        break;

      case 'auth_ok':
        hostName = msg['host_name'] as String? ?? hostName;
        lastError = null;
        _backoff = 1;
        _misses = 0;
        retryAt = null;
        _setState(ConnState.online);
        requestCatalog();
        break;

      case 'catalog_pending':
        catalogLoading = true;
        catalogPolls++;
        _startCatalogPoll();
        notifyListeners();
        break;

      case 'catalog':
        catalogLoading = false;
        catalogPolls = 0;
        _catalogPoll?.cancel();
        _catalogPoll = null;
        catalog = (msg['apps'] as List)
            .map((e) => RemoteApp.fromJson(e as Map<String, dynamic>))
            .toList();
        catalogById = {for (final a in catalog) a.id: a};
        notifyListeners();
        break;

      case 'volume':
        final id = msg['app_id'] as String?;
        if (id != null) {
          final old = statuses[id] ?? const AppStatus();
          statuses[id] = AppStatus(
            running: old.running,
            windows: old.windows,
            volume: (msg['volume'] as num?)?.toDouble() ?? old.volume,
            muted: msg['muted'] as bool? ?? old.muted,
          );
          notifyListeners();
        }
        break;

      case 'status':
        final apps = (msg['apps'] as Map).cast<String, dynamic>();
        statuses = {
          for (final e in apps.entries)
            e.key: AppStatus(
              running: (e.value as Map)['running'] as bool? ?? false,
              windows: (e.value as Map)['windows'] as int? ?? 0,
              volume: ((e.value as Map)['volume'] as num?)?.toDouble() ?? -1,
              muted: (e.value as Map)['muted'] as bool? ?? false,
            )
        };
        // Cửa sổ đã hiện ra thì thôi chờ: viền tím nhường chỗ cho viền xanh.
        for (final id in _pending.keys.toList()) {
          if (statuses[id]?.running == true) _clearPending(id);
        }
        notifyListeners();
        break;

      case 'pong':
        final sent = msg['ts'];
        if (sent is int) {
          latencyMs = DateTime.now().millisecondsSinceEpoch - sent;
          notifyListeners();
        }
        break;

      case 'error':
        lastError = msg['msg'] as String? ?? 'Lỗi không rõ';
        if (_pairing != null && !_pairing!.isCompleted) {
          _pairing!.completeError(StateError(lastError!));
        }
        if (msg['fatal'] == true) {
          final code = msg['code'] as String? ?? '';
          final text = lastError ?? '';
          final unknownDevice = code == 'unknown_device' ||
              code == 'key_changed' ||
              code == 'bad_signature' ||
              (code.isEmpty &&
                  (text.contains('chưa được ghép cặp') ||
                      text.contains('Chữ ký') ||
                      text.contains('Chưa xác thực')));
          if (unknownDevice) {
            // Ghép cặp lại là việc của người dùng, thử lại tự động vô nghĩa.
            _stopped = true;
            _setState(ConnState.needsPairing);
          } else {
            // Bị chặn tạm, quá tải... đều là tình huống sẽ tự hết. Cứ thử lại.
            _setState(ConnState.failed);
          }
        } else {
          notifyListeners();
        }
        break;
    }
  }

  void _onClosed() {
    _ping?.cancel();
    _ch = null;
    latencyMs = null;
    statuses = {};
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    _catalogPoll?.cancel();
    _catalogPoll = null;
    catalogLoading = false;
    catalogPolls = 0;

    // Agent gửi lỗi rồi đóng socket ngay, nên hàm này chạy ngay sau khi ta
    // vừa đặt needsPairing. Không được ghi đè: mất trạng thái đó thì app coi
    // như mất kết nối bình thường và lại thử lại vô ích, còn người dùng thì
    // không bao giờ thấy nút "Ghép cặp lại".
    if (state == ConnState.needsPairing) {
      notifyListeners();
      return;
    }

    if (_stopped) {
      _setState(ConnState.offline);
    } else {
      _setState(ConnState.connecting);
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    final wait = Duration(seconds: _backoff);
    _backoff = min(_backoff * 2, 20);
    _misses++;
    retryAt = DateTime.now().add(wait);
    notifyListeners();
    // Sau vài lần hụt, nhiều khả năng router đã cấp IP khác cho laptop.
    // Đi dò lại bằng mDNS thay vì kiên trì gọi vào địa chỉ đã chết.
    _retry = Timer(wait, _misses % 3 == 0 ? _rediscoverThenConnect : _connectOnce);
  }

  /// Địa chỉ vòng lặp nội bộ nghĩa là đang đi qua đường hầm `adb reverse`
  /// (máy ảo hoặc cáp USB). Địa chỉ LAN dò được sẽ không tới nơi, nên tuyệt
  /// đối không ghi đè.
  bool get _isTunnelled =>
      _host == '127.0.0.1' || _host == 'localhost' || _host.startsWith('127.');

  Future<void> _rediscoverThenConnect() async {
    if (_stopped) return;
    if (_isTunnelled) {
      await _connectOnce();
      return;
    }
    try {
      final hosts = await discoverHosts(timeout: const Duration(seconds: 3));
      if (hosts.isNotEmpty) {
        final found = hosts.first;
        if (found.ip != _host || found.port != _port) {
          _host = found.ip;
          _port = found.port;
          onHostChanged?.call(_host, _port);
          _backoff = 1;
        }
      }
    } catch (_) {
      // Dò không ra cũng không sao, cứ thử địa chỉ cũ.
    }
    await _connectOnce();
  }

  /// Thử lại ngay, bỏ qua thời gian chờ. Dùng cho nút bấm tay và lúc app
  /// quay lại tiền cảnh.
  Future<void> reconnectNow() async {
    if (state == ConnState.needsPairing || isOnline) return;
    _retry?.cancel();
    _backoff = 1;
    _misses = 0;
    _stopped = false;
    await _connectOnce();
  }

  void _startPing() {
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 5), (_) {
      _send({'t': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch});
    });
  }

  Future<void> _teardown() async {
    _ping?.cancel();
    _catalogPoll?.cancel();
    _catalogPoll = null;
    await _sub?.cancel();
    _sub = null;
    await _ch?.sink.close();
    _ch = null;
  }

  void _setState(ConnState s) {
    state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopped = true;
    _retry?.cancel();
    _teardown();
    super.dispose();
  }

  // ---------------------------------------------------------------- tiện ích

  static String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('khoá thiết bị')) {
      // Giữ nguyên câu chữ từ DeviceIdentity, nó đã nói rõ nguyên nhân.
      return s.replaceFirst(RegExp(r'^\w+Error: '), '');
    }
    if (s.contains('refused')) return 'Laptop từ chối kết nối — agent chưa chạy?';
    if (s.contains('mạng nội bộ')) return 'Agent chỉ nhận kết nối từ mạng nội bộ';
    if (s.contains('timed out') || s.contains('timeout')) {
      return 'Hết thời gian chờ — kiểm tra Wi-Fi và tường lửa';
    }
    if (s.contains('unreachable') || s.contains('Network')) {
      return 'Không tới được máy — hai thiết bị có cùng Wi-Fi không?';
    }
    return 'Không kết nối được';
  }

  static String _randomHex(int bytes) {
    final rnd = Random.secure();
    return List.generate(bytes, (_) => rnd.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
