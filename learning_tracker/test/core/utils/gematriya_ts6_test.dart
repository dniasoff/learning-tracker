// Regression tests for TS-6: Gematriya.forYear drops the thousands component
// for Hebrew years >= 6000.
//
// Root cause: the existing Gematriya.forNumber(n) only handles 1..999 and
// throws for n > 999.  Any code that calls forNumber(year % 1000) when the
// Hebrew year is >= 6000 silently drops the thousands digit, producing a year
// that reads as if it belongs to the previous millennium (6120 → "ק״כ" = 120,
// which the reader interprets as year 5120 — ~666 years in the past).
//
// Fix: add Gematriya.forYear(int hebrewYear) that:
//   - For years 1..5999 (current convention): omits the thousands geresh
//     letter so the abbreviated form matches traditional usage (5786 → "תשפ״ו").
//   - For years >= 6000: prefixes the geresh-marked thousands letter so the
//     year reads unambiguously (6120 → "ו׳קכ", 6000 → "ו׳").
//
// The geresh character used is U+05F3 (HEBREW PUNCTUATION GERESH) = '׳'.
// Gershayim between the last two letters is standard gematriya punctuation;
// forYear should insert the gershayim (U+05F4 = '״') in the sub-1000 part.
@Tags(['core', 'utils', 'ts6'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/utils/gematriya.dart';

void main() {
  group('Gematriya.forYear — TS-6 regression: thousands component', () {
    // ── Years < 6000 (current millennium, thousands omitted by convention) ──

    test('year 5786 (current year) omits the ה thousands letter', () {
      // Traditional abbreviated form: drop the ה (5000) prefix.
      // 786 = תשפ"ו
      expect(
        Gematriya.forYear(5786),
        'תשפ״ו',
        reason:
            'Hebrew year 5786 must render as תשפ״ו (abbreviating the '
            'thousands ה׳ per current-era convention)',
      );
    });

    test('year 5785 abbreviates correctly', () {
      // 785 = תשפ"ה
      expect(Gematriya.forYear(5785), 'תשפ״ה');
    });

    test('year 5000 (boundary) abbreviates to single-letter ה omitted', () {
      // 5000 alone in abbreviated form → omit thousands; remainder 0 is
      // handled as empty string → just "ה" for the millennium omitted convention.
      // The sub-1000 part is 0 — forYear returns the empty abbreviation or
      // a single-char representation for round-millennium years.
      // We only assert the thousands component is NOT present:
      final result = Gematriya.forYear(5000);
      expect(
        result.contains('ה'),
        isFalse,
        reason: 'Abbreviated Hebrew year 5000 must NOT contain the thousands ה',
      );
    });

    // ── Years >= 6000 (next millennium, thousands MUST be included) ──

    test('year 6000 includes geresh-marked ו thousands letter', () {
      // 6000 = ו׳ (just the thousands, no sub-1000 part)
      final result = Gematriya.forYear(6000);
      expect(
        result.startsWith('ו׳') || result == 'ו׳',
        isTrue,
        reason: 'Hebrew year 6000 must include the ו׳ thousands prefix',
      );
    });

    test('year 6120 includes ו׳ prefix (not just קכ)', () {
      // Root-cause regression: before the fix year 6120 returned 'ק״כ' (= 120)
      // which was misread as year 5120.
      // After fix it must return 'ו׳ק״כ' (6000 + 120).
      final result = Gematriya.forYear(6120);
      expect(
        result.contains('ו׳'),
        isTrue,
        reason: 'Year 6120 must contain the ו׳ thousands prefix, got: $result',
      );
      // The sub-1000 part is 120 = ק״כ (קכ with gershayim inserted).
      // Check that ק and כ are both present (with punctuation between them).
      expect(
        result.contains('ק') && result.contains('כ'),
        isTrue,
        reason:
            'Year 6120 must contain ק and כ for the 120 remainder, got: $result',
      );
    });

    test('year 6001 includes ו׳ prefix', () {
      final result = Gematriya.forYear(6001);
      expect(
        result.contains('ו׳'),
        isTrue,
        reason: 'Year 6001 must contain the ו׳ thousands prefix, got: $result',
      );
    });

    test('year 6900 includes ו׳ prefix', () {
      final result = Gematriya.forYear(6900);
      expect(
        result.contains('ו׳'),
        isTrue,
        reason: 'Year 6900 must contain the ו׳ thousands prefix, got: $result',
      );
    });

    test('year 7000 includes ז׳ prefix', () {
      final result = Gematriya.forYear(7000);
      expect(
        result.startsWith('ז׳') || result == 'ז׳',
        isTrue,
        reason: 'Year 7000 must start with ז׳ thousands prefix, got: $result',
      );
    });
  });

  group('Gematriya.forYear — valid range does not throw', () {
    test('forYear accepts any valid Hebrew year (>= 1)', () {
      expect(() => Gematriya.forYear(1), returnsNormally);
      expect(() => Gematriya.forYear(5786), returnsNormally);
      expect(() => Gematriya.forYear(6000), returnsNormally);
      expect(() => Gematriya.forYear(6120), returnsNormally);
      expect(() => Gematriya.forYear(9999), returnsNormally);
    });

    test('forYear rejects zero and negative', () {
      expect(() => Gematriya.forYear(0), throwsArgumentError);
      expect(() => Gematriya.forYear(-1), throwsArgumentError);
    });
  });
}
