import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';

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
    // These exercise the REAL production symbol, smartDefaultTrackName
    // (lib/features/tracks/setup/presentation/screens/add_track_flow_screen.dart),
    // not a private test-local reimplementation — see AUD-t-track_setup-01.
    test('uses program name when program selected', () {
      const state = AddTrackState(
        curriculumId: CurriculumId.bavli,
        programName: 'דף היומי',
      );

      final defaultName = smartDefaultTrackName(state, useHebrewTerms: true);
      expect(defaultName, 'דף היומי');
    });

    test(
      'uses curriculum label (not the last scope value) when scope narrowed',
      () {
        // Regression test for the F-05/F-21/run7 on-device audit fix: the
        // track-setup wizard's smart default name previously showed the
        // last-selected scope value (e.g. "סדר זרעים") instead of the
        // curriculum label, so the post-creation snackbar didn't match the
        // Track Management hub card title. Before the fix was wired through
        // this production symbol, asserting this expectation against the
        // (now-deleted) stale test-local copy failed with:
        //   Expected: משניות
        //     Actual: סדר זרעים
        const state = AddTrackState(
          curriculumId: CurriculumId.mishnayos,
          scopeSelections: [ScopeEntry(level: 1, value: 'סדר זרעים')],
        );

        final defaultName = smartDefaultTrackName(state, useHebrewTerms: true);
        expect(defaultName, CurriculumId.mishnayos.displayNameHe);
      },
    );

    test('uses curriculum Hebrew name as fallback', () {
      const state = AddTrackState(curriculumId: CurriculumId.mishnayos);

      final defaultName = smartDefaultTrackName(state, useHebrewTerms: true);
      expect(defaultName, CurriculumId.mishnayos.displayNameHe);
    });
  });

  // The former 'Program auto-skip logic' group (AddTrackFlowStateX
  // .hasProgramsForCurriculum) was removed here — AUD-tracks-11 deleted
  // add_track_flow_state.dart as dead code: the live AddTrackFlow wizard
  // (add_track_flow_screen.dart) has always used its own independent
  // _hasProgramStepForCurriculum implementation, never this extension, so
  // this group pinned behavior nobody exercised in production. See the
  // finding's commit for the full evidence trail.
}
