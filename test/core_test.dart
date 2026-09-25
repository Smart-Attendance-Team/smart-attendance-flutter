import 'package:flutter_test/flutter_test.dart';
import 'package:smart_attendance/core/l10n/strings.dart';
import 'package:smart_attendance/core/utils/format.dart';
import 'package:smart_attendance/core/widgets/ui.dart';

/// Offline unit tests for core helpers (no backend needed).
void main() {
  group('Format.asInt', () {
    test('parses ints, numeric strings and doubles', () {
      expect(Format.asInt(7), 7);
      expect(Format.asInt(' 42 '), 42);
      expect(Format.asInt(3.9), 3);
    });

    test('returns null for junk', () {
      expect(Format.asInt(null), isNull);
      expect(Format.asInt('abc'), isNull);
      expect(Format.asInt(''), isNull);
    });
  });

  group('Format.head', () {
    test('never throws on short strings', () {
      expect(Format.head('Monday', 3), 'Mon');
      expect(Format.head('-', 3), '-');
      expect(Format.head(null, 3), '');
    });
  });

  group('Format dates', () {
    test('falls back to raw input instead of throwing', () {
      expect(Format.date(null), '-');
      expect(Format.date('not-a-date'), 'not-a-date');
      expect(Format.time(null), '');
    });
  });

  group('Validators', () {
    test('email validation', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('bad'), isNotNull);
      expect(Validators.email('a@test.com'), isNull);
    });

    test('number validation', () {
      expect(Validators.number(''), isNotNull);
      expect(Validators.number('x'), isNotNull);
      expect(Validators.number('12'), isNull);
    });

    test('min length validation', () {
      expect(Validators.min('ab', 3), isNotNull);
      expect(Validators.min('abc', 3), isNull);
    });
  });

  group('Localization', () {
    test('every status code maps without crashing', () {
      for (final s in const [
        'present',
        'late',
        'absent',
        'excused',
        'approved',
        'rejected',
        'pending',
        'whatever',
      ]) {
        expect(trStatus(s), isNotEmpty);
      }
    });

    test('ltr wraps values for bidi safety', () {
      final wrapped = ltr('CS101');
      expect(wrapped.contains('CS101'), isTrue);
      expect(wrapped.length, greaterThan('CS101'.length));
    });
  });
}
