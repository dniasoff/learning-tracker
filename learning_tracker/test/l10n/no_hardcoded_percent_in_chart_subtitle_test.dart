/// Regression test: ensures `chartCumulativeProgressSubtitle` in both ARB
/// files does NOT contain a hardcoded percentage literal (e.g. "+12%").
///
/// Fix 1 — Progress Aggregator L1+L2 remediation (2026-05-20).
/// Analyst finding: the string was a static placeholder ("+12% vs last week")
/// that was never computed at runtime.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches strings that contain a hardcoded percentage like "+12%" or "-5%".
final _hardcodedPercentPattern = RegExp(r'[+-]\d+%');

void main() {
  group('chartCumulativeProgressSubtitle — no hardcoded percentage', () {
    for (final locale in ['en', 'he']) {
      test('app_$locale.arb does not contain a hardcoded ±N% literal', () {
        final arbFile = File('lib/l10n/app_$locale.arb');
        expect(
          arbFile.existsSync(),
          isTrue,
          reason: 'ARB file for locale "$locale" must exist',
        );

        final arb =
            json.decode(arbFile.readAsStringSync()) as Map<String, dynamic>;

        final subtitle = arb['chartCumulativeProgressSubtitle'] as String?;
        expect(
          subtitle,
          isNotNull,
          reason:
              'chartCumulativeProgressSubtitle key must exist in app_$locale.arb',
        );
        expect(
          _hardcodedPercentPattern.hasMatch(subtitle!),
          isFalse,
          reason:
              'chartCumulativeProgressSubtitle in app_$locale.arb must not '
              'contain a hardcoded percentage literal like "+12%". '
              'Found: "$subtitle"',
        );
      });
    }
  });
}
