/// Story acceptance tests for Epic 6 -- Scheduler.
@Tags(['epic_6'])
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

class _InMemoryContentRepo implements SchedulerContentRepository {
  final List<SchedulerContentItem> items;
  _InMemoryContentRepo(this.items);
  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async =>
      items;
}

void main() {
  // ── Story 6.1: Parametric Scheduler Engine ─────────────────────────

  group('Story 6.1 -- Parametric Scheduler Engine', tags: ['story_6_1'], () {
    late AppDatabase db;
    late SchedulerEngine engine;
    final now = DateTime.utc(2026, 3, 15);
    const curriculum = CurriculumId.mishnayos;

    final contentItems = List.generate(
      20,
      (i) => SchedulerContentItem(
        sefariaRef: 'Mishnah_Berakhot_1.$i',
        sortOrder: i,
      ),
    );

    setUp(() async {
      db = createTestDatabase();

      // Set up 3 stages
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: curriculum.storageKey,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: curriculum.storageKey,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: curriculum.storageKey,
          stageOrder: 3,
          stageName: 'Chazara 2',
          delayDays: 7,
        ),
      );

      engine = SchedulerEngine(
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
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'scheduler generates a daily task list with new learning items',
      () async {
        final config = ScheduleConfig(
          curriculumId: curriculum,
          goalDeadline: now.add(const Duration(days: 10)),
          currentDate: now,
        );

        final tasks = await engine.generateDailyTasks(config);
        expect(tasks, isNotEmpty);

        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        // 20 items / 10 days = 2
        expect(newTasks.length, 2);
      },
    );

    test('items are ordered by urgency (overdue > scheduled > new)', () async {
      // Complete first item yesterday (Chazara 1 due today)
      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        curriculum.storageKey,
      );
      final learnId = stages.firstWhere((s) => s.stageOrder == 1).id;

      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: curriculum.storageKey,
          sefariaRef: 'Mishnah_Berakhot_1.0',
          stageId: learnId,
          trackType: 'personal',
          completedAt: now.subtract(const Duration(days: 1)),
          points: const Value(10),
        ),
      );

      final config = ScheduleConfig(curriculumId: curriculum, currentDate: now);

      final tasks = await engine.generateDailyTasks(config);

      // First task should be chazara (scheduled), then new learning
      final firstChazara = tasks.indexWhere(
        (t) => t.priority == DailyTaskPriority.scheduledChazara,
      );
      final firstNew = tasks.indexWhere(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );

      expect(firstChazara, greaterThanOrEqualTo(0));
      expect(firstNew, greaterThan(firstChazara));
    });
  });

  // ── Story 6.2: Spaced repetition algorithm ────────────────────

  group(
    'Story 6.2 -- Spaced repetition algorithm',
    tags: ['story_6_2'],
    skip: 'Backlog: spaced repetition algorithm not yet implemented',
    () {
      test('delay-based spacing uses stage delayDays', () {});
      test('completing all stages marks content as mastered', () {});
    },
  );

  // ── Story 6.3: Session management ─────────────────────────────

  group(
    'Story 6.3 -- Session management',
    tags: ['story_6_3'],
    skip: 'Backlog: session management not yet implemented',
    () {
      test('session tracks items reviewed and time spent', () {});
      test('session can be paused and resumed', () {});
    },
  );

  // ── Story 6.4: Calendar integration ───────────────────────────

  group(
    'Story 6.4 -- Calendar integration',
    tags: ['story_6_4'],
    skip: 'Backlog: calendar integration not yet implemented',
    () {
      test('Hebrew calendar dates shown in scheduler view', () {});
      test('Shabbos and Yom Tov days are marked differently', () {});
    },
  );

  // ── Story 6.5: Streak tracking ────────────────────────────────

  group(
    'Story 6.5 -- Streak tracking',
    tags: ['story_6_5'],
    skip: 'Backlog: streak tracking not yet implemented',
    () {
      test('daily streak increments on consecutive learning days', () {});
      test('streak resets after a missed day', () {});
      test('Shabbos does not break streak', () {});
    },
  );
}
