import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Current app language. The whole [MaterialApp] rebuilds when it changes.
abstract class AppLocale {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_locale';

  static final ValueNotifier<Locale> current = ValueNotifier(
    const Locale('en'),
  );

  static bool get isArabic => current.value.languageCode == 'ar';

  static Future<void> load() async {
    final saved = await _storage.read(key: _key);
    current.value = saved == 'ar' ? const Locale('ar') : const Locale('en');
  }

  static Future<void> toggle() async {
    final next = isArabic ? const Locale('en') : const Locale('ar');
    current.value = next;
    await _storage.write(key: _key, value: next.languageCode);
  }
}
