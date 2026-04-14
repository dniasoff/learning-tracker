import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';

void main() {
  group('AddTrackResult', () {
    test('creates with required fields', () {
      const result = AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'משניות',
        studyDays: {
          1: 'study',
          2: 'study',
          3: 'study',
          4: 'study',
          5: 'study',
          6: 'review',
          7: 'review',
        },
      );

      expect(result.curriculumId, CurriculumId.mishnayos);
      expect(result.label, 'משניות');
      expect(result.programId, isNull);
      expect(result.scopeSelections, isNull);
      expect(result.wizardResult, isNull);
      expect(result.goalResult, isNull);
      expect(result.bulkMarkResult, isNull);
    });

    test('creates with all optional fields', () {
      const result = AddTrackResult(
        curriculumId: CurriculumId.bavli,
        label: 'דף היומי',
        programId: 1,
        programName: 'דף היומי',
        scopeSelections: [ScopeEntry(level: 1, value: 'Berachos')],
        studyDays: {1: 'study', 2: 'study'},
      );

      expect(result.programId, 1);
      expect(result.programName, 'דף היומי');
      expect(result.scopeSelections, hasLength(1));
    });

    test('copyWith preserves unchanged fields', () {
      const original = AddTrackResult(
        curriculumId: CurriculumId.bavli,
        label: 'Test',
        studyDays: {1: 'study'},
      );

      final updated = original.copyWith(label: 'Updated');

      expect(updated.curriculumId, CurriculumId.bavli);
      expect(updated.label, 'Updated');
      expect(updated.studyDays, {1: 'study'});
    });
  });

  group('ScopeEntry', () {
    test('creates with level and value', () {
      const entry = ScopeEntry(level: 1, value: 'Seder Zeraim');
      expect(entry.level, 1);
      expect(entry.value, 'Seder Zeraim');
    });

    test('equality works', () {
      const a = ScopeEntry(level: 1, value: 'Zeraim');
      const b = ScopeEntry(level: 1, value: 'Zeraim');
      expect(a, equals(b));
    });
  });

  group('AddTrackState', () {
    test('defaults to curriculum step', () {
      const state = AddTrackState();
      expect(state.currentStep, AddTrackStep.curriculum);
      expect(state.curriculumId, isNull);
      expect(state.contentActivated, false);
    });

    test('copyWith updates step and curriculum', () {
      const state = AddTrackState();
      final updated = state.copyWith(
        currentStep: AddTrackStep.scope,
        curriculumId: CurriculumId.mishnayos,
      );

      expect(updated.currentStep, AddTrackStep.scope);
      expect(updated.curriculumId, CurriculumId.mishnayos);
    });
  });

  group('AddTrackStep', () {
    test('has 8 steps', () {
      expect(AddTrackStep.values, hasLength(8));
    });

    test('steps are in correct order (program before scope)', () {
      expect(AddTrackStep.values, [
        AddTrackStep.curriculum,
        AddTrackStep.program,
        AddTrackStep.scope,
        AddTrackStep.studyDays,
        AddTrackStep.chazaraSetup,
        AddTrackStep.goal,
        AddTrackStep.trackName,
        AddTrackStep.bulkMark,
      ]);
    });
  });

  group('Smart track name defaults', () {
    test('uses program name when program selected', () {
      const state = AddTrackState(
        curriculumId: CurriculumId.bavli,
        programName: 'דף היומי',
      );

      final defaultName = _getSmartDefault(state);
      expect(defaultName, 'דף היומי');
    });

    test('uses scope value when scope narrowed', () {
      const state = AddTrackState(
        curriculumId: CurriculumId.mishnayos,
        scopeSelections: [ScopeEntry(level: 1, value: 'סדר זרעים')],
      );

      final defaultName = _getSmartDefault(state);
      expect(defaultName, 'סדר זרעים');
    });

    test('uses curriculum Hebrew name as fallback', () {
      const state = AddTrackState(curriculumId: CurriculumId.mishnayos);

      final defaultName = _getSmartDefault(state);
      expect(defaultName, CurriculumId.mishnayos.displayNameHe);
    });
  });

  group('Program auto-skip logic', () {
    test('bavli has programs', () {
      expect(_hasProgramsForCurriculum(CurriculumId.bavli), true);
    });

    test('mishnaBerurah has programs', () {
      expect(_hasProgramsForCurriculum(CurriculumId.mishnaBerurah), true);
    });

    test('mishnayos has programs', () {
      expect(_hasProgramsForCurriculum(CurriculumId.mishnayos), true);
    });

    test('chumash has no programs', () {
      expect(_hasProgramsForCurriculum(CurriculumId.chumash), false);
    });

    test('torah has programs', () {
      expect(_hasProgramsForCurriculum(CurriculumId.mishnehTorah), true);
    });

    test('tanach has programs', () {
      expect(_hasProgramsForCurriculum(CurriculumId.tanach), true);
    });
  });
}

// Extracted logic from AddTrackFlow for unit testing
String _getSmartDefault(AddTrackState state) {
  if (state.programName != null) return state.programName!;
  if (state.scopeSelections != null && state.scopeSelections!.isNotEmpty) {
    return state.scopeSelections!.last.value;
  }
  return state.curriculumId?.displayNameHe ?? '';
}

/// Curricula that have at least one seeded learning program.
bool _hasProgramsForCurriculum(CurriculumId curriculum) {
  return curriculum == CurriculumId.bavli ||
      curriculum == CurriculumId.mishnaBerurah ||
      curriculum == CurriculumId.yerushalmi ||
      curriculum == CurriculumId.mussar ||
      curriculum == CurriculumId.mishnayos ||
      curriculum == CurriculumId.nach ||
      curriculum == CurriculumId.mishnehTorah ||
      curriculum == CurriculumId.tanach;
}
