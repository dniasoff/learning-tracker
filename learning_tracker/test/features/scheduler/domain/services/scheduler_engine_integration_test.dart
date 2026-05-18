import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

import '../../../../helpers/test_database.dart';

/// Fake content repository that returns in-memory items (no asset loading).
class InMemoryContentRepo implements SchedulerContentRepository {
  final List<SchedulerContentItem> _items;
  InMemoryContentRepo(this._items);

  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async =>
      _items;
}

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'full round-trip: import content, set stages, set goal, generate tasks, mark completions, regenerate',
    () async {
      const curriculum = CurriculumId.mishnayos;
      final now = DateTime.utc(2026, 3, 15);

      final trackRow = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: 0,
              curriculumId: curriculum.storageKey,
              trackType: 'personal',
              activatedAt: DateTime.now(),
            ),
          );
      trackId = trackRow.id;

      // 1. Set up stages
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
      );

      // 2. Content (in-memory, simulating imported content)
      final contentItems = List.generate(
        10,
        (i) => SchedulerContentItem(
          sefariaRef: 'Mishnah_Berakhot_1.$i',
          sortOrder: i,
        ),
      );

      // 3. Build engine with real DB repositories + in-memory content
      final engine = SchedulerEngine(
        contentRepository: InMemoryContentRepo(contentItems),
        completionRepository: SchedulerCompletionRepositoryImpl(
          completionDao: db.completionDao,
          stageDao: db.stageDao,
          profileId: 1,
        ),
        stageRepository: SchedulerStageRepositoryImpl(stageDao: db.stageDao),
        learningOrderRepository: SchedulerLearningOrderRepositoryImpl(
          learningOrderDao: db.learningOrderDao,
        ),
      );

      // 4. Generate initial tasks (no completions yet)
      var config = ScheduleConfig(
        curriculumId: curriculum,
        trackId: 1,
        trackLabel: 'Test Track',
        goalDeadline: now.add(const Duration(days: 5)),
        currentDate: now,
      );

      var tasks = await engine.generateDailyTasks(config);
      // 10 items / 5 days = 2 new items per day
      expect(
        tasks.where((t) => t.priority == DailyTaskPriority.newLearning).length,
        2,
      );

      // 5. Mark completions for first 2 items (Learn stage)
      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        curriculum.storageKey,
      );
      final learnStageId = stages.firstWhere((s) => s.stageOrder == 1).id;

      for (var i = 0; i < 2; i++) {
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            sefariaRef: 'Mishnah_Berakhot_1.$i',
            stageId: learnStageId,
            trackType: 'personal',
            completedAt: now,
            points: const Value(10),
          ),
        );
      }

      // 6. Regenerate next day — should reflect updated state
      config = ScheduleConfig(
        curriculumId: curriculum,
        trackId: 1,
        trackLabel: 'Test Track',
        goalDeadline: now.add(const Duration(days: 5)),
        currentDate: now.add(const Duration(days: 1)),
      );

      tasks = await engine.generateDailyTasks(config);

      // Chazara 1 (delayDays=1) should now be due for the 2 completed items
      final chazaraTasks = tasks.where(
        (t) => t.priority == DailyTaskPriority.scheduledChazara,
      );
      expect(chazaraTasks.length, 2);

      // Should still have new learning items (8 remaining / 4 days = 2)
      final newTasks = tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      expect(newTasks.length, 2);
    },
  );
}
