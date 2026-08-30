import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Danh tính của điện thoại đối với laptop.
///
/// Điện thoại sinh một cặp khoá Ed25519. **Khoá công khai** gửi cho agent lúc
/// ghép cặp; **khoá bí mật** nằm lại trong máy và không bao giờ rời khỏi đó.
/// Agent chỉ giữ khoá công khai, nên kẻ đọc trộm file cấu hình trên laptop
/// cũng không giả mạo được điện thoại.
///
/// Khoá được lưu trong vùng dữ liệu riêng của app. Bản trước dùng
/// `flutter_secure_storage`, nhưng thư viện đó dựa trên EncryptedSharedPrefs —
/// đã bị Google ngừng phát triển và ghi/đọc hỏng lặng lẽ trên Android mới,
/// khiến khoá bị sinh lại và laptop không còn nhận ra máy. Vùng dữ liệu riêng
/// của app không đọc được từ app khác trên máy chưa root, đủ an toàn ở đây và
/// quan trọng hơn là **hoạt động ổn định**.
class DeviceIdentity {
  static const _kSeed = 'hedeck.identity.seed';
  static const _kPublic = 'hedeck.identity.public';

  static final _ed25519 = Ed25519();

  SimpleKeyPair? _pair;
  String? _publicBase64;

  String get publicKeyBase64 => _publicBase64 ?? '';

  bool get isReady => _pair != null;

  /// Lỗi gần nhất khi nạp hoặc sinh khoá. Rỗng nghĩa là không có vấn đề gì.
  String lastError = '';

  /// Bảo đảm có khoá dùng được trước khi cần tới.
  ///
  /// Gọi ngay trước lúc ghép cặp và lúc ký. Bình thường khoá đã sẵn từ
  /// `main()`, nhưng nếu vì lý do nào đó chưa có thì thử lại tại chỗ — tốt
  /// hơn nhiều so với gửi đi một khoá rỗng rồi nhận về lỗi khó hiểu.
  Future<void> ensureReady() async {
    if (isReady && publicKeyBase64.isNotEmpty) return;
    await load();
    if (!isReady || publicKeyBase64.isEmpty) {
      throw StateError(
        lastError.isEmpty
            ? 'Không tạo được khoá thiết bị'
            : 'Không tạo được khoá thiết bị: $lastError',
      );
    }
  }

  /// Nạp cặp khoá đã có, hoặc sinh mới trong lần chạy đầu tiên.
  ///
  /// Trả về `true` nếu phải sinh khoá mới — khi đó mọi laptop đã ghép cặp
  /// trước đó không còn nhận ra máy này nữa.
  Future<bool> load() async {
    lastError = '';
    SharedPreferences? prefs;
    String? seed;
    String? public;

    // Bọc cả bước lấy SharedPreferences: nếu plugin chưa sẵn sàng thì ném lỗi
    // ngay ở đây, và trước kia lỗi đó thoát thẳng ra ngoài làm app chết lặng.
    try {
      prefs = await SharedPreferences.getInstance();
      seed = prefs.getString(_kSeed);
      public = prefs.getString(_kPublic);
    } catch (e) {
      lastError = 'không đọc được bộ nhớ máy ($e)';
      debugPrint('HeDeck: $lastError');
    }

    if (seed != null && public != null) {
      try {
        _pair = await _ed25519.newKeyPairFromSeed(base64Decode(seed));
        // Dựng lại khoá công khai từ hạt giống và đối chiếu. Nếu hai thứ lệch
        // nhau thì dữ liệu đã hỏng, thà làm lại còn hơn ký bằng khoá sai rồi
        // nhận về "chữ ký không hợp lệ" mà không hiểu vì sao.
        final derived = base64Encode((await _pair!.extractPublicKey()).bytes);
        if (derived == public) {
          _publicBase64 = public;
          return false;
        }
        debugPrint('HeDeck: khoá lưu bị lệch, sinh lại cặp khoá mới');
      } catch (e) {
        debugPrint('HeDeck: không đọc được khoá đã lưu ($e), sinh lại');
      }
    }

    try {
      await regenerate();
    } catch (e) {
      lastError = 'sinh khoá thất bại ($e)';
      debugPrint('HeDeck: $lastError');
    }
    return true;
  }

  /// Sinh cặp khoá mới. Gọi khi ghép cặp lần đầu hoặc khi muốn thu hồi
  /// quyền của mọi laptop đã ghép trước đó.
  ///
  /// Khoá luôn được đưa vào bộ nhớ trước, việc lưu xuống đĩa làm sau. Nhờ vậy
  /// máy nào không ghi được vẫn ghép cặp và dùng bình thường trong phiên đó,
  /// thay vì hỏng ngay từ bước đầu.
  Future<void> regenerate() async {
    final pair = await _ed25519.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    final publicKey = await pair.extractPublicKey();

    _pair = pair;
    _publicBase64 = base64Encode(publicKey.bytes);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSeed, base64Encode(seed));
      await prefs.setString(_kPublic, _publicBase64!);

      // Đọc lại ngay để chắc chắn đã ghi được. Ghi hỏng lặng lẽ chính là thứ
      // khiến khoá đổi mỗi lần mở app ở bản trước.
      await prefs.reload();
      if (prefs.getString(_kSeed) == null) {
        lastError = 'không lưu được khoá xuống máy';
        debugPrint('HeDeck: CẢNH BÁO — $lastError, mỗi lần mở app sẽ phải '
            'ghép cặp lại');
      }
    } catch (e) {
      lastError = 'không lưu được khoá ($e)';
      debugPrint('HeDeck: $lastError — vẫn dùng được trong phiên này');
    }
  }

  /// Ký một thông điệp. Trả về chữ ký dạng base64.
  Future<String> sign(String message) async {
    final pair = _pair;
    if (pair == null) throw StateError('Chưa có khoá thiết bị');
    final signature = await _ed25519.sign(utf8.encode(message), keyPair: pair);
    return base64Encode(signature.bytes);
  }

  /// Vân tay ngắn để người dùng đối chiếu với dòng agent in ra.
  Future<String> fingerprint() async {
    final raw = _publicBase64;
    if (raw == null) return '';
    final digest = await Sha256().hash(base64Decode(raw));
    final hex =
        digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final parts = <String>[];
    for (var i = 0; i < 12; i += 4) {
      parts.add(hex.substring(i, i + 4));
    }
    return parts.join(':').toUpperCase();
  }
}
