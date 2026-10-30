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
