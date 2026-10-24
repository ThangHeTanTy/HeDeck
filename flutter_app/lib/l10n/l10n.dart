import 'en.dart';

/// Ngôn ngữ giao diện của app.
enum AppLang {
  vi('Tiếng Việt', '🇻🇳'),
  en('English', '🇬🇧');

  final String label;
  final String flag;
  const AppLang(this.label, this.flag);

  static AppLang fromCode(String? code) =>
      AppLang.values.firstWhere((l) => l.name == code, orElse: () => AppLang.vi);
}

/// Ngôn ngữ đang dùng. Store đặt giá trị này lúc khởi động và mỗi khi người
/// dùng đổi ngôn ngữ, rồi dựng lại giao diện.
class L10n {
  static AppLang current = AppLang.vi;
}

/// Dịch một câu. Câu tiếng Việt viết thẳng trong code chính là khoá tra:
/// đọc code vẫn hiểu ngay, và câu nào chưa có bản dịch thì hiện nguyên tiếng
/// Việt chứ không bao giờ hiện trống.
///
/// Giá trị thay đổi đặt bằng {0}, {1}... theo thứ tự trong [args]:
/// `t('Đã tắt {0}', [name])`.
String t(String vi, [List<Object?> args = const []]) {
  var s = L10n.current == AppLang.en ? (en[vi] ?? vi) : vi;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
