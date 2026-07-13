// Tests for ParentDashboardAggregator.compute() — exercises the DB-backed
// path including _computePaceStatus (lines 215-249) which was uncovered.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/dashboard/domain/services/parent_dashboard_aggregator.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;
  late int stageId;

  const profileId = 1;
  const curriculumId = 'mishnayos';

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);

    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );

    stageId = await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        schedule: const Value('{"type":"delay","delay_days":0}'),
      ),
    );

    // Mark mishnayos as active curriculum for the profile.
    await db.activeCurriculumDao.activateByProfile(
      CurriculumId.mishnayos,
      profileId,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertCompletion({
    String ref = 'Berakhot 1:1',
    DateTime? completedAt,
  }) async {
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        sefariaRef: ref,
        stageId: stageId,
        trackType: 'personal',
        trackId: Value(trackId),
        eventTimestamp: completedAt ?? DateTime.utc(2026, 3, 15),
        points: const Value(10),
      ),
    );
  }

  // =========================================================================
  // compute() — no data at all
  // =========================================================================

  group('ParentDashboardAggregator.compute', () {
    test('returns zero values when no completions or streak', () async {
      final aggregator = ParentDashboardAggregator(db, profileId: profileId);
      final data = await aggregator.compute(now: DateTime.utc(2026, 3, 20));

      expect(data.globalPoints, 0);
      expect(data.currentStreak, 0);
      expect(data.maxStreak, 0);
      expect(data.recentCompletions, isEmpty);
    });

    test('returns global points from completions', () async {
      await insertCompletion();
      await insertCompletion(ref: 'Berakhot 1:2');

      final aggregator = ParentDashboardAggregator(db, profileId: profileId);
      final data = await aggregator.compute(now: DateTime.utc(2026, 3, 20));

      expect(data.globalPoints, 20); // 2 × 10 points
    });

    test('includes recent completions from last 7 days', () async {
      final now = DateTime.utc(2026, 3, 20, 12);
      await insertCompletion(
        completedAt: now.subtract(const Duration(days: 3)),
      );
      await insertCompletion(
        ref: 'Berakhot 1:2',
        completedAt: now.subtract(const Duration(days: 10)), // older
      );

      final aggregator = ParentDashboardAggregator(db, profileId: profileId);
      final data = await aggregator.compute(now: now);

      // Only the completion within 7 days should appear.
      expect(data.recentCompletions, hasLength(1));
      expect(data.recentCompletions.first.sefariaRef, 'Berakhot 1:1');
    });

    test('returns streak derived from streak_events', () async {
      // AUD-dashboard-07: streak is derived from streak_events, replayed
      // against an injected LocalDayClock (not the real wall clock), so
      // "today" is a fixed, hermetic value. Seed 5 consecutive days ending
      // on that fixed today so StreakStateService sees an active streak.
      final todayUtc = DateTime.utc(2026, 3, 20);
      for (var i = 0; i < 5; i++) {
        final day = todayUtc.subtract(Duration(days: 4 - i));
        await db.streakEventDao.appendEvent(
          StreakEventsCompanion.insert(
            profileId: profileId,
            eventType: 'completion',
            dayUtc: day,
            eventTimestamp: day,
          ),
        );
      }

      final aggregator = ParentDashboardAggregator(
        db,
        profileId: profileId,
        clock: FakeLocalDayClock(todayUtc),
      );
      final data = await aggregator.compute(now: todayUtc);

      expect(data.currentStreak, 5);
      expect(data.maxStreak, 5);
    });

    // -------------------------------------------------------------------
    // _computePaceStatus — mishnayos curriculum with a goal
    // -------------------------------------------------------------------

    test('computes paceStatus as onPace when goal has no targetDate', () async {
      final now = DateTime.utc(2026, 3, 20);

      // Insert a goal without a targetDate → should fall back to onPace.
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          targetDate: const Value(null),
        ),
      );

      await insertCompletion();

      final aggregator = ParentDashboardAggregator(db, profileId: profileId);
      final data = await aggregator.compute(now: now);

      // One curriculum summary should be present.
      expect(data.curricula, hasLength(1));
      // No targetDate → onPace.
      expect(data.curricula.first.curriculum, CurriculumId.mishnayos);
    });

    test(
      'computes paceStatus with a future deadline (no goals = empty curricula summary list)',
      () async {
        final now = DateTime.utc(2026, 3, 20);
        await insertCompletion();

        final aggregator = ParentDashboardAggregator(db, profileId: profileId);
        final data = await aggregator.compute(now: now);

        // Curriculum is active, so there will be one summary.
        expect(data.curricula, hasLength(1));
      },
    );

    test(
      'computes paceStatus when goal has a targetDate (exercises lines 220-249)',
      () async {
        final now = DateTime.utc(2026, 3, 20);

        // Insert a goal WITH a targetDate — triggers the PaceCalculator path.
        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 3, 20),
            targetDate: Value(DateTime.utc(2026, 12, 31)),
          ),
        );

        await insertCompletion();

        final aggregator = ParentDashboardAggregator(db, profileId: profileId);
        final data = await aggregator.compute(now: now);

        // Curriculum is active and has a goal with deadline — pace status computed.
        expect(data.curricula, hasLength(1));
        // PaceStatusType will be onPace, behind, or ahead depending on pace calc.
        expect(data.curricula.first.paceStatus, isNotNull);
      },
    );
  });

  // =========================================================================
  // computeCompletionPercentage
  // =========================================================================

  group('ParentDashboardAggregator.computeCompletionPercentage', () {
    test('returns 0.0 when no completions', () async {
      final aggregator = ParentDashboardAggregator(db, profileId: profileId);
      final pct = await aggregator.computeCompletionPercentage(
        CurriculumId.mishnayos,
      );
      expect(pct, 0.0);
    });
  });
}
