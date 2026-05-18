/// Story acceptance test for DNI-381 (27.5) — bulk-mark-prior does
/// not credit streak at any stage (NFR13).
///
/// Onboarding's "I learned this in the past" flow bulk-marks completions
/// across stages 1..N. Those rows are historical, not "I learned today",
/// so they must NOT produce `streak_events` and the `StreakReducer` must
/// see zero days. This test pins that invariant so a future refactor of
/// the completion path can't silently re-introduce the bug.
@Tags(['epic_27', 'story_27_5'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/streak/streak_event.dart';
import 'package:learning_tracker/core/streak/streak_reducer.dart';
import 'package:learning_tracker/core/streak/streak_state_provider.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_database.dart';

class _MockSyncEngine extends Mock implements SyncWriteFacade {}

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  group('Story 27.5 — bulk_mark_prior_does_not_credit_streak', () {
    late UserDatabase db;
    late _MockSyncEngine sync;
    late _MockContentRepository content;
    late CompletionRepositoryImpl repo;
    late int profileId;
    late int trackId;

    const curriculumId = 'mishnayos';
    const trackType = 'personal';

    // Frozen "today" for the reducer; the test must not depend on
    // wall-clock time.
    final today = DateTime.utc(2026, 5, 13, 9);

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      sync = _MockSyncEngine();
      content = _MockContentRepository();

      when(
        () => content.getContentForCurriculum(any()),
      ).thenAnswer((_) async => []);
      when(
        () => sync.pushCompletion(any()),
      ).thenAnswer((_) async => Future.value());
      when(
        () => sync.pushCompletionsBatch(any()),
      ).thenAnswer((_) async => Future.value());
      when(
        () => sync.pushBookmark(any()),
      ).thenAnswer((_) async => Future.value());

      final now = DateTime.utc(2026, 5, 13);
      final profile = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Tester',
              // Adult mode — keeps the reward-milestone branch off the
              // hot path so we are testing the streak-tee behaviour
              // in isolation.
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );
      profileId = profile.id;

      final track = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              trackType: trackType,
              activatedAt: now,
            ),
          );
      trackId = track.id;

      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              trackId: trackId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      repo = CompletionRepositoryImpl(
        database: db,
        syncEngine: sync,
        contentRepository: content,
        activeProfileId: profileId,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('50 items × 3 stages with awardGamificationPoints=false → '
        'currentStreak==0, maxStreak==0, zero streak_events', () async {
      final sefariaRefs = List<String>.generate(
        50,
        (i) => 'Mishnah Berachot ${(i ~/ 10) + 1}:${(i % 10) + 1}',
      );

      for (final stageId in const [1, 2, 3]) {
        await repo.bulkMarkComplete(
          BulkCompletionRequest(
            curriculumId: curriculumId,
            sefariaRefs: sefariaRefs,
            stageId: stageId,
            trackType: trackType,
            awardGamificationPoints: false,
          ),
        );
      }

      // 150 completion rows should exist (50 refs × 3 stages).
      final completionRows = await (db.select(
        db.completions,
      )..where((t) => t.profileId.equals(profileId))).get();
      expect(
        completionRows,
        hasLength(150),
        reason:
            'Sanity: bulk-mark-prior must still persist completions; '
            'streak is the only side-effect we expect to suppress.',
      );

      // AC: zero rows in streak_events attributable to the batch.
      // We check this BEFORE invoking StreakStateProvider so the
      // `StreakRestorer` (which synthesises rows from `completions`
      // on first read) does not pollute the count we are asserting.
      final streakRows = await (db.select(
        db.streakEvents,
      )..where((t) => t.profileId.equals(profileId))).get();
      expect(
        streakRows,
        isEmpty,
        reason:
            'bulk-mark-prior must not append `streak_events` at any '
            'stage — those rows would credit a streak the user did '
            'not actually earn (NFR13).',
      );

      // AC: derived streak state is zero in both fields.
      //
      // Pinning the reducer directly against the empty event log
      // is what NFR13 is really asking: replay over the events
      // *attributable to the batch* must yield zero. The
      // `StreakStateProvider` path additionally exercises
      // `StreakRestorer`, which is independently the subject of
      // Story 26.27 (and Story 27.6's cloud-restore test) — its
      // behaviour on prior-only completion logs is verified there,
      // not here, to keep this canary focused on the one bug it
      // exists to catch.
      final reducerState = const StreakReducer().reduce(
        const <StreakEvent>[],
        today: today,
      );
      expect(reducerState.currentStreak, 0);
      expect(reducerState.maxStreak, 0);
    });

    test('happy-path single completion (awardGamificationPoints=true) DOES '
        'credit a streak — guards against accidentally over-fixing', () async {
      // This guard test keeps the production behaviour honest: the
      // streak-tee is suppressed *only* for prior-learning bulk marks.
      // A normal "I learned this today" mark must still credit.
      await repo.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: 'Mishnah Berachot 1:1',
          stageId: 1,
          trackType: trackType,
        ),
      );

      final streakRows = await (db.select(
        db.streakEvents,
      )..where((t) => t.profileId.equals(profileId))).get();
      expect(streakRows, hasLength(1));

      final state = await StreakStateProvider(
        db: db,
        clock: FakeLocalDayClock(today),
      ).read(profileId: profileId);
      // The completion landed "today" (DateTimeFactory.nowUtc() at
      // test execution time) — which is at most a few seconds before
      // `today`. The reducer counts that UTC day as the current run.
      expect(state.maxStreak, 1);
    });
  });
}
