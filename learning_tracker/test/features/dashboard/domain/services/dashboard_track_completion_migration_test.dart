/// Regression tests for the Layer 3 migration of
/// [dashboardTrackCompletionPercentageProvider] → [TrackProgressService].
///
/// Verifies the contract of the migrated provider:
/// 1. For live-only profiles, the result is identical to the old
///    TrackCompletionService.computeTrackPercentage path.
/// 2. For bulk-only profiles, trackAchievement counts bulkInTrack items.
/// 3. For mixed profiles containing lifetimeOnly rows, the migrated result
///    is correctly lower than the old all-tiers result (lifetimeOnly excluded).
@Tags(['dashboard', 'migration', 'layer3'])
library;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/services/track_completion_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;

import '../../../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _profileId = 1;
const _curriculumId = 'mishnayos';
final _liveAt = DateTime.utc(2026, 5, 1, 12);
final _bulkAt = DateTime.utc(2000, 1, 1);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

domain_stage.StageDefinition _stageModel({int stageOrder = 1}) =>
    domain_stage.StageDefinition(
      id: stageOrder,
      curriculumId: CurriculumId.mishnayos,
      stageOrder: stageOrder,
      stageName: stageOrder == 1 ? 'Learn' : 'Chazara $stageOrder',
      delayDays: 0,
      isDefault: true,
    );

Future<void> _seedStageRow(UserDatabase db, {required int trackId}) async {
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

Future<void> _seedLive(
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
      eventTimestamp: _liveAt,
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
  late TrackProgressService service;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumId,
    );
    await _seedStageRow(db, trackId: trackId);
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

  const totalItems = 10;
  const legacySvc = TrackCompletionService();

  group('dashboardTrackCompletionPercentage migration consistency', () {
    test('live-only profile: trackAchievement == old all-tiers result', () async {
      await _seedLive(db, trackId: trackId, ref: 'ref1');
      await _seedLive(db, trackId: trackId, ref: 'ref2');

      // Old path: all rows, TrackCompletionService formula.
      final allRows = await db.completionDao.getCompletionsByTrackAndProfile(
        trackId,
        _profileId,
      );
      final legacyPct = legacySvc.computeTrackPercentage(
        stages: [_stageModel()],
        completions: allRows,
        totalItems: totalItems,
      );

      // Migrated path: trackAchievement.
      final migratedPct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: totalItems,
      );

      expect(
        migratedPct,
        closeTo(legacyPct, 1e-9),
        reason:
            'Live-only profile: trackAchievement must equal old all-tiers result',
      );
      expect(migratedPct, closeTo(0.2, 1e-9)); // 2/10
    });

    test(
      'bulk-only profile: trackAchievement credits bulkInTrack items',
      () async {
        await _seedBulkInTrack(db, trackId: trackId, ref: 'ref1');
        await _seedBulkInTrack(db, trackId: trackId, ref: 'ref2');
        await _seedBulkInTrack(db, trackId: trackId, ref: 'ref3');

        final migratedPct = await service.completionPercent(
          trackId: trackId,
          profileId: _profileId,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: totalItems,
        );

        expect(migratedPct, closeTo(0.3, 1e-9)); // 3/10 bulkInTrack
      },
    );

    test(
      'mixed profile: migrated value < old value when lifetimeOnly rows exist',
      () async {
        await _seedLive(db, trackId: trackId, ref: 'ref_live');
        await _seedBulkInTrack(db, trackId: trackId, ref: 'ref_bulk');
        await _seedLifetimeOnly(db, trackId: trackId, ref: 'ref_lt');

        // Old: all 3 rows → 3/10.
        final allRows = await db.completionDao.getCompletionsByTrackAndProfile(
          trackId,
          _profileId,
        );
        final legacyPct = legacySvc.computeTrackPercentage(
          stages: [_stageModel()],
          completions: allRows,
          totalItems: totalItems,
        );

        // Migrated: live + bulkInTrack only → 2/10.
        final migratedPct = await service.completionPercent(
          trackId: trackId,
          profileId: _profileId,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: totalItems,
        );

        expect(legacyPct, closeTo(0.3, 1e-9), reason: 'Old path: 3 rows');
        expect(
          migratedPct,
          closeTo(0.2, 1e-9),
          reason: 'New path: lifetimeOnly excluded',
        );
        expect(
          migratedPct,
          lessThan(legacyPct),
          reason: 'trackAchievement < all-tiers when lifetimeOnly rows present',
        );
      },
    );
  });
}
