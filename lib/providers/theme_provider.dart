import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مظهر التطبيق: فاتح / داكن / حسب النظام.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  bool get isDarkEffective {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    // system — يُفضَّل الاعتماد على MediaQuery في الواجهة
    return false;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('theme_mode') ?? 'system';
      _mode = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString('theme_mode', raw);
    } catch (_) {}
  }

  Future<void> toggleLightDark(BuildContext context) async {
    final brightness = Theme.of(context).brightness;
    await setMode(
      brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
