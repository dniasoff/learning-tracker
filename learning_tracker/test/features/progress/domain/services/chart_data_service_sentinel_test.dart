/// Regression tests for bulk-import exclusion in ChartDataService.
///
/// For a profile that has ONLY bulk-prior completions (seeded into
/// prior_completion_imports), both getDailyCompletions() and
/// getCumulativeProgress() must return data with count = 0 everywhere.
///
/// Updated for Layer 3 migration: the old kBulkPriorSentinelMs timestamp
/// filter is replaced by the prior_completion_imports LEFT JOIN mechanism.
/// These tests seed proper import records instead of relying on a magic
/// timestamp to trigger exclusion.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late ChartDataService service;
  late int trackId;
  const profileId = 1;

  // The old sentinel timestamp, retained here to verify that rows stamped
  // with this value are NOT excluded unless they also appear in
  // prior_completion_imports (i.e., timestamp alone no longer drives exclusion).
  final oldSentinelDate = DateTime.utc(2000, 1, 1);

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    service = ChartDataService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  /// Seeds a bulkInTrack completion: event row + prior_completion_imports record.
  /// This is the correct Layer 3 representation of a bulk-prior import.
  Future<void> insertBulkImport({String sefariaRef = 'ref_1'}) async {
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: 'mishnayos',
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
        trackId: Value(trackId),
        eventTimestamp: oldSentinelDate,
      ),
    );
    await db.priorCompletionImportDao.batchInsertImports([
      PriorCompletionImportsCompanion.insert(
        profileId: profileId,
        curriculumId: 'mishnayos',
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
        source: 'bulkInTrack',
      ),
    ]);
  }

  group('ChartDataService — bulk-import exclusion (Layer 3)', () {
    group('getDailyCompletions', () {
      test(
        'returns all-zero counts when only bulk import rows exist',
        () async {
          // Insert several bulk import completions for different refs.
          await insertBulkImport(sefariaRef: 'ref_1');
          await insertBulkImport(sefariaRef: 'ref_2');
          await insertBulkImport(sefariaRef: 'ref_3');

          final start = DateTime(2024, 1, 1);
          final end = DateTime(2026, 5, 20);

          final result = await service.getDailyCompletions(
            startDate: start,
            endDate: end,
          );

          // Every day in the range must have count == 0.
          expect(
            result.every((d) => d.count == 0),
            isTrue,
            reason:
                'bulk-import rows must not appear in daily completions',
          );
        },
      );

      test(
        'live completions are still counted when bulk import rows also exist',
        () async {
          // Mix: one bulk import row + one live row.
          await insertBulkImport(sefariaRef: 'ref_bulk');
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'ref_live',
              stageId: 1,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: DateTime(2026, 3, 15, 10),
            ),
          );

          final result = await service.getDailyCompletions(
            startDate: DateTime(2026, 3, 15),
            endDate: DateTime(2026, 3, 15),
          );

          expect(result, hasLength(1));
          expect(
            result.first.count,
            1,
            reason: 'live completion must still be counted',
          );
        },
      );

      test(
        'sentinel-stamped row WITHOUT import record is treated as live (Layer 3 contract)',
        () async {
          // A row that happens to have the old sentinel timestamp, but is NOT
          // in prior_completion_imports, is treated as live in Layer 3.
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'ref_sentinel_only',
              stageId: 1,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: oldSentinelDate,
            ),
          );

          final result = await service.getDailyCompletions(
            startDate: DateTime(1990, 1, 1),
            endDate: DateTime(2026, 12, 31),
          );

          // The sentinel-timestamped row without an import record IS counted
          // as live — timestamp alone no longer drives exclusion.
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

    group('getCumulativeProgress', () {
      test(
        'returns all-zero totals when only bulk import rows exist',
        () async {
          await insertBulkImport(sefariaRef: 'ref_1');
          await insertBulkImport(sefariaRef: 'ref_2');

          final start = DateTime(2024, 1, 1);
          final end = DateTime(2026, 5, 20);

          final result = await service.getCumulativeProgress(
            startDate: start,
            endDate: end,
          );

          // All totals should be zero — bulk import rows excluded from both the
          // day-range counts AND the cumulativeBeforeStart calculation.
          expect(
            result.every((p) => p.total == 0),
            isTrue,
            reason:
                'bulk-import rows must not inflate cumulativeBeforeStart '
                'or any daily total in getCumulativeProgress',
          );
        },
      );

      test(
        'live completions accumulate correctly when bulk import rows also exist',
        () async {
          // Bulk import row should not appear.
          await insertBulkImport(sefariaRef: 'ref_bulk');
          // Live row on 2026-03-15.
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'ref_live',
              stageId: 1,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: DateTime(2026, 3, 15, 10),
            ),
          );

          final result = await service.getCumulativeProgress(
            startDate: DateTime(2026, 3, 14),
            endDate: DateTime(2026, 3, 16),
          );

          // Day 0 (March 14): 0 — no live completions before start
          // Day 1 (March 15): 1 — the live completion
          // Day 2 (March 16): 1 — no additional completions
          expect(result, hasLength(3));
          expect(result[0].total, 0, reason: 'no live completions on March 14');
          expect(result[1].total, 1, reason: 'one live completion on March 15');
          expect(
            result[2].total,
            1,
            reason: 'cumulative stays at 1 on March 16',
          );
        },
      );
    });
  });
}
