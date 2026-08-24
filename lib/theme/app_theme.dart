import 'package:flutter/material.dart';

const Color appBrandBackground = Color(0xFF0B0B0D);
const Color appBrandGold = Color(0xFFD8B15A);
const Color appBrandGoldDark = Color(0xFFB8892E);

Color parseHexColor(String hex, {Color fallback = const Color(0xFF2563EB)}) {
  try {
    var h = hex.replaceAll('0x', '').replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return fallback;
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return fallback;
  }
}

ThemeData buildAppTheme({Color primary = const Color(0xFF111827), Color accent = const Color(0xFF2563EB)}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.light,
  ).copyWith(
    primary: accent,
    secondary: appBrandGold,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF9F5EC),
    appBarTheme: const AppBarTheme(
      backgroundColor: appBrandBackground,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: appBrandGoldDark, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: appBrandGold.withOpacity(0.2),
      side: BorderSide.none,
      labelStyle: const TextStyle(color: Color(0xFF0F172A)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE9DDC6)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
  );
}
