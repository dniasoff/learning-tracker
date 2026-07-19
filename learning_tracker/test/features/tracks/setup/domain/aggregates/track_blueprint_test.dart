import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/setup/domain/aggregates/track_blueprint.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';

void main() {
  final today = DateTime(2026, 5, 20);

  GoalEntity makeGoal() => GoalEntity(
    curriculumId: CurriculumId.bavli,
    description: 'test',
    createdAt: today,
    updatedAt: today,
  );

  // ── GoalIntent ──────────────────────────────────────────────────────────────
  group('GoalIntent', () {
    test('NoGoalIntent equality', () {
      expect(const NoGoalIntent(), const NoGoalIntent());
    });

    test('SpecifiedGoalIntent holds goal', () {
      final goal = makeGoal();
      final intent = SpecifiedGoalIntent(goal: goal);
      expect(intent.goal, goal);
    });
  });

  // ── StageConfiguration ──────────────────────────────────────────────────────
  group('StageConfiguration', () {
    test('SingleStageConfiguration equality', () {
      expect(
        const SingleStageConfiguration(),
        const SingleStageConfiguration(),
      );
    });

    test('WizardStageConfiguration holds wizard result', () {
      const wrapper = LearningProcessWizardResult(
        wizardResult: WizardResult(
          curriculumId: CurriculumId.bavli,
          choice: WizardChoice.noReview,
        ),
      );
      const config = WizardStageConfiguration(wizardResult: wrapper);
      expect(config.wizardResult, wrapper);
    });
  });

  // ── TrackBulkMarkIntent ─────────────────────────────────────────────────────
  group('TrackBulkMarkIntent', () {
    test('NoBulkMarkIntent equality', () {
      expect(const NoBulkMarkIntent(), const NoBulkMarkIntent());
    });

    test('BulkMarkedIntent equality and counts', () {
      const a = BulkMarkedIntent(itemCount: 5, completionCount: 10);
      const b = BulkMarkedIntent(itemCount: 5, completionCount: 10);
      expect(a, b);
      expect(a.itemCount, 5);
      expect(a.completionCount, 10);
    });

    test('BulkMarkedIntent inequality on different counts', () {
      const a = BulkMarkedIntent(itemCount: 5, completionCount: 10);
      const b = BulkMarkedIntent(itemCount: 3, completionCount: 6);
      expect(a == b, isFalse);
    });
  });

  // ── ProgramSelection ────────────────────────────────────────────────────────
  group('ProgramSelection', () {
    test('SelfPacedSelection equality', () {
      expect(const SelfPacedSelection(), const SelfPacedSelection());
    });

    test('CalendarProgramSelection holds fields', () {
      final pos = ProgramStartingPosition.create(
        startDate: today,
        today: today,
      );
      final sel = CalendarProgramSelection(
        programId: 1,
        programName: 'Daf Yomi',
        startingPosition: pos,
      );
      expect(sel.programId, 1);
      expect(sel.programName, 'Daf Yomi');
      expect(sel.startingPosition, pos);
    });

    test('CalendarProgramSelection equality', () {
      final pos = ProgramStartingPosition.create(
        startDate: today,
        today: today,
      );
      final a = CalendarProgramSelection(
        programId: 1,
        programName: 'Daf Yomi',
        startingPosition: pos,
      );
      final b = CalendarProgramSelection(
        programId: 1,
        programName: 'Daf Yomi',
        startingPosition: pos,
      );
      expect(a, b);
    });
  });

  // ── TrackBlueprint ──────────────────────────────────────────────────────────
  group('TrackBlueprint', () {
    test('isCalendarProgram false for self-paced', () {
      const blueprint = TrackBlueprint(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study'},
        programSelection: SelfPacedSelection(),
        stageConfiguration: SingleStageConfiguration(),
        goalIntent: NoGoalIntent(),
        bulkMarkIntent: NoBulkMarkIntent(),
      );
      expect(blueprint.isCalendarProgram, isFalse);
      expect(blueprint.programId, isNull);
      expect(blueprint.startingPosition, isNull);
    });

    test('isCalendarProgram true for calendar program', () {
      final pos = ProgramStartingPosition.create(
        startDate: today.subtract(const Duration(days: 5)),
        today: today,
      );
      final blueprint = TrackBlueprint(
        curriculumId: CurriculumId.bavli,
        label: 'Daf Yomi',
        studyDays: {1: 'study'},
        programSelection: CalendarProgramSelection(
          programId: 42,
          programName: 'Daf Yomi',
          startingPosition: pos,
        ),
        stageConfiguration: const SingleStageConfiguration(),
        goalIntent: const NoGoalIntent(),
        bulkMarkIntent: const NoBulkMarkIntent(),
      );
      expect(blueprint.isCalendarProgram, isTrue);
      expect(blueprint.programId, 42);
      expect(blueprint.startingPosition, pos);
    });

    // W4.12 regression: TrackBlueprint.fromLegacyResult bridge
    group('fromLegacyResult', () {
      test('null programId → SelfPacedSelection', () {
        const result = AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          studyDays: {1: 'study'},
        );
        final blueprint = TrackBlueprint.fromLegacyResult(result, today: today);
        expect(blueprint.programSelection, isA<SelfPacedSelection>());
        expect(blueprint.goalIntent, isA<NoGoalIntent>());
        expect(blueprint.bulkMarkIntent, isA<NoBulkMarkIntent>());
        expect(blueprint.stageConfiguration, isA<SingleStageConfiguration>());
      });

      test('programId present → CalendarProgramSelection', () {
        const result = AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Daf Yomi',
          programId: 1,
          programName: 'Daf Yomi',
          studyDays: {1: 'study'},
          startingRef: 'offset:5',
        );
        final blueprint = TrackBlueprint.fromLegacyResult(result, today: today);
        expect(blueprint.programSelection, isA<CalendarProgramSelection>());
        final cal = blueprint.programSelection as CalendarProgramSelection;
        expect(cal.programId, 1);
        expect(
          cal.startingPosition.daysFromToday(today),
          5,
          reason: 'offset:5 → 5 days back',
        );
      });

      test('bulkMarkResult → BulkMarkedIntent', () {
        const bulk = BulkMarkIntent(itemCount: 3, completionCount: 6);
        const result = AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          studyDays: {1: 'study'},
          bulkMarkResult: bulk,
        );
        final blueprint = TrackBlueprint.fromLegacyResult(result, today: today);
        final intent = blueprint.bulkMarkIntent as BulkMarkedIntent;
        expect(intent.itemCount, 3);
        expect(intent.completionCount, 6);
      });

      test('goalResult → SpecifiedGoalIntent', () {
        final goal = makeGoal();
        final result = AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          studyDays: {1: 'study'},
          goalResult: goal,
        );
        final blueprint = TrackBlueprint.fromLegacyResult(result, today: today);
        expect(blueprint.goalIntent, isA<SpecifiedGoalIntent>());
      });

      test('wizardResult → WizardStageConfiguration', () {
        const wrapper = LearningProcessWizardResult(
          wizardResult: WizardResult(
            curriculumId: CurriculumId.bavli,
            choice: WizardChoice.noReview,
          ),
        );
        const result = AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          studyDays: {1: 'study'},
          wizardResult: wrapper,
        );
        final blueprint = TrackBlueprint.fromLegacyResult(result, today: today);
        expect(blueprint.stageConfiguration, isA<WizardStageConfiguration>());
      });
    });

    test('equality based on key fields', () {
      final pos = ProgramStartingPosition.create(
        startDate: today,
        today: today,
      );
      final a = TrackBlueprint(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study'},
        programSelection: CalendarProgramSelection(
          programId: 1,
          programName: 'Daf Yomi',
          startingPosition: pos,
        ),
        stageConfiguration: const SingleStageConfiguration(),
        goalIntent: const NoGoalIntent(),
        bulkMarkIntent: const NoBulkMarkIntent(),
      );
      final b = TrackBlueprint(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study'},
        programSelection: CalendarProgramSelection(
          programId: 1,
          programName: 'Daf Yomi',
          startingPosition: pos,
        ),
        stageConfiguration: const SingleStageConfiguration(),
        goalIntent: const NoGoalIntent(),
        bulkMarkIntent: const NoBulkMarkIntent(),
      );
      expect(a, b);
    });

    // AUD-tracks-23 regression: TrackBlueprint's hand-rolled == omitted
    // studyDays and scopeSelections entirely, so two blueprints differing
    // only in one of those fields compared equal.
    test('inequality on different studyDays', () {
      const a = TrackBlueprint(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study'},
        programSelection: SelfPacedSelection(),
        stageConfiguration: SingleStageConfiguration(),
        goalIntent: NoGoalIntent(),
        bulkMarkIntent: NoBulkMarkIntent(),
      );
      const b = TrackBlueprint(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'skip'},
        programSelection: SelfPacedSelection(),
        stageConfiguration: SingleStageConfiguration(),
        goalIntent: NoGoalIntent(),
        bulkMarkIntent: NoBulkMarkIntent(),
      );
      expect(a == b, isFalse);
    });

    test('inequality on different scopeSelections', () {
      const a = TrackBlueprint(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study'},
        scopeSelections: [ScopeEntry(level: 1, value: 'Seder Zeraim')],
        programSelection: SelfPacedSelection(),
        stageConfiguration: SingleStageConfiguration(),
        goalIntent: NoGoalIntent(),
        bulkMarkIntent: NoBulkMarkIntent(),
      );
      const b = TrackBlueprint(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study'},
        scopeSelections: [ScopeEntry(level: 1, value: 'Seder Moed')],
        programSelection: SelfPacedSelection(),
        stageConfiguration: SingleStageConfiguration(),
        goalIntent: NoGoalIntent(),
        bulkMarkIntent: NoBulkMarkIntent(),
      );
      expect(a == b, isFalse);
    });
  });
}
