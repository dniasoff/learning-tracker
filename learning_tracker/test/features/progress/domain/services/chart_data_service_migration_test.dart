/// Regression tests for the Layer 3 migration of [ChartDataService].
///
/// Pre-migration:
/// - [getDailyCompletions] and [getCumulativeProgress] used
///   [getCompletionsByCurriculumAndProfile] (all tiers) and filtered out
///   sentinel rows via `kBulkPriorSentinelMs` magic-constant comparison.
///
/// Post-migration:
/// - Both methods use [CompletionDao.getCompletionsByTier] with
///   [CompletionTierFilter.liveOnly] — excludes bulkInTrack and lifetimeOnly
///   via LEFT JOIN on [prior_completion_imports], not a timestamp check.
///
/// Expected value changes:
/// - Live-only profile: results are identical.
/// - bulkInTrack rows: new = excluded (old sentinel filter did not catch these).
/// - lifetimeOnly rows: new = excluded (same as old sentinel, different mechanism).
@Tags(['progress', 'migration', 'layer3'])
library;

import 'package:drift/drift.dart' show InsertMode, Value;
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
    trackId = await seedTrack(db, profileId: _profileId, curriculumId: _curriculumId);
    service = ChartDataService(db, profileId: _profileId);
  });

  tearDown(() => db.close());

  group('ChartDataService.getDailyCompletions Layer 3 migration', () {
    test('live-only: counts match pre-migration result', () async {
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

    test('bulkInTrack rows: excluded from daily chart (new behavior)', () async {
      // bulkInTrack rows are now excluded by liveOnly tier.
      // Old sentinel path would NOT have excluded these (they use a non-sentinel timestamp).
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk1');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk2');

      final result = await service.getDailyCompletions(
        startDate: DateTime(1990, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      expect(
        result.every((d) => d.count == 0),
        isTrue,
        reason: 'bulkInTrack rows must be excluded by liveOnly tier filter',
      );
    });

    test('lifetimeOnly rows: excluded (same as sentinel, new mechanism)', () async {
      await _seedLifetimeOnly(db, trackId: trackId, ref: 'lt1');

      final result = await service.getDailyCompletions(
        startDate: DateTime(1990, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      expect(
        result.every((d) => d.count == 0),
        isTrue,
        reason: 'lifetimeOnly rows excluded via prior_completion_imports JOIN',
      );
    });

    test('mixed: live counted, bulkInTrack excluded', () async {
      await _seedLive(db, trackId: trackId, ref: 'live1');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk1');

      final result = await service.getDailyCompletions(
        startDate: _startDate,
        endDate: _endDate,
      );

      final day10 = result.firstWhere((d) => d.date.day == 10);
      expect(day10.count, 1, reason: 'only the live completion counts');
    });
  });

  group('ChartDataService.getCumulativeProgress Layer 3 migration', () {
    test('live-only: cumulative matches pre-migration result', () async {
      await _seedLive(db, trackId: trackId, ref: 'ref1', at: DateTime.utc(2026, 5, 5, 10));
      await _seedLive(db, trackId: trackId, ref: 'ref2', at: DateTime.utc(2026, 5, 10, 10));

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

    test('bulkInTrack rows: excluded from cumulative (new behavior)', () async {
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk1');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk2');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk3');

      final result = await service.getCumulativeProgress(
        startDate: DateTime(1990, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      expect(
        result.every((p) => p.total == 0),
        isTrue,
        reason: 'bulkInTrack rows must not inflate cumulativeBeforeStart or daily totals',
      );
    });

    test('lifetimeOnly rows excluded, live completions before startDate accumulate', () async {
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
        reason: 'cumulativeBeforeStart must include live row before start, not lifetimeOnly',
      );
    });
  });
}
