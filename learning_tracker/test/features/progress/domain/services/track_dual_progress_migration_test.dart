/// Regression tests for the Layer 3 migration of
/// [trackDualProgressMetricsProvider.currentCyclePercentage] →
/// [TrackProgressService.completionPercent].
///
/// Pre-migration: `getCompletionsByTrackAndProfileSince(activatedAt)` (all tiers,
/// time-gated), distinct-refs count.
///
/// Post-migration: `TrackProgressService.completionPercent` with
/// `tier: trackAchievement, since: activatedAt, requireAllStages: false`.
///
/// Expected changes:
/// - For live-only profiles, values are identical.
/// - lifetimeOnly rows that were time-gated SINCE activatedAt would have been
///   counted by the old path; they are now excluded by trackAchievement.
///   (In practice, lifetimeOnly imports pre-date activatedAt so the old filter
///   already excluded them via the `Since` gate — values are equal for real data.)
@Tags(['progress', 'migration', 'layer3'])
library;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumId = 'mishnayos';
final _activatedAt = DateTime.utc(2026, 3, 1);
final _beforeActivation = DateTime.utc(2026, 2, 1);
final _afterActivation = DateTime.utc(2026, 4, 1);
final _bulkAt = DateTime.utc(2000, 1, 1);

Future<void> _seedStage(UserDatabase db, {required int trackId}) async {
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          curriculumId: _curriculumId,
          trackId: trackId,
          profileId: _profileId,
          stageOrder: 1,
          stageName: 'Learn',
          isDefault: const Value(true),
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<void> _seedLiveAt(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required DateTime at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
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

void main() {
  late UserDatabase db;
  late int trackId;
  late TrackProgressService service;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumId,
      activatedAt: _activatedAt,
    );
    await _seedStage(db, trackId: trackId);
    service = TrackProgressService(
      dao: db.completionDao,
      stageRepo: StageDefinitionRepositoryImpl(
        stageDao: db.stageDao,
        completionDao: db.completionDao,
        pushSettings: null,
      ),
    );
  });

  tearDown(() => db.close());

  const denominator = 10;

  group('currentCyclePercentage migration consistency', () {
    test(
      'live-only, all after activatedAt: migrated == pre-migration',
      () async {
        await _seedLiveAt(
          db,
          trackId: trackId,
          ref: 'ref1',
          at: _afterActivation,
        );
        await _seedLiveAt(
          db,
          trackId: trackId,
          ref: 'ref2',
          at: _afterActivation,
        );

        // Pre-migration path: all rows since activatedAt, distinct refs.
        final oldRows = await db.completionDao
            .getCompletionsByTrackAndProfileSince(
              trackId,
              _profileId,
              _activatedAt,
            );
        final oldDistinctRefs = oldRows.map((c) => c.sefariaRef).toSet();
        final oldPct = oldDistinctRefs.length / denominator;

        // Migrated path.
        final migratedPct = await service.completionPercent(
          trackId: trackId,
          profileId: _profileId,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: denominator,
          requireAllStages: false,
          since: _activatedAt,
        );

        expect(migratedPct, closeTo(oldPct, 1e-9));
        expect(migratedPct, closeTo(0.2, 1e-9)); // 2/10
      },
    );

    test(
      'live before and after activatedAt: since filter applied correctly',
      () async {
        // Old ref: before activatedAt → excluded by since gate.
        await _seedLiveAt(
          db,
          trackId: trackId,
          ref: 'old_ref',
          at: _beforeActivation,
        );
        // New ref: after activatedAt → included.
        await _seedLiveAt(
          db,
          trackId: trackId,
          ref: 'new_ref',
          at: _afterActivation,
        );

        final migratedPct = await service.completionPercent(
          trackId: trackId,
          profileId: _profileId,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: denominator,
          requireAllStages: false,
          since: _activatedAt,
        );

        expect(
          migratedPct,
          closeTo(0.1, 1e-9),
          reason: 'Only new_ref (after activatedAt) counts: 1/10',
        );
      },
    );

    test(
      'bulkInTrack after activatedAt: included in trackAchievement cycle',
      () async {
        // Bulk import with a post-activation timestamp (unusual but valid).
        await _seedBulkInTrack(
          db,
          trackId: trackId,
          ref: 'bulk_new',
          at: _afterActivation,
        );

        final migratedPct = await service.completionPercent(
          trackId: trackId,
          profileId: _profileId,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: denominator,
          requireAllStages: false,
          since: _activatedAt,
        );

        expect(migratedPct, closeTo(0.1, 1e-9)); // 1/10 bulk after activation
      },
    );
  });
}
