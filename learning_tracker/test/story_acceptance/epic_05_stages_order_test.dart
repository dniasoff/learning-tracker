/// Story acceptance tests for Epic 5 -- Stages & Order.
@Tags(['epic_5'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:test/test.dart';

void main() {
  // ── Story 5.1: Custom stage definitions ───────────────────────

  group('Story 5.1 -- Custom stage definitions', tags: ['story_5_1'], () {
    late AppDatabase database;
    late StageDefinitionRepositoryImpl repository;
    const curriculum = CurriculumId.mishnayos;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = StageDefinitionRepositoryImpl(
        stageDao: database.stageDao,
        completionDao: database.completionDao,
        pushSettings: (_) async {},
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('user can add a custom chazara stage', () async {
      await repository.initializeDefaults(curriculum);

      final newStage = await repository.addStage(curriculum, 'Chazara 3', 30);

      expect(newStage.stageName, 'Chazara 3');
      expect(newStage.delayDays, 30);
      expect(newStage.isDefault, false);
      expect(newStage.stageOrder, 4);

      final all = await repository.getStagesForCurriculum(curriculum);
      expect(all, hasLength(4));
    });

    test('user can reorder stages', () async {
      await repository.initializeDefaults(curriculum);
      final stages = await repository.getStagesForCurriculum(curriculum);
      // Reverse order: [3, 2, 1]
      final reversed = stages.reversed.map((s) => s.id).toList();

      await repository.reorderStages(curriculum, reversed);

      final reordered = await repository.getStagesForCurriculum(curriculum);
      expect(reordered[0].stageOrder, 1);
      expect(reordered[0].stageName, 'Chazara 2');
      expect(reordered[2].stageName, 'Learn');
    });

    test('user can adjust delay days for a stage', () async {
      await repository.initializeDefaults(curriculum);
      final stages = await repository.getStagesForCurriculum(curriculum);
      final chazara1 = stages.firstWhere((s) => s.stageName == 'Chazara 1');

      await repository.updateStage(chazara1.id, delayDays: 3);

      final updated = await repository.getStagesForCurriculum(curriculum);
      final updatedStage = updated.firstWhere((s) => s.id == chazara1.id);
      expect(updatedStage.delayDays, 3);
    });
  });

  // ── Story 5.2: Custom learning order ──────────────────────────

  group(
    'Story 5.2 -- Custom learning order',
    tags: ['story_5_2'],
    skip: 'Backlog: custom learning order not yet implemented',
    () {
      test('user can reorder content items within a curriculum', () {
        // TODO: verify LearningOrderDao reorder
      });

      test('custom order persists across sessions', () {
        // TODO: verify order survives database close/reopen
      });
    },
  );
}
