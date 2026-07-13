// Regression tests for IL-9 (Hebrew locale leaks untranslated Latin literals).
//
// Root cause: sacredTimeLockGoodShabbos, sacredTimeLockShabbosSubtitle, and
// sacredTimeShabbosModeLabel in app_he.arb used {term} placeholders. When the
// device locale is Hebrew but the Hebrew Terms toggle is OFF, the caller passes
// the English transliteration "Shabbos" (or "SHABBOS" after .toUpperCase()),
// so the Hebrew UI showed "שבת שלום? No: Shabbos שלום" / "מצב SHABBOS".
//
// Fix: in app_he.arb, these strings hardcode the Hebrew "שבת" / "שבת שלום" and
// do not reference {term}, so the Hebrew locale always renders correctly
// regardless of what term value the feature code passes.
import 'package:flutter_test/flutter_test.dart';

import '../helpers/arb_loader.dart';

void main() {
  late final Map<String, dynamic> heArb;

  setUpAll(() {
    heArb = loadArb('he');
  });

  group('IL-9 — Hebrew Shabbos strings do not leak Latin {term}', () {
    test(
      'app_he.arb: sacredTimeLockGoodShabbos contains Hebrew שבת (not {term})',
      () {
        final value = heArb['sacredTimeLockGoodShabbos'] as String;
        expect(
          value.contains('שבת'),
          isTrue,
          reason:
              '"$value" must contain Hebrew "שבת" for the Hebrew greeting. '
              'IL-9 fix: do not use {term} in the Hebrew template.',
        );
        expect(
          value.contains('{term}'),
          isFalse,
          reason:
              '"$value" must NOT reference {term} in app_he.arb — the Hebrew '
              'locale should hardcode "שבת" so "SHABBOS" cannot leak in.',
        );
      },
    );

    test(
      'app_he.arb: sacredTimeLockShabbosSubtitle contains Hebrew שבת (not {term})',
      () {
        final value = heArb['sacredTimeLockShabbosSubtitle'] as String;
        expect(value.contains('שבת'), isTrue);
        expect(
          value.contains('{term}'),
          isFalse,
          reason: 'IL-9: sacredTimeLockShabbosSubtitle must not use {term}',
        );
      },
    );

    test(
      'app_he.arb: sacredTimeShabbosModeLabel contains Hebrew שבת (not {term})',
      () {
        final value = heArb['sacredTimeShabbosModeLabel'] as String;
        expect(value.contains('שבת'), isTrue);
        expect(
          value.contains('{term}'),
          isFalse,
          reason: 'IL-9: sacredTimeShabbosModeLabel must not use {term}',
        );
      },
    );

    test(
      'app_he.arb: sacredTimeCardDescription contains Hebrew שבת (not {term})',
      () {
        final value = heArb['sacredTimeCardDescription'] as String;
        expect(value.contains('שבת'), isTrue);
        expect(
          value.contains('{term}'),
          isFalse,
          reason: 'IL-9: sacredTimeCardDescription must not use {term}',
        );
      },
    );

    test(
      'app_he.arb: sacredTimeLockShabbosYomTovGreeting contains Hebrew שבת (not {term})',
      () {
        final value = heArb['sacredTimeLockShabbosYomTovGreeting'] as String;
        expect(value.contains('שבת'), isTrue);
        expect(value.contains('{term}'), isFalse);
      },
    );

    test(
      'app_he.arb: sacredTimeLockShabbosYomTovSubtitle contains Hebrew שבת (not {term})',
      () {
        final value = heArb['sacredTimeLockShabbosYomTovSubtitle'] as String;
        expect(value.contains('שבת'), isTrue);
        expect(value.contains('{term}'), isFalse);
      },
    );
  });
}
