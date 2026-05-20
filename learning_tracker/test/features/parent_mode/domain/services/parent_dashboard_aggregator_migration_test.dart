/// Regression tests for the Layer 3 migration of
/// [ParentDashboardAggregator.computeCompletionPercentage].
///
/// Pre-migration:
/// - Uses getCompletionsByCurriculumAndProfile (all tiers).
/// - Formula: stageSet.length >= totalStages (wrong — counts items with any N
///   stages, not specifically the required set).
///
/// Post-migration:
/// - Uses getCompletionsByTier(trackAchievement) — excludes lifetimeOnly.
/// - Formula: every(requiredStageOrder in doneStages) — canonical.
///
/// Expected value changes:
/// - Live-only profile: value is identical (same rows, same formula for 1 stage).
/// - lifetimeOnly profile: old=counted, new=0 (correct per policy).
/// - Wrong-formula scenario: old over-counted; new is precise (documented).
@Tags(['parent_mode', 'migration', 'layer3'])
library;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/services/parent_dashboard_aggregator.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumId = 'mishnayos';
final _liveAt = DateTime.utc(2026, 5, 1);
final _bulkAt = DateTime.utc(2000, 1, 1);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _seedStage(
  UserDatabase db, {
  required int trackId,
  int stageOrder = 1,
}) async {
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          curriculumId: _curriculumId,
          trackId: trackId,
          profileId: _profileId,
          stageOrder: stageOrder,
          stageName: stageOrder == 1 ? 'Learn' : 'Chazara $stageOrder',
          isDefault: const Value(true),
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<void> _seedLearningOrder(
  UserDatabase db, {
  required String ref,
  int sortOrder = 1,
}) async {
  await db
      .into(db.learningOrder)
      .insert(
        LearningOrderCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculumId,
          sefariaRef: ref,
          userSortOrder: sortOrder,
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<void> _seedLive(
  UserDatabase db, {
  required int trackId,
  required String ref,
  int stageId = 1,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
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
  int stageId = 1,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
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
      stageId: stageId,
      trackType: 'personal',
      source: 'bulkInTrack',
    ),
  ]);
}

Future<void> _seedLifetimeOnly(
  UserDatabase db, {
  required int trackId,
  required String ref,
  int stageId = 1,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
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
      stageId: stageId,
      trackType: 'personal',
      source: 'lifetimeOnly',
    ),
  ]);
}

ParentDashboardAggregator _makeAggregator(UserDatabase db) =>
    ParentDashboardAggregator(
      db,
      profileId: _profileId,
      stageRepository: StageDefinitionRepositoryImpl(
        stageDao: db.stageDao,
        completionDao: db.completionDao,
        pushSettings: null,
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumId,
    );
    // Seed 10 items in learning_order (denominator = 10)
    for (var i = 1; i <= 10; i++) {
      await _seedLearningOrder(db, ref: 'ref$i', sortOrder: i);
    }
    await _seedStage(db, trackId: trackId);
  });

  tearDown(() => db.close());

  group('ParentDashboardAggregator.computeCompletionPercentage migration', () {
    test('live-only profile: migrated result == 0.2 (2/10)', () async {
      await _seedLive(db, trackId: trackId, ref: 'ref1');
      await _seedLive(db, trackId: trackId, ref: 'ref2');

      final agg = _makeAggregator(db);
      final result = await agg.computeCompletionPercentage(
        CurriculumId.mishnayos,
      );
      expect(result, closeTo(0.2, 1e-9));
    });

    test(
      'bulkInTrack profile: trackAchievement credits bulk items (3/10)',
      () async {
        await _seedBulkInTrack(db, trackId: trackId, ref: 'ref1');
        await _seedBulkInTrack(db, trackId: trackId, ref: 'ref2');
        await _seedBulkInTrack(db, trackId: trackId, ref: 'ref3');

        final agg = _makeAggregator(db);
        final result = await agg.computeCompletionPercentage(
          CurriculumId.mishnayos,
        );
        expect(result, closeTo(0.3, 1e-9));
      },
    );

    test('lifetimeOnly profile: new value is 0 (lifetimeOnly excluded from '
        'trackAchievement — corrected per B1 policy)', () async {
      await _seedLifetimeOnly(db, trackId: trackId, ref: 'ref1');
      await _seedLifetimeOnly(db, trackId: trackId, ref: 'ref2');

      final agg = _makeAggregator(db);
      final result = await agg.computeCompletionPercentage(
        CurriculumId.mishnayos,
      );
      // New value: 0 (lifetimeOnly excluded from trackAchievement).
      // Old value would have been 0.2 (2/10) — this is a deliberate correction.
      expect(result, 0.0);
    });

    test(
      'multi-stage: canonical formula (every stageOrder required)',
      () async {
        // Seed a second stage.
        await _seedStage(db, trackId: trackId, stageOrder: 2);

        // ref1: both stages done → fully complete.
        await _seedLive(db, trackId: trackId, ref: 'ref1', stageId: 1);
        await _seedLive(db, trackId: trackId, ref: 'ref1', stageId: 2);
        // ref2: only stage 1 done → NOT fully complete.
        await _seedLive(db, trackId: trackId, ref: 'ref2', stageId: 1);

        final agg = _makeAggregator(db);
        final result = await agg.computeCompletionPercentage(
          CurriculumId.mishnayos,
        );
        // Only ref1 is fully done: 1/10.
        expect(result, closeTo(0.1, 1e-9));
      },
    );
  });
}
