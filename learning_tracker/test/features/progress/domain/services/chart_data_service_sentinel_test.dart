/// Regression tests for bulk-import handling in ChartDataService.
///
/// Updated for the trackAchievement chart-tier switch (W1-B / Phase A):
/// charts now show LIVE + BULK-IN-TRACK completions but still exclude
/// LIFETIME-ONLY imports. The previous all-zero expectation for
/// bulkInTrack rows is no longer correct — those rows ARE charted now.
/// Lifetime-only imports remain excluded.
///
/// The old kBulkPriorSentinelMs timestamp filter was replaced earlier by
/// the prior_completion_imports LEFT JOIN mechanism (Layer 3). These
/// tests seed proper import records instead of relying on a magic
/// timestamp to trigger inclusion/exclusion.
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
  /// This is the canonical representation of a bulk-prior import.
  ///
  /// Under [CompletionTierFilter.trackAchievement] (used by charts), these
  /// rows ARE counted on the chart — bulkInTrack rows belong to a real
  /// track and represent real per-track learning.
  Future<void> insertBulkInTrack({
    String sefariaRef = 'ref_1',
    DateTime? at,
  }) async {
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: 'mishnayos',
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
        trackId: Value(trackId),
        eventTimestamp: at ?? oldSentinelDate,
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

  /// Seeds a lifetimeOnly import — these MUST NOT appear on charts under any
  /// tier other than [CompletionTierFilter.lifetime].
  Future<void> insertLifetimeOnly({String sefariaRef = 'ref_1'}) async {
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
        source: 'lifetimeOnly',
      ),
    ]);
  }

  group('ChartDataService — tier behavior (trackAchievement)', () {
    group('getDailyCompletions', () {
      test(
        'bulkInTrack rows are charted (new trackAchievement tier)',
        () async {
          // Stamp bulkInTrack rows on a recent date inside a daily-bucketed
          // range so the chart shows them as a non-zero day.
          final bulkDate = DateTime(2026, 3, 15, 10);
          await insertBulkInTrack(sefariaRef: 'ref_1', at: bulkDate);
          await insertBulkInTrack(sefariaRef: 'ref_2', at: bulkDate);
          await insertBulkInTrack(sefariaRef: 'ref_3', at: bulkDate);

          final result = await service.getDailyCompletions(
            startDate: DateTime(2026, 3, 15),
            endDate: DateTime(2026, 3, 15),
          );

          expect(result, hasLength(1));
          expect(
            result.first.count,
            3,
            reason:
                'bulkInTrack rows MUST be visible on the daily-activity '
                'chart under the trackAchievement tier (W1-B / Phase A).',
          );
        },
      );

      test('lifetimeOnly rows are EXCLUDED from charts', () async {
        await insertLifetimeOnly(sefariaRef: 'ref_lt');

        final result = await service.getDailyCompletions(
          startDate: DateTime(1990, 1, 1),
          endDate: DateTime(2026, 12, 31),
        );

        expect(
          result.every((d) => d.count == 0),
          isTrue,
          reason:
              'lifetimeOnly rows must not appear on per-track charts '
              'under the trackAchievement tier.',
        );
      });

      test('live + bulkInTrack rows BOTH count on the chart', () async {
        await insertBulkInTrack(
          sefariaRef: 'ref_bulk',
          at: DateTime(2026, 3, 15, 9),
        );
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
          2,
          reason: 'both live AND bulkInTrack must be counted',
        );
      });

      test(
        'sentinel-stamped row WITHOUT import record is treated as live',
        () async {
          // A row that happens to have the old sentinel timestamp, but is NOT
          // in prior_completion_imports, is treated as live.
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
      test('bulkInTrack rows accumulate on the cumulative chart', () async {
        await insertBulkInTrack(
          sefariaRef: 'ref_1',
          at: DateTime(2026, 3, 15, 9),
        );
        await insertBulkInTrack(
          sefariaRef: 'ref_2',
          at: DateTime(2026, 3, 16, 9),
        );

        final result = await service.getCumulativeProgress(
          startDate: DateTime(2026, 3, 14),
          endDate: DateTime(2026, 3, 16),
        );

        expect(result, hasLength(3));
        expect(result[0].total, 0, reason: 'no completions on March 14');
        expect(result[1].total, 1, reason: 'one bulkInTrack on March 15');
        expect(
          result[2].total,
          2,
          reason: 'second bulkInTrack on March 16 — cumulative is 2',
        );
      });

      test('lifetimeOnly rows do NOT inflate cumulativeBeforeStart', () async {
        await insertLifetimeOnly(sefariaRef: 'ref_lt1');
        await insertLifetimeOnly(sefariaRef: 'ref_lt2');

        final result = await service.getCumulativeProgress(
          startDate: DateTime(2026, 3, 14),
          endDate: DateTime(2026, 3, 16),
        );

        expect(result, hasLength(3));
        expect(
          result.every((p) => p.total == 0),
          isTrue,
          reason:
              'lifetimeOnly rows must not inflate cumulativeBeforeStart '
              'or any daily total in getCumulativeProgress',
        );
      });

      test(
        'live completions accumulate correctly when bulkInTrack also exists',
        () async {
          // bulkInTrack row counts under trackAchievement.
          await insertBulkInTrack(
            sefariaRef: 'ref_bulk',
            at: DateTime(2026, 3, 14, 9),
          );
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

          expect(result, hasLength(3));
          expect(
            result[0].total,
            1,
            reason: 'bulkInTrack on March 14 counts immediately',
          );
          expect(
            result[1].total,
            2,
            reason: 'live completion on March 15 — cumulative is 2',
          );
          expect(
            result[2].total,
            2,
            reason: 'cumulative stays at 2 on March 16',
          );
        },
      );
    });
  });
}
