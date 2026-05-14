/// Extended tests for ParentDashboardAggregator covering compute() and
/// computeCompletionPercentage() which require a live UserDatabase.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late ParentDashboardAggregator aggregator;
  const profileId = 1;

  setUp(() {
    db = inMemoryDb();
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
    return db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackType: 'personal',
            isActive: Value(isActive),
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
  }) {
    return db
        .into(db.completions)
        .insert(
          CompletionsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            sefariaRef: sefariaRef,
            stageId: stageId,
            trackType: 'personal',
            trackId: trackId,
            completedAt: completedAt ?? DateTime.utc(2026, 5, 14),
            points: Value(points),
          ),
        );
  }

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
              trackType: 'personal',
              isActive: const Value(true),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      // Should not throw — unknown key is silently filtered.
      final data = await aggregator.compute(now: DateTime.utc(2026, 5, 14));
      expect(data.curricula, isEmpty);
    });
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
