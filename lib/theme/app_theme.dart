import 'package:flutter/material.dart';

const Color kInk = Color(0xFF121316);
const Color kBlackBg = Color(0xFF0B0B0D);
const Color kSilver = Color(0xFFC6CBD4);
const Color kSilverBorder = Color(0xFFE2E5EA);
const Color kMutedText = Color(0xFF6B7280);

const String defaultPrimaryHex = '0xFF121316';
const String defaultAccentHex = '0xFFC6CBD4';

Color parseHexColor(String hex, {Color fallback = kInk}) {
  try {
    var h = hex.replaceAll('0x', '').replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return fallback;
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return fallback;
  }
}

ThemeData buildAppTheme({
  Color primary = kInk,
  Color accent = kSilver,
  Brightness brightness = Brightness.light,
}) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? accent : primary,
    secondary: accent,
    surface: isDark ? const Color(0xFF16181D) : Colors.white,
    onSurface: isDark ? const Color(0xFFE8EAED) : kInk,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF1F2F4),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF0B0B0D) : kBlackBg,
      foregroundColor: kSilver,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      iconTheme: const IconThemeData(color: kSilver),
      shape: const Border(
        bottom: BorderSide(color: Color(0xFF1E2025), width: 1),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xFF16181D) : Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A2D34) : Colors.grey.shade200,
        ),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: isDark ? const Color(0xFF12141A) : Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1C1F26) : Colors.white,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A2D34) : kSilverBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? accent : primary,
          width: 1.5,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? accent : primary,
        foregroundColor: isDark ? kBlackBg : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? accent : primary,
        foregroundColor: isDark ? kBlackBg : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? accent : primary,
        side: BorderSide(
          color: (isDark ? accent : primary).withOpacity(0.35),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? accent : primary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor:
          isDark ? const Color(0xFF1C1F26) : const Color(0xFFF3F4F6),
      selectedColor: accent.withOpacity(0.25),
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: isDark ? const Color(0xFFE8EAED) : kInk,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF2A2D34) : kSilverBorder,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor:
          isDark ? const Color(0xFF2A2D34) : const Color(0xFFE8EAEE),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: isDark ? accent : primary,
      foregroundColor: isDark ? kBlackBg : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? const Color(0xFF1C1F26) : kInk,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: ListTileThemeData(
      textColor: isDark ? const Color(0xFFE8EAED) : null,
      iconColor: isDark ? kSilver : null,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xFF16181D) : Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF12141A) : Colors.white,
      indicatorColor: accent.withOpacity(0.3),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? (isDark ? accent : primary)
              : kMutedText,
        ),
      ),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: isDark ? accent : kInk,
      unselectedLabelColor: kMutedText,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? (isDark ? accent : primary)
            : Colors.grey.shade400,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withOpacity(0.5)
            : Colors.grey.shade300,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? (isDark ? accent : primary)
            : Colors.transparent,
      ),
      side: BorderSide(color: Colors.grey.shade400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}
