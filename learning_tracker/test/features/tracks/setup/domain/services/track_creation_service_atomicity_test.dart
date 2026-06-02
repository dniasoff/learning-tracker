// D7: track creation must be atomic — a stage-seed failure mid-creation must
// roll back the track row AND the program-enrolment row (no orphaned 0-stage
// track / dangling profile_programs row).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/drift_memory.dart';

class _MockActivation extends Mock implements CurriculumActivationService {}

class _MockWizard extends Mock implements LearningProcessWizardService {}

class _MockGoalRepo extends Mock implements GoalRepository {}

class _MockStageRepo extends Mock implements StageDefinitionRepository {}

void main() {
  late UserDatabase db;

  setUpAll(() {
    // The B3 back-date tests stub activateForProfile(any(), any()); mocktail
    // needs a fallback for the non-primitive CurriculumId argument.
    registerFallbackValue(CurriculumId.bavli);
    // createTrack now always seeds stages via applyWizardResult (falling back
    // to a noReview/לימוד-only config when no wizard result is supplied), so
    // the positional WizardResult arg needs a mocktail fallback.
    registerFallbackValue(
      const WizardResult(
        curriculumId: CurriculumId.bavli,
        choice: WizardChoice.noReview,
      ),
    );
  });

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // learner_profiles(id = 1)
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'D7: a stage-seed failure rolls back the track AND program rows (atomic)',
    () async {
      final stageRepo = _MockStageRepo();
      // The stage step throws mid-transaction — exactly the profile-less FK
      // failure class that left orphaned rows before the fix.
      when(
        () => stageRepo.deleteStagesForTrack(any()),
      ).thenThrow(Exception('stage-seed boom'));

      final service = TrackCreationService(
        database: db,
        activationService: _MockActivation(),
        wizardService: _MockWizard(),
        goalRepository: _MockGoalRepo(),
        stageRepository: stageRepo,
      );

      const result = AddTrackResult(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        programId: 99, // would create a profile_programs row
        studyDays: {1: 'study'},
      );

      await expectLater(
        service.createTrack(result: result, profileId: 1),
        throwsA(isA<Exception>()),
      );

      // Neither the track row nor the program-enrolment row may survive.
      final tracks = await db.select(db.curriculumTracks).get();
      expect(tracks, isEmpty, reason: 'track row must roll back');
      final programs = await db.profileProgramDao.getProgramsForProfile(1);
      expect(programs, isEmpty, reason: 'program row must roll back');
    },
  );

  // Back-date sign-inversion regression (bug-hunt round 2):
  // The canonical typed grammar (ProgramStartingPosition.toLegacyGrammar) emits
  // a POSITIVE offset for a back-date ("offset:5" = started 5 days ago). The
  // parser previously did nowUtc().add(offset), writing trackingStartDate 5 days
  // in the FUTURE, which made the scheduler skip all task generation (the exact
  // opposite of the B3 back-date→overdue rule). It must resolve to the PAST.
  test('B3: positive back-date offset (typed grammar "offset:5") writes a PAST '
      'trackingStartDate, not a future one', () async {
    final stageRepo = _MockStageRepo();
    when(() => stageRepo.deleteStagesForTrack(any())).thenAnswer((_) async {});

    final activation = _MockActivation();
    when(
      () => activation.activateForProfile(any(), any()),
    ).thenAnswer((_) async {});

    final wizard = _MockWizard();
    when(
      () => wizard.applyWizardResult(
        any(),
        profileId: any(named: 'profileId'),
        trackId: any(named: 'trackId'),
      ),
    ).thenAnswer((_) async {});

    final service = TrackCreationService(
      database: db,
      activationService: activation,
      wizardService: wizard,
      goalRepository: _MockGoalRepo(),
      stageRepository: stageRepo,
    );

    final before = DateTimeFactory.nowUtc();
    const result = AddTrackResult(
      curriculumId: CurriculumId.bavli,
      label: 'Bavli',
      programId: 99,
      studyDays: {1: 'study'},
      // Canonical positive-past convention emitted by
      // ProgramStartingPosition.toLegacyGrammar for a 5-day back-date.
      startingRef: 'offset:5',
    );

    await service.createTrack(result: result, profileId: 1);

    final program = await db.profileProgramDao
        .getProgramForProfileAndCurriculum(1, CurriculumId.bavli.storageKey);
    expect(program, isNotNull, reason: 'program enrolment row must persist');
    final startDate = program!.trackingStartDate;
    expect(startDate, isNotNull, reason: 'a back-date offset must set a date');

    // Must be ~5 days in the PAST, never the future.
    expect(
      startDate!.isBefore(before),
      isTrue,
      reason: 'offset:5 must resolve to 5 days ago, not 5 days from now',
    );
    final daysBack = before.difference(startDate).inDays;
    expect(daysBack, 5, reason: 'offset:5 must be exactly 5 days in the past');
  });

  // The live add-track calendar UI emits the OPPOSITE (negative) sign for a
  // back-date ("offset:-5"). Both producers must land in the past.
  test('B3: negative back-date offset (live UI "offset:-5") also writes a PAST '
      'trackingStartDate', () async {
    final stageRepo = _MockStageRepo();
    when(() => stageRepo.deleteStagesForTrack(any())).thenAnswer((_) async {});

    final activation = _MockActivation();
    when(
      () => activation.activateForProfile(any(), any()),
    ).thenAnswer((_) async {});

    final wizard = _MockWizard();
    when(
      () => wizard.applyWizardResult(
        any(),
        profileId: any(named: 'profileId'),
        trackId: any(named: 'trackId'),
      ),
    ).thenAnswer((_) async {});

    final service = TrackCreationService(
      database: db,
      activationService: activation,
      wizardService: wizard,
      goalRepository: _MockGoalRepo(),
      stageRepository: stageRepo,
    );

    final before = DateTimeFactory.nowUtc();
    const result = AddTrackResult(
      curriculumId: CurriculumId.bavli,
      label: 'Bavli',
      programId: 99,
      studyDays: {1: 'study'},
      startingRef: 'offset:-5',
    );

    await service.createTrack(result: result, profileId: 1);

    final program = await db.profileProgramDao
        .getProgramForProfileAndCurriculum(1, CurriculumId.bavli.storageKey);
    final startDate = program!.trackingStartDate!;
    expect(
      startDate.isBefore(before),
      isTrue,
      reason: 'offset:-5 must resolve to 5 days ago',
    );
    expect(before.difference(startDate).inDays, 5);
  });
}
