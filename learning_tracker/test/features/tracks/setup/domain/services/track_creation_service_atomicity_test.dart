// TrackCreationService: Add track is ONE named governed action (DNI-476
// AC-5), plus the program-track regressions of the Firestore migration.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fake_clock.dart';
import '../../../../../helpers/recording_add_track_actions.dart';

class _MockStageRepository extends Mock implements StageDefinitionRepository {}

class _NoPrograms implements ProfileProgramRepository {
  @override
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async =>
      null;

  @override
  Future<void> setProgram({
    required CurriculumId curriculumId,
    required int programId,
    DateTime? trackingStartDate,
    String? trackingStartRef,
  }) async => fail('Add track writes the program inside its action');

  @override
  Future<void> removeProgram(CurriculumId curriculumId) async =>
      fail('Add track writes the program inside its action');
}

TrackCreationService _buildService({
  required RecordingAddTrackActions actions,
  AnalyticsService? analytics,
}) => TrackCreationService(
  actionRepository: actions,
  wizardService: LearningProcessWizardService(
    stageRepository: _MockStageRepository(),
    learningProgramRepo: LearningProgramRepository.instance,
    profileProgramRepository: _NoPrograms(),
  ),
  analytics: analytics,
);

void main() {
  test('Add track is ONE action holding the track, stages, study days, '
      'scope, program and goal', () async {
    final actions = RecordingAddTrackActions();
    await _buildService(actions: actions).createTrack(
      result: AddTrackResult(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: const {1: 'study', 6: 'rest'},
        scopeSelections: const [ScopeEntry(level: 1, value: 'Seder Moed')],
        goalResult: GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'deadline',
          targetDate: DateTime.utc(2027, 6, 1),
          createdAt: DateTime.utc(2026),
        ),
      ),
    );

    final plan = actions.plans.single;
    expect(plan.curriculumId, CurriculumId.bavli);
    expect(plan.stages.map((s) => s.stageName), ['לימוד']);
    expect(plan.studyDays, {1: DayType.study, 6: DayType.review});
    expect(plan.scopes, [(level: 1, value: 'Seder Moed')]);
    expect(plan.program, isNull);
    expect(plan.goal?.goalType, 'deadline');
    expect(
      plan.goal?.description,
      'Bavli',
      reason: 'an empty goal description falls back to the track label',
    );
  });

  test('a failed action propagates', () async {
    final actions = RecordingAddTrackActions()..failWith = Exception('x');
    await expectLater(
      _buildService(actions: actions).createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          programId: 99,
          studyDays: {1: 'study'},
          startingRef: 'Berakhot 2a',
        ),
      ),
      throwsException,
    );
  });

  for (final (label, startingRef) in [
    ('positive', 'offset:5'),
    ('negative', 'offset:-5'),
  ]) {
    test('B3: $label back-date offset resolves to the past', () async {
      final actions = RecordingAddTrackActions();
      final fixedNow = DateTime.utc(2026, 6, 15, 12);
      installFakeClock(fixedNow);
      final before = DateTimeFactory.nowUtc();

      await _buildService(actions: actions).createTrack(
        result: AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          programId: 99,
          studyDays: const {1: 'study'},
          startingRef: startingRef,
        ),
      );

      final program = actions.plans.single.program!;
      expect(program.programId, 99);
      final date = program.trackingStartDate;
      expect(date, isNotNull);
      expect(date!.isBefore(before), isTrue);
      expect(before.difference(date).inDays, 5);
    });
  }

  test(
    'program creation stores its governed starting reference in the action',
    () async {
      final actions = RecordingAddTrackActions();
      await _buildService(actions: actions).createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          programId: 99,
          studyDays: {1: 'study'},
          startingRef: 'Mishnah Berakhot 2:1',
        ),
      );

      expect(
        actions.plans.single.program?.trackingStartRef,
        'Mishnah Berakhot 2:1',
      );
    },
  );

  test('a re-add keeps its prior program and ignores the flow\'s starting ref '
      '(ruling B13)', () async {
    final actions = RecordingAddTrackActions()..reAdded = true;
    await _buildService(actions: actions).createTrack(
      result: const AddTrackResult(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        programId: 99,
        studyDays: {1: 'study'},
        startingRef: 'Mishnah Berakhot 2:1',
      ),
    );

    expect(actions.plans, hasLength(1));
  });

  group('an action queued offline (AD-54)', () {
    const programResult = AddTrackResult(
      curriculumId: CurriculumId.bavli,
      label: 'Bavli',
      programId: 99,
      studyDays: {1: 'study'},
      startingRef: 'Mishnah Berakhot 2:1',
    );

    test(
      'defers the track-added event until the server confirms the track',
      () async {
        final confirmation = Completer<bool>();
        final actions = RecordingAddTrackActions()
          ..queuedConfirmation = confirmation;
        final analytics = FakeAnalyticsService();

        await _buildService(
          actions: actions,
          analytics: analytics,
        ).createTrack(result: programResult);

        expect(actions.plans, hasLength(1));
        expect(analytics.countOf(AnalyticsEvent.trackAdded), 0);

        confirmation.complete(true);
        await pumpEventQueue();

        expect(analytics.countOf(AnalyticsEvent.trackAdded), 1);
      },
    );

    test(
      'a queued action the server later refuses leaves no track-added event',
      () async {
        final confirmation = Completer<bool>();
        final actions = RecordingAddTrackActions()
          ..queuedConfirmation = confirmation;
        final analytics = FakeAnalyticsService();

        await _buildService(
          actions: actions,
          analytics: analytics,
        ).createTrack(result: programResult);
        confirmation.complete(false);
        await pumpEventQueue();

        expect(analytics.countOf(AnalyticsEvent.trackAdded), 0);
      },
    );
  });

  test(
    'a saved (not queued) action fires track-added before createTrack returns',
    () async {
      final analytics = FakeAnalyticsService();
      await _buildService(
        actions: RecordingAddTrackActions(),
        analytics: analytics,
      ).createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          programId: 99,
          studyDays: {1: 'study'},
          startingRef: 'Mishnah Berakhot 2:1',
        ),
      );
      await pumpEventQueue();
      expect(analytics.countOf(AnalyticsEvent.trackAdded), 1);
    },
  );

  test(
    'stages come from the wizard result when the flow supplies one',
    () async {
      final actions = RecordingAddTrackActions();
      await _buildService(actions: actions).createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.mishnayos,
          label: 'Mishnayos',
          studyDays: {1: 'study'},
          wizardResult: LearningProcessWizardResult(
            wizardResult: WizardResult(
              curriculumId: CurriculumId.mishnayos,
              choice: WizardChoice.custom,
              customRounds: [],
            ),
          ),
        ),
      );
      final stages = actions.plans.single.stages;
      expect(stages.map((s) => s.stageOrder), [1]);
    },
  );
}
