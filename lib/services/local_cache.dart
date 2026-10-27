import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// تخزين مؤقت محلي بسيط (JSON) لتسريع أول فتح وعرض البيانات عند انقطاع الشبكة.
class LocalCache {
  LocalCache._();
  static final instance = LocalCache._();

  static const _prefix = 'bb_cache_v1_';

  Future<void> putJson(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(value));
      await prefs.setString(
        '$_prefix${key}_at',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  Future<Object?> getJson(String key, {Duration? maxAge}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      if (maxAge != null) {
        final at = DateTime.tryParse(prefs.getString('$_prefix${key}_at') ?? '');
        if (at != null && DateTime.now().difference(at) > maxAge) {
          return null;
        }
      }
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
      await prefs.remove('$_prefix${key}_at');
    } catch (_) {}
  }

  String shopKey(String shopId, String name) => '${shopId}_$name';
}
