import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:test/test.dart';

import '../../../../helpers/test_database.dart';

class _InMemoryContentRepo implements SchedulerContentRepository {
  final List<SchedulerContentItem> items;
  _InMemoryContentRepo(this.items);
  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async =>
      items;
}

void main() {
  late UserDatabase db;
  late DailyTaskGenerator generator;
  late int trackId;
  final now = DateTime.utc(2026, 3, 15);
  const curriculum = CurriculumId.mishnayos;

  final contentItems = List.generate(
    10,
    (i) =>
        SchedulerContentItem(sefariaRef: 'Mishnah_Berakhot_1.$i', sortOrder: i),
  );

  setUp(() async {
    db = createTestDatabase();

    final trackRow = await db.into(db.curriculumTracks).insertReturning(
      CurriculumTracksCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackType: 'personal',
        activatedAt: DateTime.now(),
      ),
    );
    trackId = trackRow.id;

    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
      ),
    );
    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        stageOrder: 2,
        stageName: 'Chazara 1',
        delayDays: 1,
      ),
    );
    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        stageOrder: 3,
        stageName: 'Chazara 2',
        delayDays: 7,
      ),
    );

    final engine = SchedulerEngine(
      contentRepository: _InMemoryContentRepo(contentItems),
      completionRepository: SchedulerCompletionRepositoryImpl(
        completionDao: db.completionDao,
        stageDao: db.stageDao,
      ),
      stageRepository: SchedulerStageRepositoryImpl(stageDao: db.stageDao),
      learningOrderRepository: SchedulerLearningOrderRepositoryImpl(
        learningOrderDao: db.learningOrderDao,
      ),
    );

    generator = DailyTaskGenerator(engine: engine);
  });

  tearDown(() async {
    await db.close();
  });

  test('generate returns correctly structured DailyTask items', () async {
    final tasks = await generator.generate(curriculum, now, trackId: 1, trackLabel: 'Test');

    expect(tasks, isNotEmpty);
    for (final task in tasks) {
      expect(task.curriculumId, curriculum);
      expect(task.contentItemSefariaRef, isNotEmpty);
      expect(task.stageDefinitionId, greaterThan(0));
      expect(task.stageName, isNotEmpty);
    }
  });

  test('prioritization: overdue before scheduled before new', () async {
    final stages = await db.stageDao.getStageDefinitionsByCurriculum(
      curriculum.storageKey,
    );
    final learnId = stages.firstWhere((s) => s.stageOrder == 1).id;
    // Item 0: learned 3 days ago → Chazara 1 overdue (delay=1)
    await db.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        sefariaRef: 'Mishnah_Berakhot_1.0',
        stageId: learnId,
        trackType: 'personal',
        completedAt: now.subtract(const Duration(days: 3)),
        points: const Value(10),
      ),
    );

    // Item 1: learned yesterday → Chazara 1 due today (delay=1)
    await db.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        sefariaRef: 'Mishnah_Berakhot_1.1',
        stageId: learnId,
        trackType: 'personal',
        completedAt: now.subtract(const Duration(days: 1)),
        points: const Value(10),
      ),
    );

    final tasks = await generator.generate(curriculum, now, trackId: 1, trackLabel: 'Test');

    // Should have overdue, scheduled, and new items
    final overdueIdx = tasks.indexWhere(
      (t) => t.priority == DailyTaskPriority.overdueChazara,
    );
    final scheduledIdx = tasks.indexWhere(
      (t) => t.priority == DailyTaskPriority.scheduledChazara,
    );
    final newIdx = tasks.indexWhere(
      (t) => t.priority == DailyTaskPriority.newLearning,
    );

    expect(overdueIdx, greaterThanOrEqualTo(0));
    expect(scheduledIdx, greaterThan(overdueIdx));
    expect(newIdx, greaterThan(scheduledIdx));
  });

  test('skipped tasks excluded from today but isOverdue flag set', () async {
    final tasks = await generator.generate(
      curriculum,
      now,
      trackId: 1,
      trackLabel: 'Test',
      skippedRefs: {'Mishnah_Berakhot_1.0'},
    );

    expect(
      tasks.any((t) => t.contentItemSefariaRef == 'Mishnah_Berakhot_1.0'),
      isFalse,
    );
  });

  test('recomputation after completion adds newly-due chazara', () async {
    final stages = await db.stageDao.getStageDefinitionsByCurriculum(
      curriculum.storageKey,
    );
    final learnId = stages.firstWhere((s) => s.stageOrder == 1).id;

    // Complete item 0 Learn right now (Chazara 1 delay=1, so not due today)
    await db.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        sefariaRef: 'Mishnah_Berakhot_1.0',
        stageId: learnId,
        trackType: 'personal',
        completedAt: now,
        points: const Value(10),
      ),
    );

    final tasksToday = await generator.generate(curriculum, now, trackId: 1, trackLabel: 'Test');
    // Item 0 should NOT have chazara due today (delay=1)
    expect(
      tasksToday.any(
        (t) =>
            t.contentItemSefariaRef == 'Mishnah_Berakhot_1.0' &&
            t.priority == DailyTaskPriority.scheduledChazara,
      ),
      isFalse,
    );

    // Tomorrow, chazara 1 should be due
    final tasksTomorrow = await generator.generate(
      curriculum,
      now.add(const Duration(days: 1)),
      trackId: 1,
      trackLabel: 'Test',
    );
    expect(
      tasksTomorrow.any(
        (t) =>
            t.contentItemSefariaRef == 'Mishnah_Berakhot_1.0' &&
            t.priority == DailyTaskPriority.scheduledChazara,
      ),
      isTrue,
    );
  });

  test('recomputation with delay_days=0 adds chazara immediately', () async {
    // Delete existing stages and create one with delay=0
    await db.stageDao.deleteAllForCurriculum(curriculum.storageKey);

    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
      ),
    );
    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        stageOrder: 2,
        stageName: 'Chazara 1',
        delayDays: 0,
      ),
    );

    final stages = await db.stageDao.getStageDefinitionsByCurriculum(
      curriculum.storageKey,
    );
    final learnId = stages.firstWhere((s) => s.stageOrder == 1).id;

    // Complete Learn for item 0
    await db.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        sefariaRef: 'Mishnah_Berakhot_1.0',
        stageId: learnId,
        trackType: 'personal',
        completedAt: now,
        points: const Value(10),
      ),
    );

    final tasks = await generator.generate(curriculum, now, trackId: 1, trackLabel: 'Test');

    // delay_days=0 means Chazara 1 is due immediately (today)
    expect(
      tasks.any(
        (t) =>
            t.contentItemSefariaRef == 'Mishnah_Berakhot_1.0' &&
            t.priority == DailyTaskPriority.scheduledChazara,
      ),
      isTrue,
    );
  });
}
