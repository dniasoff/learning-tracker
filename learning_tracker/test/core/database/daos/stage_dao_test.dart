import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
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
      curriculumId: curriculumId,
      stageOrder: stageOrder,
      stageName: stageName,
      delayDays: delayDays,
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
      await database.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'bavli',
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
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
        await database.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: 'bavli',
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
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
          curriculumId: curriculumId,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        StageDefinitionsCompanion.insert(
          curriculumId: curriculumId,
          stageOrder: 2,
          stageName: 'New Stage',
          delayDays: 3,
        ),
        StageDefinitionsCompanion.insert(
          curriculumId: curriculumId,
          stageOrder: 3,
          stageName: 'Another',
          delayDays: 14,
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
