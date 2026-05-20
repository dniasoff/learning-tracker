import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase database;
  late int trackId;

  setUp(() async {
    database = inMemoryDb();
    await seedProfile(database);
    trackId = await database
        .into(database.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime.now(),
            activatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  const curriculumId = 'mishnayos';

  Future<int> insertStage({
    int stageOrder = 1,
    String stageName = 'Learn',
    int delayDays = 0,
    bool isDefault = true,
  }) => database.stageDao.insertStageDefinition(
    StageDefinitionsCompanion.insert(
      profileId: 1,
      curriculumId: curriculumId,
      trackId: trackId,
      stageOrder: stageOrder,
      stageName: stageName,
      schedule: Value('{"type":"delay","delay_days":${delayDays}}'),
      isDefault: Value(isDefault),
    ),
  );

  group('StageDao', () {
    test('insert and retrieve by curriculum', () async {
      await insertStage(stageOrder: 1, stageName: 'Learn');
      await insertStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1);

      final stages = await database.stageDao.getStageDefinitionsByCurriculum(
        curriculumId,
      );
      expect(stages.length, 2);
      expect(stages[0].stageName, 'Learn');
      expect(stages[1].stageName, 'Chazara 1');
    });

    test(
      'getStageDefinitionsByCurriculum returns ordered by stageOrder',
      () async {
        // Insert out of order
        await insertStage(stageOrder: 3, stageName: 'Chazara 2', delayDays: 7);
        await insertStage(stageOrder: 1, stageName: 'Learn');
        await insertStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1);

        final stages = await database.stageDao.getStageDefinitionsByCurriculum(
          curriculumId,
        );
        expect(stages.map((s) => s.stageOrder).toList(), [1, 2, 3]);
      },
    );

    test('getMaxStageOrder returns null when no stages', () async {
      final max = await database.stageDao.getMaxStageOrder(curriculumId);
      expect(max, isNull);
    });

    test('getMaxStageOrder returns correct max', () async {
      await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 3, stageName: 'Chazara 2', delayDays: 7);
      await insertStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1);

      final max = await database.stageDao.getMaxStageOrder(curriculumId);
      expect(max, 3);
    });

    test('countStagesForCurriculum returns 0 when empty', () async {
      final count = await database.stageDao.countStagesForCurriculum(
        curriculumId,
      );
      expect(count, 0);
    });

    test('countStagesForCurriculum returns correct count', () async {
      await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1);

      final count = await database.stageDao.countStagesForCurriculum(
        curriculumId,
      );
      expect(count, 2);
    });

    test('countStagesForCurriculum is scoped to curriculum', () async {
      await insertStage(stageOrder: 1);
      final bavliTrackId = await database
          .into(database.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.now(),
              activatedAt: DateTime.now(),
            ),
          );
      await database.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: Value('{"type":"delay","delay_days":0}'),
        ),
      );

      final count = await database.stageDao.countStagesForCurriculum(
        curriculumId,
      );
      expect(count, 1);
    });

    test(
      'UNIQUE constraint on (curriculumId, stageOrder) rejects duplicates',
      () async {
        await insertStage(stageOrder: 1);

        expect(
          () => insertStage(stageOrder: 1, stageName: 'Duplicate'),
          throwsException,
        );
      },
    );

    test(
      'deleteAllForCurriculum removes only that curriculum stages',
      () async {
        await insertStage(stageOrder: 1);
        final bavliTrackId = await database
            .into(database.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                stateChangedAt: DateTime.now(),
                activatedAt: DateTime.now(),
              ),
            );
        await database.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 1,
            stageName: 'Learn',
            schedule: Value('{"type":"delay","delay_days":0}'),
          ),
        );

        await database.stageDao.deleteAllForCurriculum(curriculumId);

        final mishnayosStages = await database.stageDao
            .getStageDefinitionsByCurriculum(curriculumId);
        final bavliStages = await database.stageDao
            .getStageDefinitionsByCurriculum('bavli');

        expect(mishnayosStages, isEmpty);
        expect(bavliStages, hasLength(1));
      },
    );

    test('replaceStagesForCurriculum replaces existing stages', () async {
      await insertStage(stageOrder: 1);
      await insertStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1);

      await database.stageDao.replaceStagesForCurriculum(curriculumId, [
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: Value('{"type":"delay","delay_days":0}'),
        ),
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'New Stage',
          schedule: Value('{"type":"delay","delay_days":3}'),
        ),
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: 3,
          stageName: 'Another',
          schedule: Value('{"type":"delay","delay_days":14}'),
        ),
      ]);

      final stages = await database.stageDao.getStageDefinitionsByCurriculum(
        curriculumId,
      );
      expect(stages.length, 3);
      expect(stages[1].stageName, 'New Stage');
    });
  });
}
