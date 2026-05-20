// Extra coverage for StageDao — deleteStageDefinition, getStagesByTrack,
// deleteStagesForTrack, replaceStagesForTrack, countStagesForTrack,
// and getMaxStageOrderForTrack were not exercised by the baseline test.
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
            curriculumId: 'bavli',
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  Future<int> insertStage({
    int stageOrder = 1,
    String stageName = 'Learn',
    int delayDays = 0,
    int? overrideTrackId,
  }) => db.stageDao.insertStageDefinition(
    StageDefinitionsCompanion.insert(
      profileId: 1,
      curriculumId: 'bavli',
      trackId: overrideTrackId ?? trackId,
      stageOrder: stageOrder,
      stageName: stageName,
      schedule: Value('{"type":"delay","delay_days":$delayDays}'),
      isDefault: const Value(true),
    ),
  );

  // ---------------------------------------------------------------------------
  // deleteStageDefinition
  // ---------------------------------------------------------------------------

  group('StageDao.deleteStageDefinition', () {
    test('removes the row by id', () async {
      final id = await insertStage();
      final deleted = await db.stageDao.deleteStageDefinition(id);
      expect(deleted, 1);

      final row = await db.stageDao.getStageDefinitionById(id);
      expect(row, isNull);
    });

    test('returns 0 for a non-existent id', () async {
      final deleted = await db.stageDao.deleteStageDefinition(9999);
      expect(deleted, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // getStagesByTrack
  // ---------------------------------------------------------------------------

  group('StageDao.getStagesByTrack', () {
    test('returns stages for the given track ordered by stageOrder', () async {
      await insertStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1);
      await insertStage(stageOrder: 1, stageName: 'Learn');

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, hasLength(2));
      expect(stages.first.stageName, 'Learn'); // stageOrder 1 first
    });

    test('returns empty list for a track with no stages', () async {
      final other = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final stages = await db.stageDao.getStagesByTrack(other);
      expect(stages, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteStagesForTrack
  // ---------------------------------------------------------------------------

  group('StageDao.deleteStagesForTrack', () {
    test('removes all stages for the given track', () async {
      await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 2, stageName: 'Chazara', delayDays: 1);

      final deleted = await db.stageDao.deleteStagesForTrack(trackId);
      expect(deleted, 2);

      final remaining = await db.stageDao.getStagesByTrack(trackId);
      expect(remaining, isEmpty);
    });

    test('does not affect stages for other tracks', () async {
      final other = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await insertStage(stageOrder: 1); // on trackId
      await insertStage(stageOrder: 1, overrideTrackId: other); // on other

      await db.stageDao.deleteStagesForTrack(trackId);

      final othersStages = await db.stageDao.getStagesByTrack(other);
      expect(othersStages, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // replaceStagesForTrack
  // ---------------------------------------------------------------------------

  group('StageDao.replaceStagesForTrack', () {
    test('replaces all existing stages for a track atomically', () async {
      await insertStage(stageOrder: 1, stageName: 'Old Learn');
      await insertStage(stageOrder: 2, stageName: 'Old Chazara', delayDays: 1);

      await db.stageDao.replaceStagesForTrack(trackId, [
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 1,
          stageName: 'New Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 2,
          stageName: 'New Chazara',
          schedule: const Value('{"type":"delay","delay_days":3}'),
        ),
      ]);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, hasLength(2));
      expect(stages[0].stageName, 'New Learn');
      expect(stages[1].stageName, 'New Chazara');
    });

    test('replaceStagesForTrack with empty list deletes all stages', () async {
      await insertStage(stageOrder: 1);

      await db.stageDao.replaceStagesForTrack(trackId, []);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // countStagesForTrack
  // ---------------------------------------------------------------------------

  group('StageDao.countStagesForTrack', () {
    test('returns 0 when no stages exist for the track', () async {
      expect(await db.stageDao.countStagesForTrack(trackId), 0);
    });

    test('counts only stages belonging to the given track', () async {
      await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 2, stageName: 'Chazara', delayDays: 1);

      expect(await db.stageDao.countStagesForTrack(trackId), 2);
    });
  });

  // ---------------------------------------------------------------------------
  // getMaxStageOrderForTrack
  // ---------------------------------------------------------------------------

  group('StageDao.getMaxStageOrderForTrack', () {
    test('returns null when no stages exist', () async {
      final max = await db.stageDao.getMaxStageOrderForTrack(trackId);
      expect(max, isNull);
    });

    test('returns the highest stageOrder', () async {
      await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 3, stageName: 'Chazara 2', delayDays: 7);
      await insertStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1);

      final max = await db.stageDao.getMaxStageOrderForTrack(trackId);
      expect(max, 3);
    });
  });
}
