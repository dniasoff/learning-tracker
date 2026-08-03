// D7: track creation must be atomic — a stage-seed failure mid-creation must
// roll back the track row AND the program-enrolment row (no orphaned 0-stage
// track / dangling profile_programs row).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/drift_memory.dart';
import '../../../../../helpers/fake_clock.dart';

class _MockActivation extends Mock implements CurriculumActivationService {}

class _MockWizard extends Mock implements LearningProcessWizardService {}

class _MockGoalRepo extends Mock implements GoalRepository {}

class _MockStageRepo extends Mock implements StageDefinitionRepository {}

class _MockBookmarkRepo extends Mock implements BookmarkRepository {}

/// A real (non-mock) in-memory [BookmarkRepository] — used by the F1
/// regression test below to prove the bookmark written by [createTrack] is
/// actually READABLE back through the same repository interface the rest of
/// the app uses (`getBookmark`), not just that some method was called with
/// the right arguments.
class _InMemoryBookmarkRepo implements BookmarkRepository {
  final Map<CurriculumId, BookmarkEntity> _store = {};

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
  }) async => _store[curriculumId];

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final entity = BookmarkEntity(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      updatedAt: DateTimeFactory.nowUtc(),
    );
    _store[curriculumId] = entity;
    return entity;
  }

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) => throw UnimplementedError('not exercised by TrackCreationService');

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
  }) => throw UnimplementedError('not exercised by TrackCreationService');
}

/// A [_MockBookmarkRepo] with `setBookmark` stubbed to echo back its
/// arguments as a [BookmarkEntity] — used by the B3 back-date tests below,
/// whose `startingRef` (e.g. "offset:5") resolves to a non-empty
/// `bookmarkRef`, which reaches `createTrack`'s `setBookmark` call.
_MockBookmarkRepo _stubbedBookmarkRepo() {
  final repo = _MockBookmarkRepo();
  when(
    () => repo.setBookmark(
      curriculumId: any(named: 'curriculumId'),
      sefariaRef: any(named: 'sefariaRef'),
    ),
  ).thenAnswer(
    (invocation) async => BookmarkEntity(
      curriculumId: invocation.namedArguments[#curriculumId] as CurriculumId,
      sefariaRef: invocation.namedArguments[#sefariaRef] as String,
      updatedAt: DateTimeFactory.nowUtc(),
    ),
  );
  return repo;
}

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
        // No startingRef below → bookmarkRef stays null → setBookmark is
        // never reached (and the stage-seed throw happens first anyway).
        bookmarkRepository: _MockBookmarkRepo(),
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
    when(
      () => stageRepo.pushStagesForTrack(
        trackId: any(named: 'trackId'),
        curriculumId: any(named: 'curriculumId'),
      ),
    ).thenAnswer((_) async {});

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
      bookmarkRepository: _stubbedBookmarkRepo(),
    );

    // AUD-t-tracks-04 (TQ-6): freeze the clock the SUT reads via
    // DateTimeFactory.nowUtc() (_parseProgramStartingRef) so the test's
    // 'before' read and the SUT's internal 'now' read are the IDENTICAL
    // instant. Without this, two independent real-clock reads straddling a
    // whole-second boundary (SQLite's DateTimeColumn truncates to whole
    // seconds) makes daysBack legitimately compute to 4 instead of 5 —
    // reproduced deterministically with a >1s artificial delay between the
    // reads before this fix.
    final fixedNow = DateTime.utc(2026, 6, 15, 12);
    installFakeClock(fixedNow);

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

    // Regression guard: with the clock frozen, an artificial delay between
    // setup and the SUT invocation must be a no-op — proves the test no
    // longer depends on two real-clock reads landing in the same tick.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

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
    when(
      () => stageRepo.pushStagesForTrack(
        trackId: any(named: 'trackId'),
        curriculumId: any(named: 'curriculumId'),
      ),
    ).thenAnswer((_) async {});

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
      bookmarkRepository: _stubbedBookmarkRepo(),
    );

    // AUD-t-tracks-04 (TQ-6): see the sibling positive-offset test above for
    // why the clock must be frozen (both B3 tests are "sites" of the same
    // finding).
    final fixedNow = DateTime.utc(2026, 6, 15, 12);
    installFakeClock(fixedNow);

    final before = DateTimeFactory.nowUtc();
    const result = AddTrackResult(
      curriculumId: CurriculumId.bavli,
      label: 'Bavli',
      programId: 99,
      studyDays: {1: 'study'},
      startingRef: 'offset:-5',
    );

    // Regression guard: with the clock frozen, an artificial delay between
    // setup and the SUT invocation must be a no-op.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

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

  // F1 regression (confirmed blocker): the initial bookmark for a
  // program-based track was previously written to Drift
  // (bookmarkDao.upsertBookmarkByProfile) and pushed via the int-profileId
  // outbox path — NEITHER of which the Firestore reader (ULID-profile-keyed)
  // ever reads. A learner choosing "Mishnah Berakhot 2:1" as their starting
  // position would see `getBookmark` return null, and the next completion
  // (of a DIFFERENT ref) would silently overwrite their chosen start. The
  // fix routes the write through the same BookmarkRepository the reader
  // uses. This test proves the ref is readable back through that repository
  // — not merely that some write call happened.
  test('F1: program-track creation writes the initial bookmark through '
      'BookmarkRepository.setBookmark, readable via the SAME repository '
      '(regression: previously landed on Drift / the int-keyed outbox path, '
      'invisible to the Firestore reader)', () async {
    final stageRepo = _MockStageRepo();
    when(() => stageRepo.deleteStagesForTrack(any())).thenAnswer((_) async {});
    when(
      () => stageRepo.pushStagesForTrack(
        trackId: any(named: 'trackId'),
        curriculumId: any(named: 'curriculumId'),
      ),
    ).thenAnswer((_) async {});

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

    final bookmarkRepo = _InMemoryBookmarkRepo();

    final service = TrackCreationService(
      database: db,
      activationService: activation,
      wizardService: wizard,
      goalRepository: _MockGoalRepo(),
      stageRepository: stageRepo,
      bookmarkRepository: bookmarkRepo,
    );

    const startingRef = 'Mishnah Berakhot 2:1';
    const result = AddTrackResult(
      curriculumId: CurriculumId.bavli,
      label: 'Bavli',
      programId: 99,
      studyDays: {1: 'study'},
      startingRef: startingRef,
    );

    await service.createTrack(result: result, profileId: 1);

    // Readable back through the exact repository the rest of the app
    // (completion flow, dashboard) reads bookmarks from.
    final bookmark = await bookmarkRepo.getBookmark(
      curriculumId: CurriculumId.bavli,
    );
    expect(
      bookmark,
      isNotNull,
      reason: 'the chosen starting ref must be readable via BookmarkRepository',
    );
    expect(bookmark!.sefariaRef, startingRef);

    // Nothing writes the Drift bookmark table anymore — the old dead
    // write path is gone, not just bypassed.
    final driftBookmarks = await db.bookmarkDao.getAllBookmarks();
    expect(
      driftBookmarks,
      isEmpty,
      reason:
          'createTrack must no longer write bookmarks to Drift — the '
          'Firestore-backed BookmarkRepository is the only writer now',
    );
  });
}
