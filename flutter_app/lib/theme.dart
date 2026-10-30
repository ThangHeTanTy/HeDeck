import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Một bộ màu đầy đủ cho một chủ đề.
class DeckPalette {
  final Brightness brightness;
  final Color bg, surface, tile, tileDim, line, text, muted;
  final Color accent, live, warn, danger;

  /// Màu nhấn người dùng chọn được cho từng ô, theo thứ tự cố định.
  final List<Color> swatches;

  const DeckPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.tile,
    required this.tileDim,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.live,
    required this.warn,
    required this.danger,
    required this.swatches,
  });

  /// Chủ đề tối "console": nền đá xám lạnh, một điểm nhấn tím, xanh cho
  /// trạng thái. Đây là màu gốc của app.
  static const dark = DeckPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0F1218),
    surface: Color(0xFF1A1D24),
    tile: Color(0xFF232733),
    tileDim: Color(0xFF1E222C),
    line: Color(0xFF2F343F),
    text: Color(0xFFE8EAF0),
    muted: Color(0xFF8A90A0),
    accent: Color(0xFF7F77DD),
    live: Color(0xFF5DCAA5),
    warn: Color(0xFFEF9F27),
    danger: Color(0xFFE24B4A),
    swatches: [
      Color(0xFFAFA9EC), // tím
      Color(0xFF85B7EB), // xanh dương
      Color(0xFF5DCAA5), // ngọc
      Color(0xFF97C459), // lá
      Color(0xFFEF9F27), // hổ phách
      Color(0xFFF0997B), // san hô
      Color(0xFFED93B1), // hồng
      Color(0xFFB4B2A9), // xám
    ],
  );

  /// Chủ đề sáng. Không chỉ đảo nền: tám màu ô của bản tối chỉ đạt khoảng
  /// 2,1:1 trên nền trắng, icon nhạt nhoà. Bộ màu dưới đây cùng tông nhưng
  /// đậm hơn — icon từ 3,4:1, chữ từ 4,9:1 trên ô trắng (đo theo WCAG).
  static const light = DeckPalette(
    brightness: Brightness.light,
    bg: Color(0xFFEEF1F6),
    surface: Color(0xFFFFFFFF),
    tile: Color(0xFFFFFFFF),
    tileDim: Color(0xFFF4F6F9),
    line: Color(0xFFDDE1E8),
    text: Color(0xFF1B1F29),
    muted: Color(0xFF5F6675),
    accent: Color(0xFF5B50D6),
    live: Color(0xFF0E7F5E),
    warn: Color(0xFFA65F00),
    danger: Color(0xFFC42F2F),
    swatches: [
      Color(0xFF6E63DD), // tím
      Color(0xFF2F7BC4), // xanh dương
      Color(0xFF12937A), // ngọc
      Color(0xFF4E8F22), // lá
      Color(0xFFC27A00), // hổ phách
      Color(0xFFD05A33), // san hô
      Color(0xFFC7477F), // hồng
      Color(0xFF77756C), // xám
    ],
  );
}

/// Màu đang dùng, theo chủ đề hiện tại. Mọi nơi trong app gọi
/// `DeckColors.xxx`; Store đổi chủ đề bằng [use] rồi dựng lại giao diện.
///
/// Là getter chứ không phải hằng, nên không đặt được trong biểu thức
/// `const` — đó là cái giá để đổi chủ đề lúc đang chạy.
class DeckColors {
  static DeckPalette _p = DeckPalette.dark;

  static void use(DeckPalette palette) => _p = palette;

  static bool get isDark => _p.brightness == Brightness.dark;

  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get tile => _p.tile;
  static Color get tileDim => _p.tileDim;
  static Color get line => _p.line;
  static Color get text => _p.text;
  static Color get muted => _p.muted;
  static Color get accent => _p.accent;
  static Color get live => _p.live;
  static Color get warn => _p.warn;
  static Color get danger => _p.danger;

  static List<Color> get swatches => _p.swatches;

  static Color swatch(int i) => swatches[i % swatches.length];
}

ThemeData buildDeckTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: DeckColors.accent,
    brightness: DeckColors.isDark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: DeckColors.accent,
    secondary: DeckColors.live,
    surface: DeckColors.surface,
    error: DeckColors.danger,
    onPrimary: Colors.white,
    onSurface: DeckColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: DeckColors.bg,
    // Bản web không có font hệ thống: Flutter tự tải Roboto từ Google, mạng
    // chập chờn là mất hết chữ. Đóng gói sẵn Roboto (đủ dấu tiếng Việt) cho
    // web; Android vẫn dùng Roboto của máy như trước.
    fontFamily: kIsWeb ? 'HeDeckRoboto' : 'Roboto',
    textTheme: TextTheme(
      titleMedium: TextStyle(color: DeckColors.text, fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(color: DeckColors.text),
      bodySmall: TextStyle(color: DeckColors.muted, fontSize: 11),
      labelSmall: TextStyle(
        color: DeckColors.muted,
        fontSize: 11,
        fontFeatures: [const FontFeature.tabularFigures()],
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DeckColors.tile,
      hintStyle: TextStyle(color: DeckColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: DeckColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: DeckColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: DeckColors.accent, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DeckColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}
