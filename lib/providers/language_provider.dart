import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar');
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  /// Keeps Intl's default locale in step with the chosen language so `DateFormat`
  /// and number formatting render in the shop's language. Without this every
  /// date fell back to en_US, showing English dates in the Arabic UI.
  void _applyIntlLocale() {
    Intl.defaultLocale = _locale.languageCode;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locale = Locale(prefs.getString('locale') ?? 'ar');
    } catch (_) {
      _locale = const Locale('ar');
    }
    _applyIntlLocale();
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    _applyIntlLocale();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locale', locale.languageCode);
    } catch (_) {
      // Persisting the choice is best-effort; the session language is applied.
    }
  }
}
