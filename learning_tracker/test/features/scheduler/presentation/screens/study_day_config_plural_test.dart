/// Regression test for R1 finding (6):
/// StudyDayConfigScreen showed "1 study days per week" when exactly 1 study day
/// was selected (hardcoded `${studyCount == 1 ? '' : 's'}` ternary, bypassing
/// ICU plural rules and the l10n system).
///
/// Fix: replace the ternary with [AppLocalizations.studyDaysPerWeekLabel(count)]
/// which uses the ICU plural pattern
///   {count, plural, =1{1 study day per week} other{{count} study days per week}}
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';

void main() {
  group('R1-(6) studyDaysPerWeekLabel — singular/plural', () {
    late AppLocalizationsEn l10n;

    setUp(() {
      Intl.defaultLocale = 'en';
      l10n = AppLocalizationsEn();
    });

    test('count=1 returns singular "1 study day per week"', () {
      final label = l10n.studyDaysPerWeekLabel(1);
      expect(
        label,
        equals('1 study day per week'),
        reason:
            'R1-(6): singular must read "1 study day per week", '
            'not "1 study days per week".',
      );
    });

    test('count=2 returns plural "2 study days per week"', () {
      final label = l10n.studyDaysPerWeekLabel(2);
      expect(label, equals('2 study days per week'));
    });

    test('count=7 returns plural "7 study days per week"', () {
      final label = l10n.studyDaysPerWeekLabel(7);
      expect(label, equals('7 study days per week'));
    });

    test('count=0 returns plural form "0 study days per week"', () {
      final label = l10n.studyDaysPerWeekLabel(0);
      expect(label, equals('0 study days per week'));
    });
  });
}
