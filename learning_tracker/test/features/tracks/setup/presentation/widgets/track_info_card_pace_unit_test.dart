/// Regression test for finding 5:
/// The Track-Detail required-pace row for a PACE goal previously rendered a
/// bare number with no unit noun ("7 · Per week"). [paceGoalUnitNoun] must now
/// resolve the unit noun for the goal's stored granularity so the row reads
/// e.g. "7 Dafim · Per week".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_info_card.dart';

void main() {
  group('paceGoalUnitNoun', () {
    String? noun({
      CurriculumId? curriculum = CurriculumId.bavli,
      String goalType = 'pace',
      int? paceValue = 7,
      String? paceGranularity = 'daf',
      bool useHebrew = false,
      TransliterationVariant variant = TransliterationVariant.ashkenazi,
    }) => paceGoalUnitNoun(
      curriculum: curriculum,
      goalType: goalType,
      paceValue: paceValue,
      paceGranularity: paceGranularity,
      useHebrew: useHebrew,
      variant: variant,
    );

    test('English pace goal returns the plural unit noun (Dafim)', () {
      expect(noun(paceValue: 7), 'Dafim');
    });

    test('singular pace value returns the singular noun (Daf)', () {
      expect(noun(paceValue: 1), 'Daf');
    });

    test('Hebrew terms returns Hebrew script unit noun', () {
      final result = noun(useHebrew: true);
      expect(result, isNotNull);
      // Hebrew daf plural — must be Hebrew script, not Latin.
      expect(RegExp('[֐-׿]').hasMatch(result!), isTrue);
    });

    test('Sephardi nusach maps Dafim → Dapim', () {
      expect(noun(variant: TransliterationVariant.sephardi), 'Dapim');
    });

    test('deadline goals have no pace unit noun', () {
      expect(noun(goalType: 'deadline'), isNull);
    });

    test(
      'missing granularity returns null (caller falls back to bare number)',
      () {
        expect(noun(paceGranularity: null), isNull);
        expect(noun(paceGranularity: ''), isNull);
      },
    );

    test('missing curriculum returns null', () {
      expect(noun(curriculum: null), isNull);
    });

    test('Mishnayos daf-less granularity resolves its own noun', () {
      // Mishnayos default fine unit is "mishna" (plural "Mishnayos").
      expect(
        noun(curriculum: CurriculumId.mishnayos, paceGranularity: 'mishna'),
        'Mishnayos',
      );
    });
  });
}
