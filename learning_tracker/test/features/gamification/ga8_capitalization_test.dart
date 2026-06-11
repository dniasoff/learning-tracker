/// GA-8 regression test — Inconsistent tile/section/title capitalization.
///
/// Root cause:
///   1. Parent Settings "Reward configuration" (lowercase 'c') breaks the
///      Title Case pattern and its own destination header.
///      l10n key: rewardConfigurationTitle = "Reward configuration"
///      Should be: "Reward Configuration"
///
///   2. Manage Tutors section headers mix casing:
///      manageTutorsActiveSection  = "ACTIVE ({count})"  — ALL_CAPS
///      manageTutorsPendingSection = "Pending ({count})" — Title Case
///      Should be consistent: both Title Case ("Active (n)" / "Pending (n)")
///      OR both ALL_CAPS ("ACTIVE (n)" / "PENDING (n)").
///      The fix normalizes both to Title Case.
///
/// This test reads the ARB file directly and asserts the correct strings are
/// in place.  RED before the ARB strings are fixed; GREEN after.
@Tags(['gamification', 'ga8', 'l10n'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final arbFile = File('${Directory.current.path}/lib/l10n/app_en.arb');

  group('GA-8: rewardConfigurationTitle must be Title Case', () {
    test(
      'rewardConfigurationTitle contains "Reward Configuration" (both words capitalized)',
      () {
        final content = arbFile.readAsStringSync();

        // Extract the value of "rewardConfigurationTitle"
        final match = RegExp(
          r'"rewardConfigurationTitle"\s*:\s*"([^"]*)"',
        ).firstMatch(content);

        expect(
          match,
          isNotNull,
          reason: 'rewardConfigurationTitle key must exist in app_en.arb',
        );

        final value = match!.group(1)!;
        expect(
          value,
          equals('Reward Configuration'),
          reason:
              'rewardConfigurationTitle should be "Reward Configuration" (Title Case), '
              'got: "$value"',
        );
      },
    );
  });

  group('GA-8: manageTutors section headers must use consistent casing', () {
    test('manageTutorsActiveSection must NOT be all-caps "ACTIVE"', () {
      final content = arbFile.readAsStringSync();

      final match = RegExp(
        r'"manageTutorsActiveSection"\s*:\s*"([^"]*)"',
      ).firstMatch(content);

      expect(match, isNotNull);
      final value = match!.group(1)!;

      // It should be "Active ({count})" not "ACTIVE ({count})"
      expect(
        value.startsWith('ACTIVE'),
        isFalse,
        reason:
            'manageTutorsActiveSection should be Title Case "Active ({count})", '
            'not ALL_CAPS "ACTIVE ({count})". Got: "$value"',
      );
      expect(
        value,
        contains('Active'),
        reason:
            'manageTutorsActiveSection should start with "Active" (Title Case)',
      );
    });

    test(
      'manageTutorsPendingSection uses same casing style as Active section',
      () {
        final content = arbFile.readAsStringSync();

        final activeMatch = RegExp(
          r'"manageTutorsActiveSection"\s*:\s*"([^"]*)"',
        ).firstMatch(content);
        final pendingMatch = RegExp(
          r'"manageTutorsPendingSection"\s*:\s*"([^"]*)"',
        ).firstMatch(content);

        expect(activeMatch, isNotNull);
        expect(pendingMatch, isNotNull);

        final activeValue = activeMatch!.group(1)!;
        final pendingValue = pendingMatch!.group(1)!;

        // Both should start with a capital letter (Title Case), not all-caps
        final activeIsAllCaps =
            activeValue.split(' ').first ==
            activeValue.split(' ').first.toUpperCase();
        final pendingIsAllCaps =
            pendingValue.split(' ').first ==
            pendingValue.split(' ').first.toUpperCase();

        expect(
          activeIsAllCaps,
          equals(pendingIsAllCaps),
          reason:
              'Both manageTutorsActiveSection and manageTutorsPendingSection must use '
              'the same casing style. Got: "$activeValue" vs "$pendingValue"',
        );
      },
    );
  });
}
