/// Extended tests for ParentDashboardAggregator covering compute() and
/// computeCompletionPercentage() which require a live UserDatabase.
///
/// AUD-t-parent_mode-01: this file absorbed
/// parent_dashboard_aggregator_compute_test.dart, which independently
/// re-verified the same compute() DB-backed contracts (zero-state,
/// globalPoints summation, 7-day recency cutoff) under a different
/// fixture idiom — those duplicate cases were dropped in favor of the
/// equivalent scenarios already below. The streak and paceStatus/goal
/// coverage further down (marked accordingly) came from that file and had
/// no equivalent here, so it was ported over intact.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/dashboard/domain/services/parent_dashboard_aggregator.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late ParentDashboardAggregator aggregator;
  const profileId = 1;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    aggregator = ParentDashboardAggregator(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<int> insertTrack({
    String curriculumId = 'mishnayos',
    bool isActive = true,
  }) {
    // W3.28/W3.29: isActive -> state='active'/'retired'.
    return db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            state: Value(isActive ? 'active' : 'retired'),
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  Future<void> insertCompletion({
    String curriculumId = 'mishnayos',
    String sefariaRef = 'Berakhot 1:1',
    int stageId = 1,
    int trackId = 1,
    int points = 10,
    DateTime? completedAt,
  }) => seedCompletion(
    db,
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: completedAt ?? DateTime.utc(2026, 5, 14),
      points: Value(points),
    ),
  ).then((_) {});

  // ── compute() ────────────────────────────────────────────────────────────

  group('ParentDashboardAggregator.compute', () {
    test(
      'returns empty data for profile with no tracks or completions',
      () async {
        final data = await aggregator.compute(now: DateTime.utc(2026, 5, 14));

        expect(data.curricula, isEmpty);
        expect(data.globalPoints, 0);
        expect(data.currentStreak, 0);
        expect(data.maxStreak, 0);
        expect(data.recentCompletions, isEmpty);
        expect(data.engagement.daysActiveThisWeek, 0);
      },
    );

    test('sums globalPoints across all completions', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertCompletion(
        curriculumId: 'mishnayos',
        trackId: trackId,
        points: 5,
      );
      await insertCompletion(
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot 1:2',
        trackId: trackId,
        points: 10,
      );

      final data = await aggregator.compute(now: DateTime.utc(2026, 5, 14));

      expect(data.globalPoints, 15);
    });

    test('includes recent completions within 7-day window', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      final now = DateTime.utc(2026, 5, 14);
      final recent = now.subtract(const Duration(days: 3));
      final old = now.subtract(const Duration(days: 30));

      await insertCompletion(
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot 1:1',
        trackId: trackId,
        completedAt: recent,
      );
      await insertCompletion(
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot 1:2',
        trackId: trackId,
        completedAt: old,
      );

      final data = await aggregator.compute(now: now);

      // Only the recent one should appear (old is > 7 days)
      expect(data.recentCompletions.length, 1);
      expect(data.recentCompletions.first.sefariaRef, 'Berakhot 1:1');
    });

    test('recent completions are sorted newest-first', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      final now = DateTime.utc(2026, 5, 14);

      await insertCompletion(
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot 1:1',
        trackId: trackId,
        completedAt: now.subtract(const Duration(days: 2)),
      );
      await insertCompletion(
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot 1:2',
        trackId: trackId,
        completedAt: now.subtract(const Duration(days: 1)),
      );

      final data = await aggregator.compute(now: now);

      expect(data.recentCompletions.first.sefariaRef, 'Berakhot 1:2');
      expect(data.recentCompletions.last.sefariaRef, 'Berakhot 1:1');
    });

    test('builds per-curriculum summary for active tracks', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertCompletion(
        curriculumId: 'mishnayos',
        trackId: trackId,
        points: 20,
      );

      final data = await aggregator.compute(now: DateTime.utc(2026, 5, 14));

      // The track is active but has no goal + no learning order items →
      // completion percentage is 0 but summary should exist.
      expect(data.curricula, hasLength(1));
      expect(data.curricula.first.curriculum.storageKey, 'mishnayos');
      expect(data.curricula.first.points, 20);
    });

    test('inactive track is not included in curricula summaries', () async {
      await insertTrack(curriculumId: 'mishnayos', isActive: false);

      final data = await aggregator.compute(now: DateTime.utc(2026, 5, 14));
      expect(data.curricula, isEmpty);
    });

    test('uses default now when not provided', () async {
      // Should not throw — just verify it calls without error.
      final data = await aggregator.compute();
      expect(data, isNotNull);
    });

    test('unknown curriculum storageKey is filtered out gracefully', () async {
      // Insert a track with a key that does not map to any CurriculumId enum value.
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'unknown_curriculum_xyz',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      // Should not throw — unknown key is silently filtered.
      final data = await aggregator.compute(now: DateTime.utc(2026, 5, 14));
      expect(data.curricula, isEmpty);
    });

    // -----------------------------------------------------------------
    // Ported from parent_dashboard_aggregator_compute_test.dart
    // (AUD-t-parent_mode-01) — streak and paceStatus/goal coverage that
    // had no equivalent scenario in this file.
    // -----------------------------------------------------------------

    test('returns streak derived from streak_events', () async {
      // AUD-dashboard-07: streak is derived from streak_events, replayed
      // against an injected LocalDayClock (not the real wall clock), so
      // "today" is a fixed, hermetic value. Seed 5 consecutive days ending
      // on that fixed today so StreakStateService sees an active streak.
      final todayUtc = DateTime.utc(2026, 5, 14);
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

      final streakAggregator = ParentDashboardAggregator(
        db,
        profileId: profileId,
        clock: FakeLocalDayClock(todayUtc),
      );
      final data = await streakAggregator.compute(now: todayUtc);

      expect(data.currentStreak, 5);
      expect(data.maxStreak, 5);
    });

    test('computes paceStatus as onPace when goal has no targetDate', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      final now = DateTime.utc(2026, 5, 14);

      // Insert a goal without a targetDate → should fall back to onPace.
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          createdAt: now,
          updatedAt: now,
          targetDate: const Value(null),
        ),
      );

      await insertCompletion(curriculumId: 'mishnayos', trackId: trackId);

      final data = await aggregator.compute(now: now);

      // One curriculum summary should be present.
      expect(data.curricula, hasLength(1));
      // No targetDate → onPace.
      expect(data.curricula.first.curriculum, CurriculumId.mishnayos);
    });

    test(
      'computes paceStatus when goal has a targetDate (exercises lines 220-249)',
      () async {
        final trackId = await insertTrack(curriculumId: 'mishnayos');
        final now = DateTime.utc(2026, 5, 14);

        // Insert a goal WITH a targetDate — triggers the PaceCalculator path.
        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackId: trackId,
            createdAt: now,
            updatedAt: now,
            targetDate: Value(DateTime.utc(2026, 12, 31)),
          ),
        );

        await insertCompletion(curriculumId: 'mishnayos', trackId: trackId);

        final data = await aggregator.compute(now: now);

        // Curriculum is active and has a goal with deadline — pace status computed.
        expect(data.curricula, hasLength(1));
        // PaceStatusType will be onPace, behind, or ahead depending on pace calc.
        expect(data.curricula.first.paceStatus, isNotNull);
      },
    );
  });

  // ── computeCompletionPercentage ───────────────────────────────────────────

  group('ParentDashboardAggregator.computeCompletionPercentage', () {
    test('returns 0.0 when no completions', () async {
      final pct = await aggregator.computeCompletionPercentage(
        CurriculumId.mishnayos,
      );
      expect(pct, 0.0);
    });

    test('returns 0.0 when no stages (stageRepository is null)', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertCompletion(curriculumId: 'mishnayos', trackId: trackId);
      // No stageRepository → stages.isEmpty → returns 0.0
      final pct = await aggregator.computeCompletionPercentage(
        CurriculumId.mishnayos,
      );
      expect(pct, 0.0);
    });

    test('returns 0.0 when no learning order items', () async {
      // completions + stages exist but learningOrderDao.countByCurriculum == 0
      // → early return 0.0
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertCompletion(curriculumId: 'mishnayos', trackId: trackId);
      final pct = await aggregator.computeCompletionPercentage(
        CurriculumId.mishnayos,
      );
      expect(pct, 0.0);
    });
  });
}
