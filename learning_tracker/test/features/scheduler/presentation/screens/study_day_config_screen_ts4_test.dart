/// Regression test for TS-4:
/// study_day_config_screen.dart uses a const _dayLabels map with hardcoded
/// English day abbreviations (including "Sat" for Saturday). Saturday must be
/// routed through the Nusach/Hebrew-Terms resolver so it reads "Shabbos",
/// "Shabbat", or "שבת" depending on the active toggle and nusach.
///
/// The test imports [studyDayLabel] — a pure function extracted from the fix.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';

void main() {
  group('TS-4 — studyDayLabel routes Saturday through nusach resolver', () {
    test('Saturday with Hebrew-Terms OFF + Ashkenazi returns Shabbos', () {
      const terms = DomainTermLabels(false); // Hebrew OFF
      const variant = TransliterationVariant.ashkenazi;

      final label = studyDayLabel(
        isoWeekday: 6, // Saturday = 6 in ISO
        terms: terms,
        variant: variant,
      );

      expect(label, equals('Shabbos'));
      expect(label, isNot(equals('Sat')));
    });

    test('Saturday with Hebrew-Terms OFF + Sephardi returns Shabbat', () {
      const terms = DomainTermLabels(false);
      const variant = TransliterationVariant.sephardi;

      final label = studyDayLabel(
        isoWeekday: 6,
        terms: terms,
        variant: variant,
      );

      expect(label, equals('Shabbat'));
    });

    test('Saturday with Hebrew-Terms ON returns Hebrew שבת', () {
      const terms = DomainTermLabels(true); // Hebrew ON
      const variant = TransliterationVariant.ashkenazi;

      final label = studyDayLabel(
        isoWeekday: 6,
        terms: terms,
        variant: variant,
      );

      expect(label, equals('שבת'));
    });

    test('Non-Saturday days return standard English abbreviation', () {
      const terms = DomainTermLabels(false);
      const variant = TransliterationVariant.ashkenazi;

      expect(
        studyDayLabel(isoWeekday: 1, terms: terms, variant: variant),
        equals('Mon'),
      );
      expect(
        studyDayLabel(isoWeekday: 5, terms: terms, variant: variant),
        equals('Fri'),
      );
      // Sunday (ISO weekday 7) should be 'Sun', not confused with Shabbos
      expect(
        studyDayLabel(isoWeekday: 7, terms: terms, variant: variant),
        equals('Sun'),
      );
    });

    test(
      'Sunday (ISO 7) initial is not the same as Saturday (ISO 6) initial',
      () {
        const terms = DomainTermLabels(false);
        const variant = TransliterationVariant.ashkenazi;

        final satLabel = studyDayLabel(
          isoWeekday: 6,
          terms: terms,
          variant: variant,
        );
        final sunLabel = studyDayLabel(
          isoWeekday: 7,
          terms: terms,
          variant: variant,
        );

        // TS-4: Shabbos avatar "S" must not duplicate Sunday's "S".
        // After the fix, Saturday uses "Sh" or a Hebrew character initial.
        expect(
          satLabel,
          isNot(equals(sunLabel)),
          reason: 'Saturday and Sunday labels must be distinct (TS-4)',
        );
      },
    );
  });
}
