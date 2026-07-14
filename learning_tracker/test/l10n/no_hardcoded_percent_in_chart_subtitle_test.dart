/// Regression test: ensures `chartCumulativeProgressSubtitle` in both ARB
/// files does NOT contain a hardcoded, never-computed-at-runtime statistic
/// (e.g. "+12%", "12%", or "12 more completions").
///
/// Fix 1 — Progress Aggregator L1+L2 remediation (2026-05-20).
/// Analyst finding: the string was a static placeholder ("+12% vs last week")
/// that was never computed at runtime. The fix replaced it with static prose
/// containing no digits at all.
///
/// Fix 2 — AUD-t-cross-57 (2026-07-14). The original guard only matched the
/// signed digit-percent shape (`[+-]\d+%`), so an unsigned reintroduction
/// like "12%" — or a non-percent fabricated stat like "12 more completions
/// than last week" — would have slipped past undetected. The guard now
/// rejects any digit in the subtitle, matching the actual intent: the string
/// is static prose, not a statistic.
library;

import 'package:flutter_test/flutter_test.dart';

import '../helpers/arb_loader.dart';

/// Matches any digit. `chartCumulativeProgressSubtitle` is static prose with
/// no computed-at-runtime statistic, so a legitimate value never contains a
/// digit — signed ("+12%"), unsigned ("12%"), or non-percent ("12 more
/// completions"). Any digit is therefore evidence of a reintroduced
/// hardcoded/fabricated stat.
final _fabricatedStatPattern = RegExp(r'\d');

void main() {
  group('chartCumulativeProgressSubtitle — no hardcoded percentage', () {
    for (final locale in ['en', 'he']) {
      test('app_$locale.arb does not contain a hardcoded ±N% literal', () {
        final arb = loadArb(locale);

        final subtitle = arb['chartCumulativeProgressSubtitle'] as String?;
        expect(
          subtitle,
          isNotNull,
          reason:
              'chartCumulativeProgressSubtitle key must exist in app_$locale.arb',
        );
        expect(
          _fabricatedStatPattern.hasMatch(subtitle!),
          isFalse,
          reason:
              'chartCumulativeProgressSubtitle in app_$locale.arb must not '
              'contain a hardcoded percentage literal like "+12%". '
              'Found: "$subtitle"',
        );
      });

      test('app_$locale.arb: an unsigned "N%" literal injected into '
          'chartCumulativeProgressSubtitle is caught by the guard '
          '(AUD-t-cross-57)', () {
        final arb = loadArb(locale);
        final subtitle = arb['chartCumulativeProgressSubtitle'] as String?;
        expect(subtitle, isNotNull);

        // Simulate a future regression reintroducing a fabricated,
        // never-computed-at-runtime statistic — this time without a
        // leading sign (the shape the original pattern missed).
        final injected = '$subtitle 12%';

        expect(
          _fabricatedStatPattern.hasMatch(injected),
          isTrue,
          reason:
              'The hardcoded-percent guard must catch an unsigned '
              'percentage literal like "12%", not just signed ones like '
              '"+12%". Injected value: "$injected"',
        );
      });

      test('app_$locale.arb: a non-percent fabricated stat injected into '
          'chartCumulativeProgressSubtitle is caught by the guard '
          '(AUD-t-cross-57)', () {
        final arb = loadArb(locale);
        final subtitle = arb['chartCumulativeProgressSubtitle'] as String?;
        expect(subtitle, isNotNull);

        // Simulate a future regression that fabricates a non-percent
        // "computed" stat instead of a percentage — same defect class,
        // different shape.
        final injected = '$subtitle 12 more completions than last week';

        expect(
          _fabricatedStatPattern.hasMatch(injected),
          isTrue,
          reason:
              'The hardcoded-percent guard must catch any fabricated '
              'digit-bearing statistic, not just the "+N%" shape. '
              'Injected value: "$injected"',
        );
      });
    }
  });
}
