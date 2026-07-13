// Regression tests for IL-3 (missing ICU plural handling in ARB strings).
//
// Root cause: Several count-bearing ARB templates use plain `{count}` string
// interpolation with no ICU `{count, plural, one{…} other{…}}` selector, so
// a count of 1 renders "1 items learned" / "1 curriculum-level siyumim" etc.
//
// Fix: Convert the affected templates to ICU plural so one{…} path uses the
// correct singular form. app_he.arb must be updated in parallel so placeholder
// shapes stay in sync.
//
// The test deliberately reads the ARB JSON directly so it catches the fix
// at the source (and fails before regeneration if the ARB is wrong), rather
// than testing the generated Dart which is committed alongside the ARB.
import 'package:flutter_test/flutter_test.dart';

import '../helpers/arb_loader.dart';

bool _hasIcuPlural(String value) {
  // A minimal check: value contains "plural," inside ICU braces.
  return value.contains(', plural,') || value.contains(',plural,');
}

void main() {
  late final Map<String, dynamic> enArb;
  late final Map<String, dynamic> heArb;

  setUpAll(() {
    enArb = loadArb('en');
    heArb = loadArb('he');
  });

  // ── IL-3 keys that MUST use ICU plural ────────────────────────────────────

  group('IL-3 — itemsLearnedCount uses ICU plural', () {
    test('app_en.arb: itemsLearnedCount has {count, plural, …}', () {
      final value = enArb['itemsLearnedCount'] as String;
      expect(
        _hasIcuPlural(value),
        isTrue,
        reason:
            '"$value" must use ICU plural so "1 item" is not "1 items". '
            'Expected: {count, plural, one{1 item learned} other{…}}',
      );
    });

    test(
      'app_en.arb: itemsLearnedCount one-form contains "item" (singular)',
      () {
        final value = enArb['itemsLearnedCount'] as String;
        if (!_hasIcuPlural(value)) return; // already caught above
        // The one{…} branch should contain singular "item" not "items".
        final oneMatch = RegExp(
          r'=1\{([^}]*)\}|one\{([^}]*)\}',
        ).firstMatch(value);
        if (oneMatch == null) return; // covered by ICU check
        final oneText = oneMatch.group(1) ?? oneMatch.group(2) ?? '';
        expect(
          oneText,
          isNot(contains('items')),
          reason: 'one{} branch should not contain "items"; got: "$oneText"',
        );
      },
    );

    test('app_he.arb: itemsLearnedCount has {count, plural, …}', () {
      final value = heArb['itemsLearnedCount'] as String;
      expect(
        _hasIcuPlural(value),
        isTrue,
        reason: 'app_he.arb itemsLearnedCount must also use ICU plural',
      );
    });
  });

  group('IL-3 — totalChazaros uses ICU plural', () {
    test('app_en.arb: totalChazaros has {count, plural, …}', () {
      final value = enArb['totalChazaros'] as String;
      expect(
        _hasIcuPlural(value),
        isTrue,
        reason:
            '"$value" must use ICU plural so "1 chazara" vs "N chazaros". '
            'Expected: {count, plural, one{1 total chazara} other{…}}',
      );
    });

    test('app_he.arb: totalChazaros has {count, plural, …}', () {
      final value = heArb['totalChazaros'] as String;
      expect(
        _hasIcuPlural(value),
        isTrue,
        reason: 'app_he.arb totalChazaros must also use ICU plural',
      );
    });
  });

  group('IL-3 — siyumimLevel* use ICU plural (singular: "siyum")', () {
    for (final key in [
      'siyumimLevelCurriculum',
      'siyumimLevelAggregate',
      'siyumimLevelUnit',
    ]) {
      test('app_en.arb: $key has {count, plural, …}', () {
        final value = enArb[key] as String;
        expect(
          _hasIcuPlural(value),
          isTrue,
          reason:
              '"$value" must use ICU plural so "1 siyum" not "1 siyumim". '
              'IL-3 fix required for key "$key".',
        );
      });

      test('app_he.arb: $key has {count, plural, …}', () {
        final value = heArb[key] as String;
        expect(
          _hasIcuPlural(value),
          isTrue,
          reason: 'app_he.arb $key must also use ICU plural',
        );
      });
    }
  });

  group('IL-3 — lifetimeMarkSavedCount drops "(s)" anti-pattern', () {
    test('app_en.arb: lifetimeMarkSavedCount has no "(s)"', () {
      final value = enArb['lifetimeMarkSavedCount'] as String;
      expect(
        value,
        isNot(contains('(s)')),
        reason:
            '"$value" must not use the (s) anti-pattern; '
            'use ICU plural instead: {count, plural, one{…selection.} other{…selections.}}',
      );
    });

    test('app_en.arb: lifetimeMarkSavedCount uses ICU plural', () {
      final value = enArb['lifetimeMarkSavedCount'] as String;
      expect(
        _hasIcuPlural(value),
        isTrue,
        reason:
            '"$value" must use ICU plural to handle singular/plural properly',
      );
    });

    test('app_he.arb: lifetimeMarkSavedCount has no "(s)"', () {
      final value = heArb['lifetimeMarkSavedCount'] as String;
      expect(value, isNot(contains('(s)')));
    });
  });

  group('IL-3 — paceBehindByDays uses ICU plural', () {
    test('app_en.arb: paceBehindByDays has {count, plural, …}', () {
      final value = enArb['paceBehindByDays'] as String;
      expect(
        _hasIcuPlural(value),
        isTrue,
        reason:
            '"$value" must use ICU plural so "1 day" not "1 days". '
            'Expected: {count, plural, one{Behind by 1 day} other{Behind by {count} days}}',
      );
    });

    test('app_he.arb: paceBehindByDays has {count, plural, …}', () {
      final value = heArb['paceBehindByDays'] as String;
      expect(
        _hasIcuPlural(value),
        isTrue,
        reason: 'app_he.arb paceBehindByDays must also use ICU plural',
      );
    });
  });
}
