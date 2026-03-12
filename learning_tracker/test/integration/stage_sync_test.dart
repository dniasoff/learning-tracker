import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';

void main() {
  late AppDatabase database;
  late List<Map<String, dynamic>> pushedSettings;
  late StageDefinitionRepositoryImpl repository;

  const curriculum = CurriculumId.mishnayos;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    pushedSettings = [];
    repository = StageDefinitionRepositoryImpl(
      stageDao: database.stageDao,
      completionDao: database.completionDao,
      pushSettings: (settings) async => pushedSettings.add(settings),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Stage sync integration', () {
    test(
      'initializeDefaults then addStage — push payload contains all stages',
      () async {
        await repository.initializeDefaults(curriculum);

        pushedSettings.clear();

        final newStage = await repository.addStage(curriculum, 'Chazara 3', 30);

        expect(newStage.stageName, 'Chazara 3');
        expect(newStage.stageOrder, 4);
        expect(newStage.isDefault, false);

        // Push should have been called once with all 4 stages
        expect(pushedSettings, hasLength(1));
        final payload = pushedSettings[0];
        expect(payload['curriculum_id'], curriculum.storageKey);

        final stages = payload['stages'] as List<dynamic>;
        expect(stages, hasLength(4));

        final stage4 =
            stages.firstWhere((s) => (s as Map)['stage_order'] == 4) as Map;
        expect(stage4['stage_name'], 'Chazara 3');
        expect(stage4['delay_days'], 30);
        expect(stage4['is_default'], false);
      },
    );

    test(
      'replaceStagesForCurriculum restores stages from Firestore payload',
      () async {
        await repository.initializeDefaults(curriculum);

        // Simulate Firestore payload arriving with 4 stages
        final firestoreStages = [
          StageDefinitionsCompanion.insert(
            curriculumId: curriculum.storageKey,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
            isDefault: const Value(true),
          ),
          StageDefinitionsCompanion.insert(
            curriculumId: curriculum.storageKey,
            stageOrder: 2,
            stageName: 'Chazara 1',
            delayDays: 1,
            isDefault: const Value(true),
          ),
          StageDefinitionsCompanion.insert(
            curriculumId: curriculum.storageKey,
            stageOrder: 3,
            stageName: 'Chazara 2',
            delayDays: 7,
            isDefault: const Value(true),
          ),
          StageDefinitionsCompanion.insert(
            curriculumId: curriculum.storageKey,
            stageOrder: 4,
            stageName: 'Chazara 3',
            delayDays: 30,
            isDefault: const Value(false),
          ),
        ];

        await database.stageDao.replaceStagesForCurriculum(
          curriculum.storageKey,
          firestoreStages,
        );

        final restored = await repository.getStagesForCurriculum(curriculum);

        expect(restored, hasLength(4));
        expect(restored.last.stageName, 'Chazara 3');
        expect(restored.last.delayDays, 30);
        expect(restored.last.isDefault, false);
      },
    );

    test('resetToDefaults restores exactly 3 stages and pushes', () async {
      await repository.initializeDefaults(curriculum);
      await repository.addStage(curriculum, 'Custom', 60);

      pushedSettings.clear();
      await repository.resetToDefaults(curriculum);

      final stages = await repository.getStagesForCurriculum(curriculum);
      expect(stages, hasLength(3));
      expect(stages.map((s) => s.stageName).toList(), [
        'Learn',
        'Chazara 1',
        'Chazara 2',
      ]);
      expect(pushedSettings, hasLength(1));
    });
  });
}
