import 'package:intl/intl.dart';

import '../l10n/app_locale.dart';

/// Date/time helpers (backend uses ISO 8601 UTC).
/// Never throws: any failure falls back to the raw string,
/// so a bad date can never crash a page.
abstract class Format {
  static String _locale() => AppLocale.isArabic ? 'ar' : 'en';

  static String date(String? iso) {
    try {
      final dt = _parse(iso);
      if (dt == null) return iso ?? '-';
      return DateFormat('EEE, d MMM yyyy', _locale()).format(dt.toLocal());
    } catch (_) {
      return iso ?? '-';
    }
  }

  static String dateShort(String? iso) {
    try {
      final dt = _parse(iso);
      if (dt == null) return iso ?? '-';
      return DateFormat('d MMM yyyy', _locale()).format(dt.toLocal());
    } catch (_) {
      return iso ?? '-';
    }
  }

  static String time(String? iso) {
    try {
      final dt = _parse(iso);
      if (dt == null) return '';
      return DateFormat('h:mm a', _locale()).format(dt.toLocal());
    } catch (_) {
      return '';
    }
  }

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  /// Safe int conversion for backend ids that should be numbers
  /// (never throws on String/null/missing values).
  static int? asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  /// Safe prefix that never throws on short strings.
  static String head(String? s, int n) {
    final v = s ?? '';
    return v.length <= n ? v : v.substring(0, n);
  }
}
