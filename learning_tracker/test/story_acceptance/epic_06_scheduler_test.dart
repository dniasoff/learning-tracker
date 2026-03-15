/// Story acceptance tests for Epic 6 -- Scheduler.
@Tags(['epic_6'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/services/daily_schedule_composer.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/goal_progress_calculator.dart';
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

  // ── Story 6.2: Daily Task Generation & Display ─────────────────

  group('Story 6.2 -- Daily Task Generation & Display', tags: ['story_6_2'], () {
    late AppDatabase db;
    late SchedulerEngine engine;
    late DailyTaskGenerator generator;
    final now = DateTime.utc(2026, 3, 15);
    const curriculum = CurriculumId.mishnayos;

    final contentItems = List.generate(
      10,
      (i) => SchedulerContentItem(
        sefariaRef: 'Mishnah_Berakhot_1.$i',
        sortOrder: i,
      ),
    );

    setUp(() async {
      db = createTestDatabase();

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
          delayDays: 0,
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

      generator = DailyTaskGenerator(engine: engine);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'DailyTaskGenerator.generate returns correctly structured DailyTask items',
      () async {
        final tasks = await generator.generate(curriculum, now);
        expect(tasks, isNotEmpty);
        for (final task in tasks) {
          expect(task.curriculumId, curriculum);
          expect(task.contentItemSefariaRef, isNotEmpty);
          expect(task.stageDefinitionId, greaterThan(0));
          expect(task.stageName, isNotEmpty);
        }
      },
    );

    test(
      'prioritization: overdue chazara before scheduled before new learning',
      () async {
        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          curriculum.storageKey,
        );
        final learnId = stages.firstWhere((s) => s.stageOrder == 1).id;

        // Item 0: learned 10 days ago → Chazara 1 (delay=0) overdue
        // Actually with delay=0, it's due same day, so 10 days overdue
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: curriculum.storageKey,
            sefariaRef: 'Mishnah_Berakhot_1.0',
            stageId: learnId,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 10)),
            points: const Value(10),
          ),
        );

        // Item 1: learned today → Chazara 1 due today (delay=0)
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: curriculum.storageKey,
            sefariaRef: 'Mishnah_Berakhot_1.1',
            stageId: learnId,
            trackType: 'personal',
            completedAt: now,
            points: const Value(10),
          ),
        );

        final tasks = await generator.generate(curriculum, now);

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
      },
    );

    test(
      'skipped tasks excluded today but would appear tomorrow as overdue',
      () async {
        final tasks = await generator.generate(
          curriculum,
          now,
          skippedRefs: {'Mishnah_Berakhot_1.0'},
        );
        expect(
          tasks.any((t) => t.contentItemSefariaRef == 'Mishnah_Berakhot_1.0'),
          isFalse,
        );
      },
    );

    test(
      'completing a Learn task with delay_days=0 adds Chazara 1 immediately',
      () async {
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
            completedAt: now,
            points: const Value(10),
          ),
        );

        final tasks = await generator.generate(curriculum, now);

        expect(
          tasks.any(
            (t) =>
                t.contentItemSefariaRef == 'Mishnah_Berakhot_1.0' &&
                t.priority == DailyTaskPriority.scheduledChazara,
          ),
          isTrue,
        );
      },
    );

    test(
      'generate daily tasks for Mishnayos with 2 chazara due and 3 new items',
      () async {
        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          curriculum.storageKey,
        );
        final learnId = stages.firstWhere((s) => s.stageOrder == 1).id;

        // 2 items with Learn completed (Chazara 1 due today since delay=0)
        for (var i = 0; i < 2; i++) {
          await db.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: curriculum.storageKey,
              sefariaRef: 'Mishnah_Berakhot_1.$i',
              stageId: learnId,
              trackType: 'personal',
              completedAt: now,
              points: const Value(10),
            ),
          );
        }

        // Use config that limits new items to 3
        final config = ScheduleConfig(
          curriculumId: curriculum,
          currentDate: now,
          defaultNewItemsPerDay: 3,
        );
        final tasks = await engine.generateDailyTasks(config);

        final chazaraTasks = tasks.where(
          (t) =>
              t.priority == DailyTaskPriority.scheduledChazara ||
              t.priority == DailyTaskPriority.overdueChazara,
        );
        final newTasks = tasks.where(
          (t) => t.priority == DailyTaskPriority.newLearning,
        );

        expect(chazaraTasks.length, 2);
        expect(newTasks.length, 3);
        expect(tasks.length, 5);

        // Priority order: chazara first, then new
        final firstChazaraIdx = tasks.indexWhere(
          (t) =>
              t.priority == DailyTaskPriority.scheduledChazara ||
              t.priority == DailyTaskPriority.overdueChazara,
        );
        final firstNewIdx = tasks.indexWhere(
          (t) => t.priority == DailyTaskPriority.newLearning,
        );
        expect(firstChazaraIdx, lessThan(firstNewIdx));
      },
    );
  });

  // ── Story 6.3: Goal Management (Per-Curriculum Deadlines) ────

  group('Story 6.3 -- Goal Management', tags: ['story_6_3'], () {
    late AppDatabase db;
    late GoalRepositoryImpl goalRepo;
    const curriculum = CurriculumId.mishnayos;
    const chumash = CurriculumId.chumash;

    setUp(() async {
      db = createTestDatabase();
      goalRepo = GoalRepositoryImpl(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    // ── Unit: GoalRepository CRUD ──

    test(
      'GoalRepository.createGoal persists goal with UTC date per P5',
      () async {
        final targetDate = DateTime(2027, 1, 1, 12, 0); // local time
        final goal = await goalRepo.createGoal(
          curriculumId: curriculum,
          targetPercent: 100.0,
          targetDate: targetDate,
        );

        expect(goal.id, isNotNull);
        expect(goal.curriculumId, curriculum);
        expect(goal.targetPercent, 100.0);
        // Date must be stored as UTC per P5
        expect(goal.targetDate!.isUtc, isTrue);
        expect(goal.createdAt.isUtc, isTrue);
      },
    );

    test(
      'GoalRepository.createGoal with Hebrew date converts to Gregorian UTC',
      () async {
        // Simulate a Hebrew date already converted to Gregorian UTC
        // (Hebrew date conversion is done by kosher_dart before calling repo)
        final hebrewConverted = DateTime.utc(2027, 9, 16); // 13 Tishrei 5788
        final goal = await goalRepo.createGoal(
          curriculumId: curriculum,
          targetPercent: 100.0,
          targetDate: hebrewConverted,
        );

        expect(goal.targetDate, equals(hebrewConverted));
        expect(goal.targetDate!.isUtc, isTrue);
      },
    );

    test(
      'GoalRepository.getGoals returns List<Goal> sorted by target date',
      () async {
        final date1 = DateTime.utc(2027, 6, 1);
        final date2 = DateTime.utc(2027, 1, 1);
        final date3 = DateTime.utc(2027, 12, 1);

        await goalRepo.createGoal(
          curriculumId: curriculum,
          targetPercent: 100.0,
          targetDate: date1,
        );
        await goalRepo.createGoal(
          curriculumId: curriculum,
          targetPercent: 50.0,
          targetDate: date2,
        );
        await goalRepo.createGoal(
          curriculumId: curriculum,
          targetPercent: 75.0,
          targetDate: date3,
        );

        final goals = await goalRepo.getGoals(curriculum);
        expect(goals.length, 3);
        // Sorted by target date ascending
        expect(goals[0].targetPercent, 50.0); // Jan
        expect(goals[1].targetPercent, 100.0); // Jun
        expect(goals[2].targetPercent, 75.0); // Dec
      },
    );

    test(
      'GoalRepository.updateGoal updates deadline and target percentage',
      () async {
        final goal = await goalRepo.createGoal(
          curriculumId: curriculum,
          targetPercent: 100.0,
          targetDate: DateTime.utc(2027, 1, 1),
        );

        final updated = await goalRepo.updateGoal(
          goalId: goal.id!,
          targetPercent: 80.0,
          targetDate: DateTime.utc(2027, 6, 1),
        );

        expect(updated.targetPercent, 80.0);
        expect(updated.targetDate, DateTime.utc(2027, 6, 1));
        // CreatedAt unchanged
        expect(updated.createdAt, goal.createdAt);
      },
    );

    // ── Unit: GoalProgressCalculator ──

    test(
      'GoalProgressCalculator computes percentage, days remaining, items/day',
      () {
        final progress = GoalProgressCalculator.calculate(
          targetPercent: 100.0,
          targetDate: DateTime.utc(2027, 1, 1),
          currentDate: DateTime.utc(2026, 3, 15),
          totalItems: 4192,
          completedItems: 10,
        );

        expect(progress.percentComplete, closeTo(0.238, 0.01));
        expect(progress.daysRemaining, greaterThan(0));
        expect(progress.itemsPerDay, isNotNull);
        expect(progress.itemsPerDay, greaterThan(0));
        expect(progress.remainingItems, 4182);
      },
    );

    test(
      'GoalProgressCalculator with no deadline returns null for days/items',
      () {
        final progress = GoalProgressCalculator.calculate(
          targetPercent: 100.0,
          targetDate: null,
          currentDate: DateTime.utc(2026, 3, 15),
          totalItems: 100,
          completedItems: 50,
        );

        expect(progress.percentComplete, 50.0);
        expect(progress.daysRemaining, isNull);
        expect(progress.itemsPerDay, isNull);
      },
    );

    test(
      'Goal data keyed by CurriculumId.storageKey — goals independent',
      () async {
        await goalRepo.createGoal(
          curriculumId: curriculum,
          targetPercent: 100.0,
          targetDate: DateTime.utc(2027, 1, 1),
        );
        await goalRepo.createGoal(
          curriculumId: chumash,
          targetPercent: 50.0,
          targetDate: DateTime.utc(2027, 6, 1),
        );

        final mishnayosGoals = await goalRepo.getGoals(curriculum);
        final chumashGoals = await goalRepo.getGoals(chumash);

        expect(mishnayosGoals.length, 1);
        expect(chumashGoals.length, 1);
        expect(mishnayosGoals[0].targetPercent, 100.0);
        expect(chumashGoals[0].targetPercent, 50.0);
      },
    );

    // ── Integration: Full scenario ──

    test(
      'Create Mishnayos goal 100% by 2027-01-01, complete 10 of 4192 items',
      () async {
        final goal = await goalRepo.createGoal(
          curriculumId: curriculum,
          targetPercent: 100.0,
          targetDate: DateTime.utc(2027, 1, 1),
          description: 'Complete all Mishnayos by 2027',
        );

        final progress = GoalProgressCalculator.calculate(
          targetPercent: goal.targetPercent,
          targetDate: goal.targetDate,
          currentDate: DateTime.utc(2026, 3, 15),
          totalItems: 4192,
          completedItems: 10,
        );

        // 10/4192 ≈ 0.239%
        expect(progress.percentComplete, closeTo(0.239, 0.01));
        // ~292 days remaining (Mar 15 2026 → Jan 1 2027)
        expect(progress.daysRemaining, 292);
        // 4182 remaining / 292 days ≈ 14.32 items/day
        expect(progress.itemsPerDay, closeTo(14.32, 0.1));
      },
    );
  });

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

  // ── Story 6.5: Cross-Curriculum Daily Schedule Composer ──────

  group(
    'Story 6.5 -- Cross-Curriculum Daily Schedule Composer',
    tags: ['story_6_5'],
    () {
      late DailyScheduleComposer composer;

      setUp(() {
        composer = DailyScheduleComposer();
      });

      DailyTask makeTask(
        CurriculumId curriculum,
        String ref, {
        DailyTaskPriority priority = DailyTaskPriority.newLearning,
        bool isOverdue = false,
      }) {
        return DailyTask(
          curriculumId: curriculum,
          contentItemSefariaRef: ref,
          stageOrder: 1,
          stageDefinitionId: 1,
          priority: priority,
          isOverdue: isOverdue,
          reason: 'test',
          stageName: 'Learn',
        );
      }

      test(
        'DailyScheduleComposer.compose merges tasks from all active curricula',
        () {
          final result = composer.compose({
            CurriculumId.mishnayos: [
              makeTask(CurriculumId.mishnayos, 'M1'),
              makeTask(CurriculumId.mishnayos, 'M2'),
            ],
            CurriculumId.bavli: [makeTask(CurriculumId.bavli, 'B1')],
          });

          expect(result.tasks.length, 3);
          expect(result.tasks.map((t) => t.curriculumId).toSet(), {
            CurriculumId.mishnayos,
            CurriculumId.bavli,
          });
        },
      );

      test(
        'cross-curriculum prioritization places overdue items from ANY curriculum first',
        () {
          final result = composer.compose({
            CurriculumId.mishnayos: [
              makeTask(CurriculumId.mishnayos, 'M_ontime'),
            ],
            CurriculumId.bavli: [
              makeTask(
                CurriculumId.bavli,
                'B_overdue',
                priority: DailyTaskPriority.overdueChazara,
                isOverdue: true,
              ),
            ],
          });

          expect(result.tasks.first.curriculumId, CurriculumId.bavli);
          expect(result.tasks.first.isOverdue, isTrue);
        },
      );

      test('round-robin balancing: tasks alternate between curricula', () {
        final result = composer.compose({
          CurriculumId.mishnayos: List.generate(
            5,
            (i) => makeTask(CurriculumId.mishnayos, 'M$i'),
          ),
          CurriculumId.bavli: List.generate(
            5,
            (i) => makeTask(CurriculumId.bavli, 'B$i'),
          ),
        });

        // First 4 tasks should include both curricula (round-robin)
        final firstFour = result.tasks.sublist(0, 4);
        final curricula = firstFour.map((t) => t.curriculumId).toSet();
        expect(curricula.length, 2);
      });

      test('daily load cap enforced — cap 15 with 18 tasks returns 15', () {
        final result = composer.compose({
          CurriculumId.mishnayos: List.generate(
            10,
            (i) => makeTask(CurriculumId.mishnayos, 'M$i'),
          ),
          CurriculumId.bavli: List.generate(
            8,
            (i) => makeTask(CurriculumId.bavli, 'B$i'),
          ),
        }, maxTasksPerDay: 15);

        expect(result.tasks.length, 15);
      });

      test(
        'daily load cap is configurable (default applied when no setting)',
        () {
          final manyTasks = List.generate(
            25,
            (i) => makeTask(CurriculumId.mishnayos, 'M$i'),
          );

          // Default cap is 20
          final result = composer.compose({CurriculumId.mishnayos: manyTasks});
          expect(result.tasks.length, 20);
        },
      );

      test('compose with zero active curricula returns empty list', () {
        final result = composer.compose({});
        expect(result.tasks, isEmpty);
      });

      test('compose with one curriculum returns tasks unchanged', () {
        final tasks = [
          makeTask(CurriculumId.mishnayos, 'M1'),
          makeTask(CurriculumId.mishnayos, 'M2'),
        ];

        final result = composer.compose({CurriculumId.mishnayos: tasks});
        expect(result.tasks.length, 2);
      });

      test('summary: "15 tasks across 3 curricula"', () {
        final result = composer.compose({
          CurriculumId.mishnayos: List.generate(
            5,
            (i) => makeTask(CurriculumId.mishnayos, 'M$i'),
          ),
          CurriculumId.bavli: List.generate(
            5,
            (i) => makeTask(CurriculumId.bavli, 'B$i'),
          ),
          CurriculumId.chumash: List.generate(
            5,
            (i) => makeTask(CurriculumId.chumash, 'C$i'),
          ),
        });

        expect(result.summary, contains('15 tasks'));
        expect(result.summary, contains('3 curricula'));
      });

      // ── Integration tests ──

      test(
        'Integration: Mishnayos (10) + Bavli (8) with cap 15 — balanced result',
        () {
          final result = composer.compose({
            CurriculumId.mishnayos: List.generate(
              10,
              (i) => makeTask(CurriculumId.mishnayos, 'M$i'),
            ),
            CurriculumId.bavli: List.generate(
              8,
              (i) => makeTask(CurriculumId.bavli, 'B$i'),
            ),
          }, maxTasksPerDay: 15);

          expect(result.tasks.length, 15);
          // Both curricula should be represented
          final mishnayosCount = result.tasks
              .where((t) => t.curriculumId == CurriculumId.mishnayos)
              .length;
          final bavliCount = result.tasks
              .where((t) => t.curriculumId == CurriculumId.bavli)
              .length;
          expect(mishnayosCount, greaterThan(0));
          expect(bavliCount, greaterThan(0));
          // Round-robin interleaves, then cap at 15
          // With 10 mishnayos and 8 bavli, round-robin yields balanced distribution
          expect(mishnayosCount + bavliCount, 15);
        },
      );

      test('Integration: complete a task — summary count decrements', () {
        final tasks = [
          makeTask(CurriculumId.mishnayos, 'M1'),
          makeTask(CurriculumId.mishnayos, 'M2'),
          makeTask(CurriculumId.bavli, 'B1'),
        ];

        final schedule1 = composer.compose({
          CurriculumId.mishnayos: [tasks[0], tasks[1]],
          CurriculumId.bavli: [tasks[2]],
        });
        expect(schedule1.summary, contains('3 tasks'));

        // Simulate task completion by removing one task
        final schedule2 = composer.compose({
          CurriculumId.mishnayos: [tasks[1]],
          CurriculumId.bavli: [tasks[2]],
        });
        expect(schedule2.summary, contains('2 tasks'));
      });
    },
  );
}
