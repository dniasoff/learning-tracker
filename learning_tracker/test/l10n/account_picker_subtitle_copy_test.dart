// Regression tests: the ACCOUNT picker subtitle must describe accounts, not
// learners.
//
// Root cause: accountPickerSubtitle read "Select a learner to continue your
// journey" (he: "בחרו משתמש כדי להמשיך") — copy borrowed from the learner /
// "Who is learning?" profile picker. AccountPickerScreen is a CLOUD ACCOUNT
// switcher (title "Choose an Account"), so the learner wording is wrong for the
// surface.
//
// Fix: accountPickerSubtitle now reads "Select an account to continue" (he:
// "בחרו חשבון כדי להמשיך"). These tests pin the corrected, account-oriented
// copy and guard against a regression back to learner wording. The separate
// learner picker (profilePickerSubtitle) is asserted unchanged so the fix did
// not bleed across surfaces.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _loadArb(String locale) {
  final candidates = [
    File('lib/l10n/app_$locale.arb'),
    File('../lib/l10n/app_$locale.arb'),
  ];
  final file = candidates.firstWhere(
    (f) => f.existsSync(),
    orElse: () =>
        throw TestFailure('Could not locate lib/l10n/app_$locale.arb.'),
  );
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  late final Map<String, dynamic> enArb;
  late final Map<String, dynamic> heArb;

  setUpAll(() {
    enArb = _loadArb('en');
    heArb = _loadArb('he');
  });

  group('Account picker subtitle describes accounts, not learners', () {
    test('app_en.arb: accountPickerSubtitle is account-oriented', () {
      final value = enArb['accountPickerSubtitle'] as String;
      expect(
        value.toLowerCase().contains('account'),
        isTrue,
        reason:
            '"$value" must mention "account" — this is the cloud ACCOUNT '
            'picker, not the learner picker.',
      );
      expect(
        value.toLowerCase().contains('learner'),
        isFalse,
        reason:
            '"$value" must NOT say "learner" — that copy belongs to the '
            'profile/learner picker, not the account picker.',
      );
    });

    test('app_he.arb: accountPickerSubtitle uses חשבון (account)', () {
      final value = heArb['accountPickerSubtitle'] as String;
      expect(
        value.contains('חשבון'),
        isTrue,
        reason:
            '"$value" must contain Hebrew "חשבון" (account) to match the '
            'account-picker surface.',
      );
    });

    test('learner picker copy is unchanged (no cross-surface bleed)', () {
      // profilePickerSubtitle (the "Who is learning?" learner picker) should
      // still talk about a profile, untouched by the account-picker fix.
      final enLearner = enArb['profilePickerSubtitle'] as String;
      expect(enLearner.toLowerCase().contains('profile'), isTrue);
    });
  });
}
