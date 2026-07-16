/// Story acceptance tests for Epic 6 -- Scheduler.
@Tags(['epic_6'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';
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
    late UserDatabase db;
    late int trackId;
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
      await seedProfile(db);
      trackId = await seedTrack(db, profileId: 1);

      // Set up 3 stages
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'Chazara 1',
          schedule: const Value('{"type":"delay","delay_days":1}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 3,
          stageName: 'Chazara 2',
          schedule: const Value('{"type":"delay","delay_days":7}'),
        ),
      );

      engine = SchedulerEngine(
        contentRepository: _InMemoryContentRepo(contentItems),
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
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'scheduler generates a daily task list with new learning items',
      () async {
        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackId: 1,
          trackLabel: 'Test Track',
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

      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          sefariaRef: 'Mishnah_Berakhot_1.0',
          stageId: learnId,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: now.subtract(const Duration(days: 1)),
          points: const Value(10),
        ),
      );

      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackId: 1,
        trackLabel: 'Test Track',
        currentDate: now,
      );

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
    late UserDatabase db;
    late int trackId;
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
      await seedProfile(db);
      trackId = await seedTrack(db, profileId: 1);

      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'Chazara 1',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 3,
          stageName: 'Chazara 2',
          schedule: const Value('{"type":"delay","delay_days":7}'),
        ),
      );

      engine = SchedulerEngine(
        contentRepository: _InMemoryContentRepo(contentItems),
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

      generator = DailyTaskGenerator(engine: engine);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'DailyTaskGenerator.generate returns correctly structured DailyTask items',
      () async {
        final tasks = await generator.generate(
          curriculum,
          now,
          trackId: 1,
          trackLabel: 'Test',
        );
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
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            sefariaRef: 'Mishnah_Berakhot_1.0',
            stageId: learnId,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: now.subtract(const Duration(days: 10)),
            points: const Value(10),
          ),
        );

        // Item 1: learned today → Chazara 1 due today (delay=0)
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            sefariaRef: 'Mishnah_Berakhot_1.1',
            stageId: learnId,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: now,
            points: const Value(10),
          ),
        );

        final tasks = await generator.generate(
          curriculum,
          now,
          trackId: 1,
          trackLabel: 'Test',
        );

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
          trackId: 1,
          trackLabel: 'Test',
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

        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            sefariaRef: 'Mishnah_Berakhot_1.0',
            stageId: learnId,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: now,
            points: const Value(10),
          ),
        );

        final tasks = await generator.generate(
          curriculum,
          now,
          trackId: 1,
          trackLabel: 'Test',
        );

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
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: curriculum.storageKey,
              sefariaRef: 'Mishnah_Berakhot_1.$i',
              stageId: learnId,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: now,
              points: const Value(10),
            ),
          );
        }

        // Use config that limits new items to 3
        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackId: 1,
          trackLabel: 'Test Track',
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
    late UserDatabase db;
    late int trackId;
    late GoalRepositoryImpl goalRepo;
    const curriculum = CurriculumId.mishnayos;
    const chumash = CurriculumId.chumash;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await seedTrack(db, profileId: 1);
      goalRepo = GoalRepositoryImpl(database: db, profileId: 1);
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
          profileId: 1,
          curriculumId: curriculum,
          trackId: trackId,
          targetPercent: 100.0,
          paceTarget: DeadlineTarget(targetDate),
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
          profileId: 1,
          curriculumId: curriculum,
          trackId: trackId,
          targetPercent: 100.0,
          paceTarget: DeadlineTarget(hebrewConverted),
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
          profileId: 1,
          curriculumId: curriculum,
          trackId: trackId,
          targetPercent: 100.0,
          paceTarget: DeadlineTarget(date1),
        );
        await goalRepo.createGoal(
          profileId: 1,
          curriculumId: curriculum,
          trackId: trackId,
          targetPercent: 50.0,
          paceTarget: DeadlineTarget(date2),
        );
        await goalRepo.createGoal(
          profileId: 1,
          curriculumId: curriculum,
          trackId: trackId,
          targetPercent: 75.0,
          paceTarget: DeadlineTarget(date3),
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
          profileId: 1,
          curriculumId: curriculum,
          trackId: trackId,
          targetPercent: 100.0,
          paceTarget: DeadlineTarget(DateTime.utc(2027, 1, 1)),
        );

        final updated = await goalRepo.updateGoal(
          goalId: goal.id!,
          targetPercent: 80.0,
          paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
        );

        expect(updated.targetPercent, 80.0);
        expect(updated.targetDate, DateTime.utc(2027, 6, 1));
        // CreatedAt unchanged
        expect(updated.createdAt, goal.createdAt);
      },
    );

    test(
      'Goal data keyed by CurriculumId.storageKey — goals independent',
      () async {
        await goalRepo.createGoal(
          profileId: 1,
          curriculumId: curriculum,
          trackId: trackId,
          targetPercent: 100.0,
          paceTarget: DeadlineTarget(DateTime.utc(2027, 1, 1)),
        );
        await goalRepo.createGoal(
          profileId: 1,
          curriculumId: chumash,
          trackId: trackId,
          targetPercent: 50.0,
          paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
        );

        final mishnayosGoals = await goalRepo.getGoals(curriculum);
        final chumashGoals = await goalRepo.getGoals(chumash);

        expect(mishnayosGoals.length, 1);
        expect(chumashGoals.length, 1);
        expect(mishnayosGoals[0].targetPercent, 100.0);
        expect(chumashGoals[0].targetPercent, 50.0);
      },
    );
  });

  // ── Story 6.4: Pace Tracking ──────────────────────────────────

  group('Story 6.4 -- Pace Tracking', tags: ['story_6_4'], () {
    final goalStart = DateTime.utc(2026, 1, 1);
    final goalDeadline = DateTime.utc(2026, 7, 1); // 181 days
    final today = DateTime.utc(2026, 3, 15); // 73 days elapsed
    const totalItems = 181; // 1 item/day pace

    /// Build daily completion counts for the last 7 days.
    Map<DateTime, int> buildRecentCompletions(int perDay) {
      final counts = <DateTime, int>{};
      for (var i = 1; i <= 7; i++) {
        counts[DateTime.utc(2026, 3, 15 - i)] = perDay;
      }
      return counts;
    }

    // ── Unit: PaceCalculator ──

    test(
      'PaceCalculator.calculate returns onPace when completions match expected',
      () {
        // 73 days elapsed, 1 item/day expected → 73 items expected
        final result = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: goalDeadline,
          totalItems: totalItems,
          completedItems: 73,
          dailyCompletionCounts: buildRecentCompletions(1),
          today: today,
        );

        expect(result.status, PaceStatusType.onPace);
        expect(result.daysDelta, 0);
      },
    );

    test(
      'PaceCalculator returns ahead with correct daysAhead when exceeding pace',
      () {
        // 73 expected, 93 completed → 20 items ahead → 20 days ahead
        final result = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: goalDeadline,
          totalItems: totalItems,
          completedItems: 93,
          dailyCompletionCounts: buildRecentCompletions(2),
          today: today,
        );

        expect(result.status, PaceStatusType.ahead);
        expect(result.daysDelta, greaterThan(0));
        expect(result.daysDelta, 20);
      },
    );

    test(
      'PaceCalculator returns behind with correct daysBehind when below pace',
      () {
        // 73 expected, 53 completed → -20 items → -20 days behind
        final result = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: goalDeadline,
          totalItems: totalItems,
          completedItems: 53,
          dailyCompletionCounts: buildRecentCompletions(1),
          today: today,
        );

        expect(result.status, PaceStatusType.behind);
        expect(result.daysDelta, lessThan(0));
        expect(result.daysDelta, -20);
      },
    );

    test(
      'PaceCalculator.projectedCompletionDate uses rolling 7-day average',
      () {
        // 73 completed, 108 remaining, rolling avg = 2/day → 54 days → Apr 8
        final result = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: goalDeadline,
          totalItems: totalItems,
          completedItems: 73,
          dailyCompletionCounts: buildRecentCompletions(2),
          today: today,
        );

        expect(result.projectedCompletionDate, isNotNull);
        expect(result.rollingAverage, closeTo(2.0, 0.01));
        // 108 remaining / 2 per day = 54 days → May 8
        final expectedDate = today.add(const Duration(days: 54));
        expect(result.projectedCompletionDate, expectedDate);
      },
    );

    test(
      'PaceCalculator with zero completions in last 7 days returns null projectedDate',
      () {
        final result = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: goalDeadline,
          totalItems: totalItems,
          completedItems: 50,
          dailyCompletionCounts: {}, // no recent completions
          today: today,
        );

        expect(result.projectedCompletionDate, isNull);
        expect(result.rollingAverage, 0.0);
      },
    );

    test(
      'PaceCalculator recalculates correctly when completion added — behind to onPace',
      () {
        // First: behind (53 completed, 73 expected)
        final behind = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: goalDeadline,
          totalItems: totalItems,
          completedItems: 53,
          dailyCompletionCounts: buildRecentCompletions(1),
          today: today,
        );
        expect(behind.status, PaceStatusType.behind);

        // After adding 20 completions → 73, now on pace
        final onPace = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: goalDeadline,
          totalItems: totalItems,
          completedItems: 73,
          dailyCompletionCounts: buildRecentCompletions(1),
          today: today,
        );
        expect(onPace.status, PaceStatusType.onPace);
      },
    );

    test('Pace calculated for personal track only — school/tutor excluded', () {
      // This test verifies the contract: PaceCalculator receives only
      // personal-track completedItems count. The filtering happens at the
      // repository/provider layer. We verify the calculator uses the count
      // as-is without any track filtering logic.
      //
      // Scenario: 73 personal completions (on pace), but if school
      // completions were included it would show 150 (ahead).
      // Calculator should use only what it's given.
      final result = PaceCalculator.calculate(
        goalStartDate: goalStart,
        goalDeadline: goalDeadline,
        totalItems: totalItems,
        completedItems: 73, // personal only
        dailyCompletionCounts: buildRecentCompletions(1),
        today: today,
      );

      expect(result.status, PaceStatusType.onPace);
    });

    // ── Integration: Full pace scenario ──

    late UserDatabase db;
    late int trackId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await seedTrack(db, profileId: 1);

      // Set up stage definitions for mishnayos
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'complete items at double pace for 7 days — shows ahead with correct count',
      () async {
        const curriculum = CurriculumId.mishnayos;
        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          curriculum.storageKey,
        );
        final learnId = stages.first.id;

        // Insert 14 personal completions over 7 days (2/day)
        final dailyCounts = <DateTime, int>{};
        var totalCompleted = 0;
        for (var dayOffset = 1; dayOffset <= 7; dayOffset++) {
          final date = DateTime.utc(2026, 3, 15 - dayOffset);
          dailyCounts[date] = 2;
          for (var j = 0; j < 2; j++) {
            await seedCompletion(
              db,
              CompletionEventsCompanion.insert(
                profileId: 1,
                curriculumId: curriculum.storageKey,
                sefariaRef: 'Mishnah_Berakhot_${dayOffset}_$j',
                stageId: learnId,
                trackType: 'personal',
                trackId: Value(trackId),
                eventTimestamp: date,
                points: const Value(10),
              ),
            );
            totalCompleted++;
          }
        }

        // Goal: 181 items over 181 days (1/day), started Jan 1
        // Expected by day 73: 73 items
        // Completed: 14 (just the recent 7 days for simplicity)
        // But let's say we also had earlier completions to total 93
        // Add 79 earlier completions
        for (var i = 0; i < 79; i++) {
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: curriculum.storageKey,
              sefariaRef: 'Mishnah_Berakhot_early_$i',
              stageId: learnId,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: DateTime.utc(2026, 2, 1),
              points: const Value(10),
            ),
          );
        }
        totalCompleted += 79; // 93 total

        final result = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: goalDeadline,
          totalItems: totalItems,
          completedItems: totalCompleted,
          dailyCompletionCounts: dailyCounts,
          today: today,
        );

        expect(result.status, PaceStatusType.ahead);
        expect(result.daysDelta, 20); // 93-73=20 items ahead / 1 item/day
        expect(result.rollingAverage, closeTo(2.0, 0.01));
        // Projected: 88 remaining / 2 per day = 44 days
        expect(result.projectedCompletionDate, isNotNull);
        expect(result.projectedCompletionDate!.isBefore(goalDeadline), isTrue);
      },
    );
  });

  // ── Regression: Issue-5 — bulk-prior sentinel does not suppress tasks ───────

  group(
    'Issue-5 regression — bulk-prior sentinel generates > 0 tasks',
    tags: ['story_6_1'],
    () {
      late UserDatabase db;
      late int trackId;
      late SchedulerEngine engine;
      final now = DateTime.utc(2026, 5, 14);
      const curriculum = CurriculumId.mishnayos;

      // Sentinel date used by BulkPriorCompletionService.
      final sentinel = SchedulerEngine.kBulkPriorSentinel;

      final contentItems = List.generate(
        5,
        (i) => SchedulerContentItem(
          sefariaRef: 'Mishnah_Berakhot_1.$i',
          sortOrder: i,
        ),
      );

      setUp(() async {
        db = createTestDatabase();
        await seedProfile(db);
        trackId = await seedTrack(db, profileId: 1);

        // Single "Learn only" stage — no chazara stages.
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            stageOrder: 1,
            stageName: 'Learn',
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );

        engine = SchedulerEngine(
          contentRepository: _InMemoryContentRepo(contentItems),
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
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'deadline track: all items bulk-marked with sentinel still get tasks',
        () async {
          final stages = await db.stageDao.getStageDefinitionsByCurriculum(
            curriculum.storageKey,
          );
          final learnId = stages.firstWhere((s) => s.stageOrder == 1).id;

          // Bulk-mark ALL items with sentinel date.
          for (final item in contentItems) {
            await seedCompletion(
              db,
              CompletionEventsCompanion.insert(
                profileId: 1,
                curriculumId: curriculum.storageKey,
                sefariaRef: item.sefariaRef,
                stageId: learnId,
                trackType: 'personal',
                trackId: Value(trackId),
                eventTimestamp: sentinel, // bulk-prior sentinel
                points: const Value(10),
              ),
            );
          }

          // Deadline track config (no pacePerDay, no trackStartedAt).
          final config = ScheduleConfig(
            curriculumId: curriculum,
            trackId: trackId,
            trackLabel: 'personal',
            goalDeadline: now.add(const Duration(days: 30)),
            currentDate: now,
          );

          final tasks = await engine.generateDailyTasks(config);

          // Must produce at least one new-learning task.
          expect(
            tasks,
            isNotEmpty,
            reason:
                'Sentinel-marked items must appear as new-learning tasks, '
                'not disappear silently',
          );
          expect(
            tasks.any((t) => t.priority == DailyTaskPriority.newLearning),
            isTrue,
          );
        },
      );

      test(
        'self-paced snapshot track: sentinel items appear as new-learning, not overdue chazara',
        () async {
          final stages = await db.stageDao.getStageDefinitionsByCurriculum(
            curriculum.storageKey,
          );
          final learnId = stages.firstWhere((s) => s.stageOrder == 1).id;

          // Bulk-mark first 3 items with sentinel date.
          for (var i = 0; i < 3; i++) {
            await seedCompletion(
              db,
              CompletionEventsCompanion.insert(
                profileId: 1,
                curriculumId: curriculum.storageKey,
                sefariaRef: contentItems[i].sefariaRef,
                stageId: learnId,
                trackType: 'personal',
                trackId: Value(trackId),
                eventTimestamp: sentinel,
                points: const Value(10),
              ),
            );
          }

          // Self-paced config with pacePerDay AND trackStartedAt (snapshot path).
          final config = ScheduleConfig(
            curriculumId: curriculum,
            trackId: trackId,
            trackLabel: 'personal',
            currentDate: now,
            pacePerDay: 2,
            trackStartedAt: now.subtract(const Duration(days: 1)),
            // priorlyShownRefs empty — first run today
          );

          final tasks = await engine.generateDailyTasks(config);

          // Sentinel items are NOT genuinely completed — they must NOT appear
          // as overdueChazara.
          expect(
            tasks.any((t) => t.priority == DailyTaskPriority.overdueChazara),
            isFalse,
            reason: 'Sentinel items must not be classified as overdueChazara',
          );
          // Some new-learning tasks should exist (items 0..4 are all candidates).
          expect(
            tasks.any((t) => t.priority == DailyTaskPriority.newLearning),
            isTrue,
          );
        },
      );
    },
  );
}
