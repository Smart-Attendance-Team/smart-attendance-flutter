import 'package:intl/intl.dart';

/// Small date/time formatting helpers (backend uses ISO 8601 UTC).
abstract class Format {
  static final _day = DateFormat('EEE, d MMM yyyy');
  static final _dayShort = DateFormat('d MMM yyyy');
  static final _time = DateFormat('h:mm a');

  static String date(String? iso) {
    final dt = _parse(iso);
    if (dt == null) return iso ?? '-';
    return _day.format(dt.toLocal());
  }

  static String dateShort(String? iso) {
    final dt = _parse(iso);
    if (dt == null) return iso ?? '-';
    return _dayShort.format(dt.toLocal());
  }

  static String time(String? iso) {
    final dt = _parse(iso);
    if (dt == null) return '';
    return _time.format(dt.toLocal());
  }

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }
}
