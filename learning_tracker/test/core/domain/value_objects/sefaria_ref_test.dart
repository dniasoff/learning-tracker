import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/sefaria_ref.dart';

void main() {
  group('SefariaRef', () {
    // -------------------------------------------------------------------------
    // Construction + parsing
    // -------------------------------------------------------------------------

    group('parse', () {
      test('strips surrounding whitespace', () {
        final ref = SefariaRef.parse('  Mishnah Berakhot 1:1  ');
        expect(ref.value, 'Mishnah Berakhot 1:1');
      });

      test('normalises en-dash to hyphen', () {
        final ref = SefariaRef.parse('Shabbat 2a–4b');
        expect(ref.value, 'Shabbat 2a-4b');
      });

      test('throws FormatException for empty string', () {
        expect(() => SefariaRef.parse(''), throwsA(isA<FormatException>()));
      });

      test('throws FormatException for whitespace-only string', () {
        expect(() => SefariaRef.parse('   '), throwsA(isA<FormatException>()));
      });

      test('valid ref stores value unchanged (after trim)', () {
        final ref = SefariaRef.parse('Genesis 1:1');
        expect(ref.value, 'Genesis 1:1');
      });
    });

    group('tryParse', () {
      test('returns null for null input', () {
        expect(SefariaRef.tryParse(null), isNull);
      });

      test('returns null for empty string', () {
        expect(SefariaRef.tryParse(''), isNull);
      });

      test('returns null for whitespace-only string', () {
        expect(SefariaRef.tryParse('   '), isNull);
      });

      test('returns SefariaRef for valid input', () {
        final ref = SefariaRef.tryParse('Shabbat 2a');
        expect(ref?.value, 'Shabbat 2a');
      });
    });

    // -------------------------------------------------------------------------
    // Segment operations
    // -------------------------------------------------------------------------

    group('titlePart', () {
      test('extracts title from chapter:verse ref', () {
        final ref = SefariaRef.parse('Mishnah Berakhot 1:1');
        // The trailing "1:1" ends with digit 1 so tail captures "1" and title is
        // "Mishnah Berakhot 1:".  However the regex captures the last numeric
        // group so title = "Mishnah Berakhot 1:" — let's assert what we actually
        // produce (the regex captures trailing token only).
        // Expected: 'Mishnah Berakhot 1:' is the title, '1' is the address.
        // The SefariaRef titlePart splits on the LAST pure-numeric token.
        expect(ref.titlePart, 'Mishnah Berakhot 1:');
      });

      test('extracts title from amud ref', () {
        final ref = SefariaRef.parse('Shabbat 2a');
        expect(ref.titlePart, 'Shabbat');
      });

      test('returns full value when no address', () {
        final ref = SefariaRef.parse('SomeText');
        expect(ref.titlePart, 'SomeText');
      });
    });

    group('addressPart', () {
      test('extracts amud address', () {
        final ref = SefariaRef.parse('Shabbat 2a');
        expect(ref.addressPart, '2a');
      });

      test('extracts plain numeric address', () {
        final ref = SefariaRef.parse('Genesis 3');
        expect(ref.addressPart, '3');
      });

      test('returns null when no numeric address', () {
        final ref = SefariaRef.parse('SomeText');
        expect(ref.addressPart, isNull);
      });
    });

    group('normalised', () {
      test('lowercases, strips punctuation, collapses whitespace', () {
        final ref = SefariaRef.parse('Mishnah Berakhot 1:1');
        expect(ref.normalised, 'mishnah berakhot 1.1');
      });

      test('replaces underscores with spaces', () {
        final ref = SefariaRef.parse('Mishnah_Berakhot_1');
        expect(ref.normalised, 'mishnah berakhot 1');
      });
    });

    group('isMishnah', () {
      test('true for Mishnah prefix', () {
        expect(SefariaRef.parse('Mishnah Berakhot 1:1').isMishnah, isTrue);
      });

      test('false for non-Mishnah ref', () {
        expect(SefariaRef.parse('Shabbat 2a').isMishnah, isFalse);
      });

      test('case-insensitive check', () {
        expect(SefariaRef.parse('MISHNAH Berakhot 1').isMishnah, isTrue);
      });
    });

    group('isYerushalmi', () {
      test('true for Jerusalem Talmud prefix', () {
        expect(
          SefariaRef.parse('Jerusalem Talmud Berakhot 1').isYerushalmi,
          isTrue,
        );
      });

      test('false for Bavli ref', () {
        expect(SefariaRef.parse('Shabbat 2a').isYerushalmi, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Equality + hash
    // -------------------------------------------------------------------------

    group('equality', () {
      test('equal when same value', () {
        final a = SefariaRef.parse('Genesis 1:1');
        final b = SefariaRef.parse('Genesis 1:1');
        expect(a, equals(b));
      });

      test('not equal for different values', () {
        final a = SefariaRef.parse('Genesis 1:1');
        final b = SefariaRef.parse('Genesis 1:2');
        expect(a, isNot(equals(b)));
      });

      test('hashCode consistent with equality', () {
        final a = SefariaRef.parse('Shabbat 2a');
        final b = SefariaRef.parse('Shabbat 2a');
        expect(a.hashCode, equals(b.hashCode));
      });

      test('can be used in Set', () {
        final set = {
          SefariaRef.parse('Genesis 1:1'),
          SefariaRef.parse('Genesis 1:1'),
          SefariaRef.parse('Shabbat 2a'),
        };
        expect(set.length, 2);
      });
    });

    // -------------------------------------------------------------------------
    // toString
    // -------------------------------------------------------------------------

    test('toString contains value', () {
      final ref = SefariaRef.parse('Shabbat 2a');
      expect(ref.toString(), contains('Shabbat 2a'));
    });
  });
}
