/// Extended tests for StageDao covering methods not exercised by stage_dao_test.dart:
/// - getStageDefinitionById
/// - updateStageDefinition
/// - deleteStageDefinition
/// - getStagesByTrack
/// - deleteStagesForTrack
/// - replaceStagesForTrack
/// - countStagesForTrack
/// - getMaxStageOrderForTrack
/// - runTransaction
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  const curriculumId = 'mishnayos';

  Future<int> insertStage({
    int stageOrder = 1,
    String stageName = 'Learn',
    int delayDays = 0,
    int? tid,
  }) => db.stageDao.insertStageDefinition(
    StageDefinitionsCompanion.insert(
      profileId: 1,
      curriculumId: curriculumId,
      trackId: tid ?? trackId,
      stageOrder: stageOrder,
      stageName: stageName,
      schedule: Value('{"type":"delay","delay_days":$delayDays}'),
    ),
  );

  // ── getStageDefinitionById ────────────────────────────────────────────────

  group('StageDao.getStageDefinitionById', () {
    test('returns the stage with the given id', () async {
      final id = await insertStage(stageOrder: 1, stageName: 'Learn');
      final stage = await db.stageDao.getStageDefinitionById(id);
      expect(stage, isNotNull);
      expect(stage!.id, id);
      expect(stage.stageName, 'Learn');
    });

    test('returns null for non-existent id', () async {
      final stage = await db.stageDao.getStageDefinitionById(9999);
      expect(stage, isNull);
    });
  });

  // ── updateStageDefinition ─────────────────────────────────────────────────

  group('StageDao.updateStageDefinition', () {
    test('updates an existing stage definition', () async {
      final id = await insertStage(stageOrder: 1, stageName: 'Original');

      final original = await db.stageDao.getStageDefinitionById(id);
      expect(original, isNotNull);

      final updated = await db.stageDao.updateStageDefinition(
        StageDefinitionsCompanion(
          id: Value(id),
          profileId: const Value(1),
          curriculumId: const Value(curriculumId),
          trackId: Value(trackId),
          stageOrder: const Value(1),
          stageName: const Value('Updated Name'),
          schedule: const Value('{"type":"delay","delay_days":3}'),
        ),
      );
      expect(updated, isTrue);

      final after = await db.stageDao.getStageDefinitionById(id);
      expect(after!.stageName, 'Updated Name');
      final scheduleJson = jsonDecode(after.schedule) as Map<String, dynamic>;
      expect(scheduleJson['delay_days'], 3);
    });
  });

  // ── deleteStageDefinition ─────────────────────────────────────────────────

  group('StageDao.deleteStageDefinition', () {
    test('removes the stage by id', () async {
      final id = await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 2, stageName: 'Chazara');

      final deleted = await db.stageDao.deleteStageDefinition(id);
      expect(deleted, 1);

      final all = await db.stageDao.getAllStageDefinitions();
      expect(all, hasLength(1));
      expect(all.first.stageOrder, 2);
    });

    test('returns 0 when id does not exist', () async {
      final deleted = await db.stageDao.deleteStageDefinition(9999);
      expect(deleted, 0);
    });
  });

  // ── getStagesByTrack ──────────────────────────────────────────────────────

  group('StageDao.getStagesByTrack', () {
    test(
      'returns stages for the specified track ordered by stageOrder',
      () async {
        // Insert a second track.
        final otherTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        await insertStage(stageOrder: 3, stageName: 'Chazara 2', tid: trackId);
        await insertStage(stageOrder: 1, stageName: 'Learn', tid: trackId);
        await insertStage(stageOrder: 1, stageName: 'Other', tid: otherTrackId);

        final stages = await db.stageDao.getStagesByTrack(trackId);
        expect(stages, hasLength(2));
        expect(stages.map((s) => s.stageOrder).toList(), [1, 3]);
      },
    );

    test('returns empty list when no stages for track', () async {
      final stages = await db.stageDao.getStagesByTrack(9999);
      expect(stages, isEmpty);
    });
  });

  // ── deleteStagesForTrack ──────────────────────────────────────────────────

  group('StageDao.deleteStagesForTrack', () {
    test('deletes only stages for the specified track', () async {
      final otherTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await insertStage(stageOrder: 1, tid: trackId);
      await insertStage(stageOrder: 2, tid: trackId);
      await insertStage(stageOrder: 1, tid: otherTrackId);

      final deleted = await db.stageDao.deleteStagesForTrack(trackId);
      expect(deleted, 2);

      final all = await db.stageDao.getAllStageDefinitions();
      expect(all, hasLength(1));
      expect(all.first.trackId, otherTrackId);
    });

    test('returns 0 when no stages for track', () async {
      final deleted = await db.stageDao.deleteStagesForTrack(9999);
      expect(deleted, 0);
    });
  });

  // ── replaceStagesForTrack ─────────────────────────────────────────────────

  group('StageDao.replaceStagesForTrack', () {
    test('replaces existing stages for the track with new ones', () async {
      await insertStage(stageOrder: 1, stageName: 'Old Learn');
      await insertStage(stageOrder: 2, stageName: 'Old Chazara');

      final newStages = [
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'New Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      ];

      await db.stageDao.replaceStagesForTrack(trackId, newStages);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, hasLength(1));
      expect(stages.first.stageName, 'New Learn');
    });

    test('deletes all stages when replacement list is empty', () async {
      await insertStage(stageOrder: 1);

      await db.stageDao.replaceStagesForTrack(trackId, []);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, isEmpty);
    });
  });

  // ── countStagesForTrack ───────────────────────────────────────────────────

  group('StageDao.countStagesForTrack', () {
    test('returns 0 when no stages for track', () async {
      final count = await db.stageDao.countStagesForTrack(9999);
      expect(count, 0);
    });

    test('returns count of stages for track', () async {
      await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 2, stageName: 'Chazara');

      final count = await db.stageDao.countStagesForTrack(trackId);
      expect(count, 2);
    });

    test('does not count stages from other tracks', () async {
      final otherTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await insertStage(stageOrder: 1, tid: trackId);
      await insertStage(stageOrder: 1, tid: otherTrackId);

      expect(await db.stageDao.countStagesForTrack(trackId), 1);
      expect(await db.stageDao.countStagesForTrack(otherTrackId), 1);
    });
  });

  // ── getMaxStageOrderForTrack ──────────────────────────────────────────────

  group('StageDao.getMaxStageOrderForTrack', () {
    test('returns null when no stages for track', () async {
      final max = await db.stageDao.getMaxStageOrderForTrack(9999);
      expect(max, isNull);
    });

    test('returns maximum stageOrder for the track', () async {
      await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 5, stageName: 'Chazara 4');
      await insertStage(stageOrder: 3, stageName: 'Chazara 2');

      final max = await db.stageDao.getMaxStageOrderForTrack(trackId);
      expect(max, 5);
    });
  });

  // ── runTransaction ────────────────────────────────────────────────────────

  group('StageDao.runTransaction', () {
    test(
      'runs body inside a database transaction and returns result',
      () async {
        final result = await db.stageDao.runTransaction(() async {
          final id = await insertStage(stageOrder: 1, stageName: 'Txn Stage');
          return id;
        });

        expect(result, isA<int>());
        final stage = await db.stageDao.getStageDefinitionById(result);
        expect(stage, isNotNull);
        expect(stage!.stageName, 'Txn Stage');
      },
    );
  });
}
