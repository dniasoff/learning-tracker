/// Regression tests for the W1-B chart-data fixes (tasks #2/#3/#5/#6).
///
/// Covers:
///   #2 — Chart tier switch from liveOnly to trackAchievement
///        (bulkInTrack rows now visible on charts).
///   #3 — "All Time" range > 60 days returns weekly-bucketed data
///        (capped to the user's first matching completion).
///   #5 — getStreakCalendar pushes the date filter to SQL — the returned
///        Set respects the requested bounds even when many rows exist
///        outside the range.
///   #6 — getDailyCompletions / getCumulativeProgress / getDailyPoints
///        push since/until to SQL (the result respects the bounds even
///        when out-of-range rows exist; the response time stays bounded
///        because we don't scan the entire history in Dart).
@Tags(['progress', 'w1b'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;

Future<int> _seedTrack(UserDatabase db) async {
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: _profileId,
          curriculumId: 'mishnayos',
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
}

Future<void> _seedLive(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required DateTime at,
  int points = 10,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: 'mishnayos',
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
      points: Value(points),
    ),
  );
}

Future<void> _seedBulkInTrack(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required DateTime at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: 'mishnayos',
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: 'mishnayos',
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      source: 'bulkInTrack',
    ),
  ]);
}

Future<void> _seedLifetimeOnly(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required DateTime at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: 'mishnayos',
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: 'mishnayos',
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      source: 'lifetimeOnly',
    ),
  ]);
}

void main() {
  late UserDatabase db;
  late int trackId;
  late ChartDataService service;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await _seedTrack(db);
    service = ChartDataService(db, profileId: _profileId);
  });

  tearDown(() => db.close());

  // ===========================================================================
  // Task #2 — trackAchievement tier
  // ===========================================================================

  group('#2 chart tier — trackAchievement', () {
    test('includes both live AND bulkInTrack; excludes lifetimeOnly', () async {
      // One of each tier on the SAME day for clean assertions.
      final day = DateTime(2026, 3, 15, 9);
      await _seedLive(db, trackId: trackId, ref: 'live1', at: day);
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk1', at: day);
      await _seedLifetimeOnly(db, trackId: trackId, ref: 'lt1', at: day);

      final result = await service.getDailyCompletions(
        startDate: DateTime(2026, 3, 15),
        endDate: DateTime(2026, 3, 15),
      );

      expect(result, hasLength(1));
      expect(
        result.first.count,
        2,
        reason:
            'live + bulkInTrack = 2 charted; lifetimeOnly is excluded under '
            'trackAchievement (#2 contract)',
      );
    });

    test('getCumulativeProgress applies the same tier contract', () async {
      final day = DateTime(2026, 3, 15, 9);
      await _seedLive(db, trackId: trackId, ref: 'live1', at: day);
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk1', at: day);
      await _seedLifetimeOnly(db, trackId: trackId, ref: 'lt1', at: day);

      final result = await service.getCumulativeProgress(
        startDate: DateTime(2026, 3, 15),
        endDate: DateTime(2026, 3, 15),
      );

      expect(result, hasLength(1));
      expect(
        result.first.total,
        2,
        reason: 'cumulative = 2 (live + bulkInTrack), lifetimeOnly excluded',
      );
    });
  });

  // ===========================================================================
  // Task #3 — "All Time" bucketing
  // ===========================================================================

  group('#3 All Time range bucketing', () {
    test(
      'spans > kChartDailyMaxDays produce weekly buckets ≤ 520 points',
      () async {
        // Seed at least one live row near today so the effective-start is
        // a recent date.
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'ref1',
          at: DateTime(2026, 5, 1, 10),
        );

        // Request "All Time" — from 2000-01-01 to today. Pre-W1-B this
        // would produce ~9,600 daily points; post-W1-B it must be capped
        // and bucketed.
        final result = await service.getDailyCompletions(
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2026, 5, 20),
        );

        expect(
          result.length,
          lessThanOrEqualTo(520),
          reason:
              'All-time chart must never exceed ~520 weekly buckets '
              '(10 years × 52 weeks)',
        );
      },
    );

    test('weekly buckets have 7-calendar-day boundaries', () async {
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'ref1',
        at: DateTime(2026, 1, 1, 10),
      );

      final result = await service.getDailyCompletions(
        startDate: DateTime(2000, 1, 1),
        endDate: DateTime(2026, 5, 20),
      );

      // Each pair of consecutive buckets must be exactly 7 calendar days
      // apart. Use a DST-safe comparison (hours/24 rounded) rather than
      // `inDays`, which rounds toward zero across DST transitions.
      int calendarDays(DateTime a, DateTime b) =>
          (b.difference(a).inHours / 24).round();

      for (var i = 1; i < result.length; i++) {
        expect(
          calendarDays(result[i - 1].date, result[i].date),
          equals(7),
          reason: 'weekly bucket boundaries must be 7 calendar days apart',
        );
      }
    });

    test(
      'effective start caps to earliest completion when range > 60 days',
      () async {
        // First live completion on 2026-01-15. Pre-W1-B the chart would
        // start at 2000-01-01 with thousands of empty buckets; post-W1-B
        // it should start at or near 2026-01-15.
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'first',
          at: DateTime(2026, 1, 15, 10),
        );

        final result = await service.getDailyCompletions(
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2026, 5, 20),
        );

        expect(result, isNotEmpty);
        // First bucket date must be at or after the earliest completion's
        // local date (2026-01-15) — NOT 2000-01-01.
        expect(
          result.first.date.year,
          greaterThanOrEqualTo(2025),
          reason:
              'effective start MUST be capped to the earliest completion, '
              'not the requested 2000-01-01',
        );
      },
    );

    test('range ≤ kChartDailyMaxDays still gets daily granularity', () async {
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'ref1',
        at: DateTime(2026, 5, 10, 10),
      );

      final result = await service.getDailyCompletions(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 30),
      );

      // 30-day range → 30 daily buckets, not weekly.
      expect(result, hasLength(30));
      // DST-safe comparison.
      int calendarDays(DateTime a, DateTime b) =>
          (b.difference(a).inHours / 24).round();
      for (var i = 1; i < result.length; i++) {
        expect(
          calendarDays(result[i - 1].date, result[i].date),
          equals(1),
          reason: 'short ranges use daily granularity',
        );
      }
    });

    test('cumulative chart also bucketizes for long ranges', () async {
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'ref1',
        at: DateTime(2026, 1, 1, 10),
      );
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'ref2',
        at: DateTime(2026, 3, 1, 10),
      );
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'ref3',
        at: DateTime(2026, 5, 1, 10),
      );

      final result = await service.getCumulativeProgress(
        startDate: DateTime(2000, 1, 1),
        endDate: DateTime(2026, 5, 20),
      );

      expect(
        result.length,
        lessThanOrEqualTo(520),
        reason: 'cumulative chart must also bucketize for long ranges',
      );
      // Final bucket total must equal full cumulative count.
      expect(
        result.last.total,
        3,
        reason: '3 live completions over the all-time window',
      );
    });

    test(
      'zero matching rows in long window collapses to one trailing bucket',
      () async {
        // No completions at all — long range must still return a tiny
        // result, NOT 9,600 empty days.
        final result = await service.getDailyCompletions(
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2026, 5, 20),
        );

        expect(
          result.length,
          lessThanOrEqualTo(2),
          reason:
              'empty long-window query must collapse to ≤ 2 buckets — not '
              'iterate 9,600 days',
        );
      },
    );
  });

  // ===========================================================================
  // Task #5 — getStreakCalendar pushes date filter to SQL
  // ===========================================================================

  group('#5 getStreakCalendar SQL date filter', () {
    test(
      'returned set respects [start, end] bounds at the SQL layer',
      () async {
        // One completion INSIDE the requested window, one BEFORE, one AFTER.
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'inside',
          at: DateTime(2026, 3, 15, 10),
        );
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'before',
          at: DateTime(2026, 2, 1, 10),
        );
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'after',
          at: DateTime(2026, 5, 1, 10),
        );

        final result = await service.getStreakCalendar(
          startDate: DateTime(2026, 3, 10),
          endDate: DateTime(2026, 3, 20),
        );

        // ONLY the inside completion's date should appear — the before/after
        // are filtered out at the SQL `since`/`until` layer, not in Dart.
        expect(result, equals({DateTime(2026, 3, 15)}));
      },
    );

    test('returns empty when no completions in window', () async {
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'far_before',
        at: DateTime(2026, 1, 1, 10),
      );

      final result = await service.getStreakCalendar(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 7),
      );

      expect(result, isEmpty);
    });

    test('includes bulkInTrack rows on the streak calendar', () async {
      await _seedBulkInTrack(
        db,
        trackId: trackId,
        ref: 'bulk1',
        at: DateTime(2026, 3, 15, 10),
      );

      final result = await service.getStreakCalendar(
        startDate: DateTime(2026, 3, 15),
        endDate: DateTime(2026, 3, 15),
      );

      expect(
        result,
        contains(DateTime(2026, 3, 15)),
        reason:
            'streak calendar uses trackAchievement tier; bulkInTrack '
            'rows must light up days too',
      );
    });

    test('lifetimeOnly rows do NOT light up the streak calendar', () async {
      await _seedLifetimeOnly(
        db,
        trackId: trackId,
        ref: 'lt1',
        at: DateTime(2026, 3, 15, 10),
      );

      final result = await service.getStreakCalendar(
        startDate: DateTime(2026, 3, 15),
        endDate: DateTime(2026, 3, 15),
      );

      expect(
        result,
        isEmpty,
        reason:
            'lifetimeOnly imports must not appear on per-track charts '
            'including the streak calendar',
      );
    });
  });

  // ===========================================================================
  // Task #6 — SQL since/until pushdown
  // ===========================================================================

  group('#6 SQL since/until pushdown (date filter respects bounds)', () {
    test(
      'getDailyCompletions: out-of-range rows are not summed into in-range buckets',
      () async {
        // Out of range (BEFORE).
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'before',
          at: DateTime(2026, 1, 1, 10),
        );
        // Out of range (AFTER).
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'after',
          at: DateTime(2026, 6, 1, 10),
        );
        // In range.
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'inside',
          at: DateTime(2026, 3, 15, 10),
        );

        final result = await service.getDailyCompletions(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 31),
        );

        // 31-day range → daily buckets.
        expect(result, hasLength(31));
        final total = result.fold<int>(0, (sum, d) => sum + d.count);
        expect(
          total,
          1,
          reason:
              'only the inside completion must count — before/after are '
              'filtered by the SQL since/until bounds (#6)',
        );
      },
    );

    test(
      'getCumulativeProgress: cumulativeBeforeStart counts ONLY pre-window completions',
      () async {
        // 2 completions before the window — must seed cumulativeBeforeStart = 2.
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'b1',
          at: DateTime(2026, 1, 1, 10),
        );
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'b2',
          at: DateTime(2026, 2, 1, 10),
        );
        // 1 completion AFTER the window — must NOT count anywhere.
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'after',
          at: DateTime(2026, 6, 1, 10),
        );
        // 1 completion in the window.
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'inside',
          at: DateTime(2026, 3, 15, 10),
        );

        final result = await service.getCumulativeProgress(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 31),
        );

        expect(result, hasLength(31));
        // First day: cumulativeBeforeStart = 2 (the 2 b1+b2 rows).
        expect(result.first.total, 2);
        // Last day: 2 + 1 = 3 (the inside completion). After-row excluded.
        expect(result.last.total, 3);
      },
    );

    test(
      'getDailyPoints uses liveOnly and excludes out-of-range rows',
      () async {
        // bulkInTrack must not earn points; out-of-range live row must
        // not be summed in.
        await _seedBulkInTrack(
          db,
          trackId: trackId,
          ref: 'bulk',
          at: DateTime(2026, 3, 15, 10),
        );
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'inside',
          at: DateTime(2026, 3, 15, 10),
          points: 7,
        );
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'after',
          at: DateTime(2026, 6, 1, 10),
          points: 99,
        );

        final result = await service.getDailyPoints(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 31),
          userMode: ProfileMode.child,
        );

        expect(result, isNotNull);
        final total = result!.fold<int>(0, (sum, d) => sum + d.points);
        expect(
          total,
          7,
          reason:
              'only the inside live row (7 points) counts — bulkInTrack '
              'earns no points (liveOnly tier) and after-row is filtered '
              'out by SQL bounds',
        );
      },
    );

    test(
      'getStreakCalendar respects SQL bounds even when many out-of-range rows exist',
      () async {
        // Seed 30 rows outside the window, one inside.
        for (var i = 0; i < 30; i++) {
          await _seedLive(
            db,
            trackId: trackId,
            ref: 'outside_$i',
            at: DateTime(2025, 1, 1).add(Duration(days: i)),
          );
        }
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'inside',
          at: DateTime(2026, 3, 15, 10),
        );

        final result = await service.getStreakCalendar(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 31),
        );

        expect(
          result,
          hasLength(1),
          reason:
              'SQL bounds must filter out the 30 out-of-range rows; only '
              'the inside row is returned',
        );
        expect(result.first, DateTime(2026, 3, 15));
      },
    );
  });
}
