import 'dart:js_interop';

/// web/index.html đọc `#ghep=123456` từ thanh địa chỉ trước khi Flutter khởi
/// động (Flutter sẽ ghi đè phần sau dấu #), cất vào biến này rồi xoá khỏi
/// thanh địa chỉ để mã không bị lưu lại khi thêm vào Màn hình chính.
@JS('hedeckPairCode')
external String? get _pairCode;

String? pairCodeFromLink() {
  final code = _pairCode ?? '';
  return RegExp(r'^\d{6}$').hasMatch(code) ? code : null;
}

@JS('open')
external void _windowOpen(String url, String target);

/// Mở đường link ở thẻ mới (trên iPhone: mở bằng Safari).
void openLink(String url) => _windowOpen(url, '_blank');

/// web/index.html đọc vé khôi phục ghép cặp (…#hd=…) trước khi Flutter chạy.
@JS('hedeckRestoreToken')
external String? get _restoreToken;

String? restoreTokenFromLink() {
  final t = _restoreToken ?? '';
  return t.isEmpty ? null : t;
}

@JS('hedeckSetLinkToken')
external void _setLinkToken(String? token);

/// Ghi (hoặc xoá, nếu null) vé khôi phục vào phần sau dấu # của đường link.
void setLinkToken(String? token) => _setLinkToken(token);
