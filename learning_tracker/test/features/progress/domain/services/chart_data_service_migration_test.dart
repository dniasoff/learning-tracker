/// Regression tests for the trackAchievement chart-tier switch (W1-B / Phase A).
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
@Tags(['progress', 'migration', 'layer3'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
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
    ),
  );
}

Future<void> _seedBulkInTrack(
  UserDatabase db, {
  required int trackId,
  required String ref,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: _bulkAt,
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
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: _bulkAt,
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
}
