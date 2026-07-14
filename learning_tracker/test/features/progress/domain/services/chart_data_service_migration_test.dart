/// Regression tests for the trackAchievement chart-tier switch (W1-B / Phase A)
/// and the follow-on W1-B chart-data fixes (tasks #2/#3/#5/#6).
///
/// Pre-W1-B:
/// - Charts used [CompletionTierFilter.liveOnly] — excluded both
///   bulkInTrack and lifetimeOnly via LEFT JOIN on prior_completion_imports.
///
/// Post-W1-B:
/// - Charts use [CompletionTierFilter.trackAchievement] — includes live
///   AND bulkInTrack; still excludes lifetimeOnly. Aligns with the policy
///   "bulk marks within tracks are equivalent to live learning except no
///   streak/points — they SHOULD show in charts and siyumim".
///
/// Consolidated per AUD-t-progress-03 (Fowler duplication / AG-5 — one
/// mirrored test suite per source file): this file previously had two
/// siblings, chart_data_service_sentinel_test.dart and
/// chart_data_service_w1b_test.dart, that reimplemented the identical
/// "bulkInTrack charted, lifetimeOnly excluded" W1-B tier contract tested
/// above (fix-wave churn — a coverage request spawned a new file instead of
/// extending this one). Their duplicate cases were dropped; each file's one
/// genuinely unique contribution is folded in:
///   - sentinel_test.dart's "sentinel-stamped row WITHOUT import record is
///     treated as live" case → the `sentinel timestamp fallback` group below.
///   - w1b_test.dart's Task #3 (All Time bucketing), #5 (getStreakCalendar
///     SQL date filter) and #6 (SQL since/until pushdown) groups, which
///     cover behavior no other chart_data_service test file exercises.
///     w1b_test.dart's own Task #2 group was a third, unmentioned near-
///     duplicate of the tier contract above and was dropped rather than
///     moved.
/// Both source files are deleted.
@Tags(['progress', 'migration', 'layer3'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumId = 'mishnayos';

final _liveAt = DateTime.utc(2026, 5, 10, 10);
final _bulkAt = DateTime.utc(2000, 1, 1);

final _startDate = DateTime(2026, 5, 1);
final _endDate = DateTime(2026, 5, 31);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _seedLive(
  UserDatabase db, {
  required int trackId,
  required String ref,
  DateTime? at,
  int points = 10,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at ?? _liveAt,
      points: Value(points),
    ),
  );
}

Future<void> _seedBulkInTrack(
  UserDatabase db, {
  required int trackId,
  required String ref,
  DateTime? at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at ?? _bulkAt,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
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
  DateTime? at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at ?? _bulkAt,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      source: 'lifetimeOnly',
    ),
  ]);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late int trackId;
  late ChartDataService service;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumId,
    );
    service = ChartDataService(db, profileId: _profileId);
  });

  tearDown(() => db.close());

  group('ChartDataService.getDailyCompletions trackAchievement tier', () {
    test('live-only: counts unchanged from pre-W1-B', () async {
      await _seedLive(db, trackId: trackId, ref: 'ref1');
      await _seedLive(db, trackId: trackId, ref: 'ref2');

      final result = await service.getDailyCompletions(
        startDate: _startDate,
        endDate: _endDate,
      );

      final day10 = result.firstWhere((d) => d.date.day == 10);
      expect(day10.count, 2, reason: 'two live completions on May 10');

      final otherDays = result.where((d) => d.date.day != 10);
      expect(
        otherDays.every((d) => d.count == 0),
        isTrue,
        reason: 'no completions on other days',
      );
    });

    test('bulkInTrack rows: INCLUDED on the chart (W1-B / Phase A)', () async {
      // bulkInTrack rows now count under trackAchievement tier — these
      // represent real per-track learning even though they do not earn
      // streak/points.
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk1');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk2');

      // bulkInTrack rows are stamped on _bulkAt = 2000-01-01.
      final result = await service.getDailyCompletions(
        startDate: DateTime(2000, 1, 1),
        endDate: DateTime(2000, 1, 1),
      );

      expect(result, hasLength(1));
      expect(
        result.first.count,
        2,
        reason:
            'bulkInTrack rows MUST appear on the chart under '
            'trackAchievement tier',
      );
    });

    test('lifetimeOnly rows: still EXCLUDED', () async {
      await _seedLifetimeOnly(db, trackId: trackId, ref: 'lt1');

      final result = await service.getDailyCompletions(
        startDate: DateTime(1990, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      expect(
        result.every((d) => d.count == 0),
        isTrue,
        reason: 'lifetimeOnly rows excluded under trackAchievement tier',
      );
    });

    test(
      'mixed: live + bulkInTrack both counted, lifetimeOnly excluded',
      () async {
        // Live on May 10.
        await _seedLive(db, trackId: trackId, ref: 'live1');
        // bulkInTrack on 2000-01-01 (the bulk epoch).
        await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk1');
        // lifetimeOnly on 2000-01-01.
        await _seedLifetimeOnly(db, trackId: trackId, ref: 'lt1');

        final result = await service.getDailyCompletions(
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2026, 12, 31),
        );

        // For a >60d range the service buckets weekly. We just assert the
        // totals match what we expect across the entire window.
        final total = result.fold<int>(0, (sum, d) => sum + d.count);
        expect(
          total,
          2,
          reason:
              'one live + one bulkInTrack = 2 charted; lifetimeOnly excluded',
        );
      },
    );
  });

  group('ChartDataService.getCumulativeProgress trackAchievement tier', () {
    test('live-only: cumulative unchanged from pre-W1-B', () async {
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'ref1',
        at: DateTime.utc(2026, 5, 5, 10),
      );
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'ref2',
        at: DateTime.utc(2026, 5, 10, 10),
      );

      final result = await service.getCumulativeProgress(
        startDate: _startDate,
        endDate: _endDate,
      );

      final day4 = result.firstWhere((p) => p.date.day == 4);
      final day5 = result.firstWhere((p) => p.date.day == 5);
      final day10 = result.firstWhere((p) => p.date.day == 10);
      final day11 = result.firstWhere((p) => p.date.day == 11);

      expect(day4.total, 0, reason: 'no completions before May 5');
      expect(day5.total, 1, reason: 'one completion on May 5');
      expect(day10.total, 2, reason: 'second completion on May 10');
      expect(day11.total, 2, reason: 'no new completions on May 11');
    });

    test('bulkInTrack rows: INCLUDED in cumulative (W1-B / Phase A)', () async {
      // All three bulkInTrack rows stamped on the bulk epoch 2000-01-01.
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk1');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk2');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk3');

      // Window that contains the bulk epoch.
      final result = await service.getCumulativeProgress(
        startDate: DateTime(2000, 1, 1),
        endDate: DateTime(2000, 1, 1),
      );

      expect(result, hasLength(1));
      expect(
        result.first.total,
        3,
        reason:
            'bulkInTrack rows MUST inflate the cumulative chart under '
            'trackAchievement tier',
      );
    });

    test('lifetimeOnly excluded; live before startDate accumulates', () async {
      // One lifetimeOnly row (should not contribute to cumulativeBeforeStart).
      await _seedLifetimeOnly(db, trackId: trackId, ref: 'lt1');
      // One live row before the window start (should add to cumulativeBeforeStart).
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'live_before',
        at: DateTime.utc(2026, 4, 15, 10),
      );

      final result = await service.getCumulativeProgress(
        startDate: _startDate,
        endDate: _endDate,
      );

      // live_before is before startDate → cumulativeBeforeStart = 1.
      // lifetimeOnly → excluded → does NOT add to baseline.
      expect(
        result.first.total,
        1,
        reason:
            'cumulativeBeforeStart must include live row before start, '
            'not lifetimeOnly',
      );
    });
  });

  // Unique case from chart_data_service_sentinel_test.dart. The old
  // kBulkPriorSentinelMs timestamp filter was replaced by the
  // prior_completion_imports LEFT JOIN mechanism (Layer 3): a row stamped
  // with the old sentinel timestamp but NOT present in
  // prior_completion_imports must be treated as live, not excluded.
  group('sentinel timestamp fallback', () {
    test(
      'sentinel-stamped row WITHOUT import record is treated as live',
      () async {
        // A row that happens to have the old sentinel timestamp (_bulkAt =
        // 2000-01-01), but is NOT in prior_completion_imports, is treated
        // as live.
        await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: _profileId,
            curriculumId: _curriculumId,
            sefariaRef: 'ref_sentinel_only',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: _bulkAt,
          ),
        );

        final result = await service.getDailyCompletions(
          startDate: DateTime(1990, 1, 1),
          endDate: DateTime(2026, 12, 31),
        );

        expect(
          result.any((d) => d.count > 0),
          isTrue,
          reason:
              'sentinel timestamp alone does not exclude a row; '
              'only prior_completion_imports membership does',
        );
      },
    );
  });

  // ===========================================================================
  // Task #3 — "All Time" bucketing (from chart_data_service_w1b_test.dart)
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
  // (from chart_data_service_w1b_test.dart)
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
  // Task #6 — SQL since/until pushdown (from chart_data_service_w1b_test.dart)
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
