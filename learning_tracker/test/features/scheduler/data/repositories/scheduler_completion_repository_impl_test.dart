/// Tests for SchedulerCompletionRepositoryImpl.getCompletions — specifically
/// AUD-scheduler-15: `resolveStageOrder` used to guess whether a completion
/// row's `stageId` meant a `StageDefinitions.id` or a `stageOrder` ordinal by
/// checking whether the raw value happened to match a CURRENT stageOrder.
/// Both value spaces are small positive integers that can coincide —
/// concretely, once a stage is reordered its `id` stays fixed while its
/// `stageOrder` moves, so a DIFFERENT stage can end up with the very
/// stageOrder value that equals the first stage's id.
///
/// This drives the real repository against a real in-memory [UserDatabase]
/// (not a fake), seeding stage_definitions and completion_events rows
/// directly so the collision is fully under the test's control.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';

import '../../../../helpers/test_database.dart';

const _profileId = 1;
const _curriculum = CurriculumId.mishnayos;

Future<int> _seedProfileAndTrack(UserDatabase db) async {
  final now = DateTime.utc(2026, 1, 1);
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          id: const Value(_profileId),
          accountId: 1,
          displayName: 'Learner',
          mode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculum.storageKey,
          stateChangedAt: now,
          activatedAt: now,
        ),
      );
}

Future<void> _seedStage(
  UserDatabase db, {
  required int id,
  required int trackId,
  required int stageOrder,
  required String name,
}) => db
    .into(db.stageDefinitions)
    .insert(
      StageDefinitionsCompanion.insert(
        id: Value(id),
        profileId: _profileId,
        curriculumId: _curriculum.storageKey,
        trackId: trackId,
        stageOrder: stageOrder,
        stageName: name,
      ),
    );

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    trackId = await _seedProfileAndTrack(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getCompletions — AUD-scheduler-15 stageId/stageOrder collision', () {
    test('resolves an id/stageOrder-format completion (tag "stageOrder") to '
        'the stage that currently holds that order — the common, unambiguous '
        'case for every row CompletionWriter has ever produced', () async {
      await _seedStage(
        db,
        id: 10,
        trackId: trackId,
        stageOrder: 1,
        name: 'Learn',
      );
      await _seedStage(
        db,
        id: 11,
        trackId: trackId,
        stageOrder: 2,
        name: 'Chazara1',
      );

      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculum.storageKey,
          sefariaRef: 'Mishnah.Berakhos.1.1',
          stageId: 2,
          trackType: 'personal',
          eventTimestamp: DateTime.utc(2026, 2, 1),
          stageIdFormat: const Value('stageOrder'),
        ),
      );

      final repo = SchedulerCompletionRepositoryImpl(
        completionDao: db.completionDao,
        stageDao: db.stageDao,
        profileId: _profileId,
      );
      final completions = await repo.getCompletions(_curriculum);

      expect(completions, hasLength(1));
      expect(completions.single.stageOrder, 2);
    });

    test('a coincidental stageId/stageOrder collision resolves to the CORRECT '
        'stage (the one the legacy row actually references by id) rather '
        'than the different stage that merely happens to hold that stageOrder '
        'value today', () async {
      // Reorder-created collision: stage A's immutable id (7) now equals
      // stage B's CURRENT stageOrder (7) — exactly the scenario
      // AUD-scheduler-15 describes (StageDefinitionRepository.
      // reorderStages moves a stage's order while its id stays fixed).
      //   A: id=7, stageOrder=1 — the stage the legacy row means.
      //   B: id=1, stageOrder=7 — the stage a value-coincidence guess
      //      would (WRONGLY) pick instead.
      await _seedStage(
        db,
        id: 7,
        trackId: trackId,
        stageOrder: 1,
        name: 'Learn',
      );
      await _seedStage(
        db,
        id: 1,
        trackId: trackId,
        stageOrder: 7,
        name: 'Custom',
      );

      // An "old-format" completion referencing stage A BY ITS ID (7),
      // explicitly tagged 'legacyId' — the post-AUD-scheduler-15
      // representation of "this stageId is a stage_definitions.id, not a
      // stageOrder ordinal". No writer in this codebase produces
      // untagged/ambiguous rows any more; this is what the v37 migration
      // backfills a pre-existing legacy row to once it can classify it
      // (see test/migration/v36_to_v37_test.dart), or — as here — what a
      // test constructs directly to exercise resolveStageOrder's tagged
      // branch in isolation.
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculum.storageKey,
          sefariaRef: 'Mishnah.Berakhos.1.2',
          stageId: 7,
          trackType: 'personal',
          eventTimestamp: DateTime.utc(2026, 2, 2),
          stageIdFormat: const Value('legacyId'),
        ),
      );

      final repo = SchedulerCompletionRepositoryImpl(
        completionDao: db.completionDao,
        stageDao: db.stageDao,
        profileId: _profileId,
      );
      final completions = await repo.getCompletions(_curriculum);

      expect(completions, hasLength(1));
      expect(
        completions.single.stageOrder,
        1,
        reason:
            'stageId=7 tagged legacyId means "stage id 7" (stage A, '
            'stageOrder 1) — NOT "stageOrder 7" (stage B), which is what '
            'a coincidence guess against the current stage set would '
            'wrongly resolve to',
      );
    });

    test('an untagged (pre-v37) row falls back to the historical best-effort '
        'guess unchanged — no regression for not-yet-migrated data', () async {
      await _seedStage(
        db,
        id: 7,
        trackId: trackId,
        stageOrder: 1,
        name: 'Learn',
      );
      await _seedStage(
        db,
        id: 1,
        trackId: trackId,
        stageOrder: 7,
        name: 'Custom',
      );

      // No stageIdFormat supplied -> column defaults to NULL, simulating
      // a row that predates the v37 migration/backfill.
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculum.storageKey,
          sefariaRef: 'Mishnah.Berakhos.1.3',
          stageId: 7,
          trackType: 'personal',
          eventTimestamp: DateTime.utc(2026, 2, 3),
        ),
      );

      final repo = SchedulerCompletionRepositoryImpl(
        completionDao: db.completionDao,
        stageDao: db.stageDao,
        profileId: _profileId,
      );
      final completions = await repo.getCompletions(_curriculum);

      expect(completions, hasLength(1));
      expect(
        completions.single.stageOrder,
        7,
        reason:
            'untagged rows must resolve EXACTLY as before v37 (order-first '
            'priority) — this is the documented, pre-existing residual '
            'limitation for genuinely ambiguous historical data with no '
            'surviving format signal, not a new regression',
      );
    });
  });
}
