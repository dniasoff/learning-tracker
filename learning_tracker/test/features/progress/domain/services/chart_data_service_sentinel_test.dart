/// Regression tests for Fix 2 — sentinel exclusion in ChartDataService.
///
/// For a profile that has ONLY bulk-prior completions (sentinel timestamp
/// `DateTime.utc(2000, 1, 1)`), both getDailyCompletions() and
/// getCumulativeProgress() must return data with count = 0 everywhere.
///
/// Fix 2 — Progress Aggregator L1+L2 remediation (2026-05-20).
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late ChartDataService service;
  late int trackId;
  const profileId = 1;

  // The sentinel DateTime used by BulkPriorCompletionService.
  final sentinelDate = DateTime.fromMillisecondsSinceEpoch(
    kBulkPriorSentinelMs,
    isUtc: true,
  );

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

  Future<void> insertSentinelCompletion({String sefariaRef = 'ref_1'}) =>
      seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          // Use the sentinel timestamp directly — this is what
          // BulkPriorCompletionService writes.
          eventTimestamp: sentinelDate,
        ),
      );

  group('ChartDataService — sentinel exclusion (Fix 2)', () {
    group('getDailyCompletions', () {
      test(
        'returns all-zero counts when only bulk-prior sentinel rows exist',
        () async {
          // Insert several sentinel completions for different refs.
          await insertSentinelCompletion(sefariaRef: 'ref_1');
          await insertSentinelCompletion(sefariaRef: 'ref_2');
          await insertSentinelCompletion(sefariaRef: 'ref_3');

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
                'bulk-prior sentinel rows must not appear in daily completions',
          );
        },
      );

      test(
        'live completions are still counted when bulk-prior rows also exist',
        () async {
          // Mix: one sentinel row + one live row.
          await insertSentinelCompletion(sefariaRef: 'ref_bulk');
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
    });

    group('getCumulativeProgress', () {
      test(
        'returns all-zero totals when only bulk-prior sentinel rows exist',
        () async {
          await insertSentinelCompletion(sefariaRef: 'ref_1');
          await insertSentinelCompletion(sefariaRef: 'ref_2');

          final start = DateTime(2024, 1, 1);
          final end = DateTime(2026, 5, 20);

          final result = await service.getCumulativeProgress(
            startDate: start,
            endDate: end,
          );

          // All totals should be zero — sentinel rows excluded from both the
          // day-range counts AND the cumulativeBeforeStart calculation.
          expect(
            result.every((p) => p.total == 0),
            isTrue,
            reason:
                'bulk-prior sentinel rows must not inflate cumulativeBeforeStart '
                'or any daily total in getCumulativeProgress',
          );
        },
      );

      test(
        'live completions accumulate correctly when bulk-prior rows also exist',
        () async {
          // Sentinel row should not appear.
          await insertSentinelCompletion(sefariaRef: 'ref_bulk');
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
