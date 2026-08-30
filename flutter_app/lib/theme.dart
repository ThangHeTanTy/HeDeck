import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Bảng màu "console": nền đá xám lạnh, một điểm nhấn tím, xanh cho trạng thái.
class DeckColors {
  static const bg = Color(0xFF0F1218);
  static const surface = Color(0xFF1A1D24);
  static const tile = Color(0xFF232733);
  static const tileDim = Color(0xFF1E222C);
  static const line = Color(0xFF2F343F);
  static const text = Color(0xFFE8EAF0);
  static const muted = Color(0xFF8A90A0);
  static const accent = Color(0xFF7F77DD);
  static const live = Color(0xFF5DCAA5);
  static const warn = Color(0xFFEF9F27);
  static const danger = Color(0xFFE24B4A);

  /// Màu nhấn người dùng chọn được cho từng ô.
  static const swatches = <Color>[
    Color(0xFFAFA9EC), // tím
    Color(0xFF85B7EB), // xanh dương
    Color(0xFF5DCAA5), // ngọc
    Color(0xFF97C459), // lá
    Color(0xFFEF9F27), // hổ phách
    Color(0xFFF0997B), // san hô
    Color(0xFFED93B1), // hồng
    Color(0xFFB4B2A9), // xám
  ];

  static Color swatch(int i) => swatches[i % swatches.length];
}

ThemeData buildDeckTheme() {
  const scheme = ColorScheme.dark(
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
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      titleMedium: TextStyle(color: DeckColors.text, fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(color: DeckColors.text),
      bodySmall: TextStyle(color: DeckColors.muted, fontSize: 11),
      labelSmall: TextStyle(
        color: DeckColors.muted,
        fontSize: 11,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DeckColors.tile,
      hintStyle: const TextStyle(color: DeckColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DeckColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DeckColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DeckColors.accent, width: 2),
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
