/// Regression tests for R1 finding (7):
/// goal_setup_screen.dart and study_day_config_screen.dart contained many
/// hardcoded English strings that were NOT passed through the l10n system,
/// so Hebrew users saw English UI text.
///
/// Fix: replace all hardcoded English strings with AppLocalizations.* calls
/// and add the corresponding keys to app_en.arb + app_he.arb.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

void main() {
  group('R1-(7) goal_setup_screen — all l10n keys present and correct', () {
    late AppLocalizationsEn en;
    late AppLocalizationsHe he;

    setUp(() {
      Intl.defaultLocale = 'en';
      en = AppLocalizationsEn();
      he = AppLocalizationsHe();
    });

    test('goalDeadlineDatePickerHint defined in en', () {
      expect(en.goalDeadlineDatePickerHint, equals('Tap to choose a date'));
    });

    test('goalDeadlineDatePickerHint is NOT English in he', () {
      final heValue = he.goalDeadlineDatePickerHint;
      expect(
        heValue,
        isNot(equals('Tap to choose a date')),
        reason:
            'R1-(7): Hebrew locale must not show hardcoded English '
            '"Tap to choose a date".',
      );
    });

    test('goalDeadlineOccasionLabel defined in en', () {
      expect(en.goalDeadlineOccasionLabel, equals('Occasion (optional)'));
    });

    test('goalDeadlineOccasionLabel is NOT English in he', () {
      expect(
        he.goalDeadlineOccasionLabel,
        isNot(equals('Occasion (optional)')),
      );
    });

    test('goalDeadlinePassed defined in en', () {
      expect(en.goalDeadlinePassed, equals('Deadline has passed'));
    });

    test('goalDeadlinePassed is NOT English in he', () {
      expect(
        he.goalDeadlinePassed,
        isNot(equals('Deadline has passed')),
        reason: 'R1-(7): Hebrew locale must show Hebrew deadline-passed text.',
      );
    });

    test('goalDeadlinePaceItems(5) = "~5 items per day" in en', () {
      expect(en.goalDeadlinePaceItems(5), equals('~5 items per day'));
    });

    test('goalDeadlinePaceItems is NOT English in he', () {
      expect(he.goalDeadlinePaceItems(5), isNot(equals('~5 items per day')));
    });

    test('goalPaceProjectedCompletion in en', () {
      expect(
        en.goalPaceProjectedCompletion('Jan 1, 2027'),
        equals('Projected completion: Jan 1, 2027'),
      );
    });

    test('goalPaceProjectedCompletion is NOT English in he', () {
      expect(
        he.goalPaceProjectedCompletion('1 בינואר 2027'),
        isNot(contains('Projected completion:')),
        reason: 'R1-(7): Hebrew locale must not show hardcoded English prefix.',
      );
    });

    test('goalLearningUnitLabel in en', () {
      expect(en.goalLearningUnitLabel, equals('Learning unit'));
    });

    test('goalLearningUnitLabel is NOT English in he', () {
      expect(he.goalLearningUnitLabel, isNot(equals('Learning unit')));
    });

    test('goalNoPressureLabel in en', () {
      expect(
        en.goalNoPressureLabel,
        equals('Learn at your own pace with no time pressure.'),
      );
    });

    test('goalNoPressureLabel is NOT English in he', () {
      expect(
        he.goalNoPressureLabel,
        isNot(equals('Learn at your own pace with no time pressure.')),
      );
    });
  });

  group('R1-(7) study_day_config_screen — all l10n keys present and correct', () {
    late AppLocalizationsEn en;
    late AppLocalizationsHe he;

    setUp(() {
      Intl.defaultLocale = 'en';
      en = AppLocalizationsEn();
      he = AppLocalizationsHe();
    });

    test('studyDayConfigTitle in en', () {
      expect(
        en.studyDayConfigTitle('Mishnayos'),
        equals('Mishnayos Study Days'),
      );
    });

    test('studyDayConfigTitle is NOT English in he', () {
      final heTitle = he.studyDayConfigTitle('משניות');
      expect(
        heTitle,
        isNot(contains('Study Days')),
        reason:
            'R1-(7): Hebrew AppBar title must not contain hardcoded English "Study Days".',
      );
    });

    test('studyDayConfigSubtitle in en', () {
      expect(
        en.studyDayConfigSubtitle,
        equals(
          'Choose which days include new learning and which are for review only.',
        ),
      );
    });

    test('studyDayConfigSubtitle is NOT English in he', () {
      expect(
        he.studyDayConfigSubtitle,
        isNot(contains('Choose which days')),
        reason: 'R1-(7): Hebrew subtitle must not show hardcoded English copy.',
      );
    });

    test('studyDayConfigAllDaysStudy in en', () {
      expect(
        en.studyDayConfigAllDaysStudy,
        equals('All days are study days for this track.'),
      );
    });

    test('studyDayConfigAllDaysStudy is NOT English in he', () {
      expect(
        he.studyDayConfigAllDaysStudy,
        isNot(contains('All days are study days')),
        reason:
            'R1-(7): Hebrew fallback text must not show hardcoded English copy.',
      );
    });
  });
}
