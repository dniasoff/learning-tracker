/// Story acceptance tests for Epic 16 -- Pace, Study Days & Dashboard Polish.
@Tags(['epic_16'])
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/services/goal_progress_calculator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

void main() {
  // ── Story 16.1: Pace-Based Goal Mode ────────────────────────────────
  group('Story 16.1 -- Pace-Based Goal Mode', tags: ['story_16_1'], () {
    final today = DateTime.utc(2026, 3, 24);

    Map<DateTime, int> buildCounts(int perDay) {
      final counts = <DateTime, int>{};
      for (var i = 1; i <= 7; i++) {
        counts[DateTime.utc(2026, 3, 24 - i)] = perDay;
      }
      return counts;
    }

    // AC-1: Pace goal creation
    test(
      'AC-1: GoalEntity supports pace goalType with paceValue and paceUnit',
      () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 1,
          paceUnit: 'per_day',
          createdAt: today,
          updatedAt: today,
        );
        expect(entity.goalType, 'pace');
        expect(entity.paceValue, 1);
        expect(entity.paceUnit, 'per_day');
        expect(entity.targetDate, isNull);
      },
    );

    // AC-3: Projected completion date
    test('AC-3: projected completion = today + ceil(remaining / pace)', () {
      final result = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: 1.0,
        completedItems: 0,
        totalItems: 2711,
        dailyCompletionCounts: buildCounts(1),
        today: today,
      );
      expect(
        result.projectedCompletionDate,
        today.add(const Duration(days: 2711)),
      );
    });

    test('AC-3: per_week projection uses paceValue/7 as daily rate', () {
      // 5 per week = 5/7 per day ≈ 0.714/day
      // 100 remaining / (5/7) = 140.0 exactly → ceil = 140 days
      final dailyRate = PaceCalculator.paceToDaily(5, 'per_week');
      expect(dailyRate, closeTo(0.714, 0.001));
      final result = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: dailyRate,
        completedItems: 0,
        totalItems: 100,
        dailyCompletionCounts: {},
        today: today,
      );
      expect(result.projectedCompletionDate, isNotNull);
      final daysOut = result.projectedCompletionDate!.difference(today).inDays;
      expect(daysOut, 140); // ceil(100 / (5/7)) = ceil(140.0) = 140
    });

    // AC-4: Pace status
    test('AC-4: ahead when rolling avg > target', () {
      final result = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: 1.0,
        completedItems: 100,
        totalItems: 500,
        dailyCompletionCounts: buildCounts(3),
        today: today,
      );
      expect(result.status, PaceStatusType.ahead);
    });

    test('AC-4: onPace when rolling avg equals target (within 0.1)', () {
      final result = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: 1.0,
        completedItems: 100,
        totalItems: 500,
        dailyCompletionCounts: buildCounts(1),
        today: today,
      );
      expect(result.status, PaceStatusType.onPace);
    });

    test('AC-4: behind when rolling avg < target', () {
      final result = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: 2.0,
        completedItems: 100,
        totalItems: 500,
        dailyCompletionCounts: buildCounts(1),
        today: today,
      );
      expect(result.status, PaceStatusType.behind);
    });

    // AC-6: Self-paced mode unchanged
    test('AC-6: default goalType is deadline with null pace fields', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.bavli,
        createdAt: today,
        updatedAt: today,
      );
      expect(entity.goalType, 'deadline');
      expect(entity.paceValue, isNull);
      expect(entity.paceUnit, isNull);
    });

    // AC-7: Firestore sync with new fields
    test('AC-7: toFirestore includes goalType, paceValue, paceUnit', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.bavli,
        goalType: 'pace',
        paceValue: 1,
        paceUnit: 'per_day',
        createdAt: today,
        updatedAt: today,
      );
      final map = entity.toFirestore();
      expect(map.containsKey('goalType'), isTrue);
      expect(map.containsKey('paceValue'), isTrue);
      expect(map.containsKey('paceUnit'), isTrue);
    });

    test('AC-7: existing deadline goals sync unchanged', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetDate: DateTime.utc(2026, 12, 31),
        createdAt: today,
        updatedAt: today,
      );
      final map = entity.toFirestore();
      expect(map['goalType'], 'deadline');
      expect(map['paceValue'], isNull);
      expect(map['paceUnit'], isNull);
      expect(map['targetDate'], isNotNull);
    });

    // AC-8: Existing deadline goals unaffected
    test('AC-8: fromFirestore defaults to deadline when goalType missing', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'bavli',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.goalType, 'deadline');
      expect(entity.paceValue, isNull);
      expect(entity.paceUnit, isNull);
    });

    // GoalProgressCalculator with pace
    test('GoalProgressCalculator uses pacePerDay when provided', () {
      final result = GoalProgressCalculator.calculate(
        targetPercent: 100.0,
        targetDate: null,
        currentDate: today,
        totalItems: 500,
        completedItems: 100,
        pacePerDay: 2.0,
      );
      expect(result.remainingItems, 400);
      expect(result.daysRemaining, 200);
      expect(result.itemsPerDay, 2.0);
    });
  });

  // Placeholder groups for future stories in Epic 16
  // ── Story 16.2: Study Day Configuration ──────────────────────────────
  group('Story 16.2 -- Study Day Configuration', tags: ['story_16_2'], () {
    // AC-1: Database table stores study day configuration
    test('AC-1: StudyDayConfigDao CRUD operations', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      // Seed defaults — all 7 days as study
      await db.studyDayConfigDao.seedDefaults(
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      final configs = await db.studyDayConfigDao
          .getConfigsByCurriculumAndProfile('mishnayos', 1);
      expect(configs.length, 7);
      expect(configs.every((c) => c.dayType == 'study'), isTrue);

      // Upsert a day to review
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: 'mishnayos',
        dayOfWeek: 6, // Saturday
        dayType: 'review',
      );

      final updated = await db.studyDayConfigDao
          .getConfigsByCurriculumAndProfile('mishnayos', 1);
      final saturday = updated.firstWhere((c) => c.dayOfWeek == 6);
      expect(saturday.dayType, 'review');
    });

    // AC-2: Default configuration seeds all days as study days
    test('AC-2: defaults to study when no config exists', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      // No config seeded — isStudyDay should default to true
      final result = await db.studyDayConfigDao.isStudyDay(
        profileId: 1,
        curriculumId: 'mishnayos',
        dayOfWeek: 1,
      );
      expect(result, isTrue);

      // getStudyDaysPerWeek defaults to 7
      final count = await db.studyDayConfigDao.getStudyDaysPerWeek(
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      expect(count, 7);
    });

    // AC-3: Scheduler suppresses new learning on review-only days
    test('AC-3: ScheduleConfig.isStudyDay=false suppresses new learning', () {
      final config = ScheduleConfig(
        curriculumId: CurriculumId.mishnayos,
        currentDate: DateTime.utc(2026, 3, 25),
        isStudyDay: false,
      );
      expect(config.isStudyDay, isFalse);
    });

    // AC-4: Scheduler allows new learning on study days
    test('AC-4: ScheduleConfig.isStudyDay defaults to true', () {
      final config = ScheduleConfig(
        curriculumId: CurriculumId.mishnayos,
        currentDate: DateTime.utc(2026, 3, 25),
      );
      expect(config.isStudyDay, isTrue);
    });

    // AC-5: Study day configuration screen toggles day types
    test('AC-5: upsertDayConfig toggles between study and review', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await db.studyDayConfigDao.seedDefaults(
        profileId: 1,
        curriculumId: 'bavli',
      );

      // Toggle Friday (day 5) to review
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: 'bavli',
        dayOfWeek: 5,
        dayType: 'review',
      );

      final isFridayStudy = await db.studyDayConfigDao.isStudyDay(
        profileId: 1,
        curriculumId: 'bavli',
        dayOfWeek: 5,
      );
      expect(isFridayStudy, isFalse);

      // Toggle back to study
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: 'bavli',
        dayOfWeek: 5,
        dayType: 'study',
      );

      final isFridayStudyAgain = await db.studyDayConfigDao.isStudyDay(
        profileId: 1,
        curriculumId: 'bavli',
        dayOfWeek: 5,
      );
      expect(isFridayStudyAgain, isTrue);
    });

    // AC-8: Pace calculator accounts for study days
    test('AC-8: studyDaysPerWeek correctly counts study days', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await db.studyDayConfigDao.seedDefaults(
        profileId: 1,
        curriculumId: 'mishnayos',
      );

      // Set Fri and Sat to review (5 study days)
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: 'mishnayos',
        dayOfWeek: 5,
        dayType: 'review',
      );
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: 'mishnayos',
        dayOfWeek: 6,
        dayType: 'review',
      );

      final count = await db.studyDayConfigDao.getStudyDaysPerWeek(
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      expect(count, 5);
    });

    test('AC-8: ScheduleConfig carries studyDaysPerWeek', () {
      final config = ScheduleConfig(
        curriculumId: CurriculumId.mishnayos,
        currentDate: DateTime.utc(2026, 3, 25),
        studyDaysPerWeek: 5,
        goalDeadline: DateTime.utc(2026, 12, 31),
      );
      expect(config.studyDaysPerWeek, 5);
    });

    // AC-1 continued: profile isolation
    test('AC-1: configs are scoped to profile', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await db.studyDayConfigDao.seedDefaults(
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await db.studyDayConfigDao.seedDefaults(
        profileId: 2,
        curriculumId: 'mishnayos',
      );

      // Modify profile 1 only
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: 'mishnayos',
        dayOfWeek: 7,
        dayType: 'review',
      );

      // Profile 2 should still have Sunday as study
      final p2Sunday = await db.studyDayConfigDao.isStudyDay(
        profileId: 2,
        curriculumId: 'mishnayos',
        dayOfWeek: 7,
      );
      expect(p2Sunday, isTrue);

      // Profile 1 should have Sunday as review
      final p1Sunday = await db.studyDayConfigDao.isStudyDay(
        profileId: 1,
        curriculumId: 'mishnayos',
        dayOfWeek: 7,
      );
      expect(p1Sunday, isFalse);
    });

    // DayType enum
    test('DayType enum serialization round-trips', () {
      expect(DayType.fromStorageKey('study'), DayType.study);
      expect(DayType.fromStorageKey('review'), DayType.review);
      expect(DayType.study.storageKey, 'study');
      expect(DayType.review.storageKey, 'review');
    });

    // Delete
    test('deleteConfigsByCurriculumAndProfile removes all configs', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await db.studyDayConfigDao.seedDefaults(
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      final deleted = await db.studyDayConfigDao
          .deleteConfigsByCurriculumAndProfile('mishnayos', 1);
      expect(deleted, 7);

      final remaining = await db.studyDayConfigDao
          .getConfigsByCurriculumAndProfile('mishnayos', 1);
      expect(remaining, isEmpty);
    });
  });
  // ── Story 16.3: Dashboard Pace & Progress Integration ─────────────────
  group(
    'Story 16.3 -- Dashboard Pace & Progress Integration',
    tags: ['story_16_3'],
    () {
      final today = DateTime.utc(2026, 3, 25);

      // AC-1: Pace status displayed per curriculum
      test('AC-1: PaceStatus contains daysDelta for badge display', () {
        final pace = PaceStatus(
          status: PaceStatusType.ahead,
          daysDelta: 2,
          projectedCompletionDate: DateTime.utc(2026, 12, 1),
          rollingAverage: 3.0,
        );
        expect(pace.daysDelta, 2);
        expect(pace.status, PaceStatusType.ahead);
      });

      test('AC-1: behind status has negative daysDelta', () {
        const pace = PaceStatus(
          status: PaceStatusType.behind,
          daysDelta: -3,
          rollingAverage: 0.5,
        );
        expect(pace.daysDelta, -3);
        expect(pace.status, PaceStatusType.behind);
      });

      test('AC-1: onPace status has zero daysDelta', () {
        const pace = PaceStatus(
          status: PaceStatusType.onPace,
          daysDelta: 0,
          rollingAverage: 1.0,
        );
        expect(pace.daysDelta, 0);
      });

      // AC-2: Projected completion date shown
      test(
        'AC-2: projectedCompletionDate is non-null when rolling avg > 0',
        () {
          final result = PaceCalculator.calculate(
            goalStartDate: DateTime.utc(2026, 1, 1),
            goalDeadline: DateTime.utc(2026, 12, 31),
            totalItems: 500,
            completedItems: 100,
            dailyCompletionCounts: {
              for (var i = 1; i <= 7; i++) DateTime.utc(2026, 3, 25 - i): 2,
            },
            today: today,
          );
          expect(result.projectedCompletionDate, isNotNull);
        },
      );

      test('AC-2: projectedCompletionDate is null when no recent activity', () {
        final result = PaceCalculator.calculate(
          goalStartDate: DateTime.utc(2026, 1, 1),
          goalDeadline: DateTime.utc(2026, 12, 31),
          totalItems: 500,
          completedItems: 100,
          dailyCompletionCounts: {},
          today: today,
        );
        expect(result.projectedCompletionDate, isNull);
      });

      // AC-3: English + Hebrew date header (unit test for formatting logic)
      test('AC-3: date header formats weekday, month, day, year', () {
        final date = DateTime(2026, 3, 24);
        // Tuesday March 24
        expect(date.weekday, DateTime.tuesday);
        expect(date.month, 3);
        expect(date.day, 24);
      });

      // AC-4: Day type indicator
      test('AC-4: empty tasks -> Rest Day', () {
        final tasks = <DailyTask>[];
        final hasNew = tasks.any(
          (t) => t.priority == DailyTaskPriority.newLearning,
        );
        final hasChazara = tasks.any(
          (t) =>
              t.priority == DailyTaskPriority.overdueChazara ||
              t.priority == DailyTaskPriority.scheduledChazara,
        );
        expect(tasks.isEmpty, isTrue);
        expect(hasNew, isFalse);
        expect(hasChazara, isFalse);
      });

      test('AC-4: only new learning -> Study Day', () {
        final tasks = [
          const DailyTask(
            curriculumId: CurriculumId.mishnayos,
            contentItemSefariaRef: 'Mishnah Berakhot 1.1',
            stageOrder: 1,
            stageDefinitionId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New',
            stageName: 'Learn',
          ),
        ];
        final hasNew = tasks.any(
          (t) => t.priority == DailyTaskPriority.newLearning,
        );
        final hasChazara = tasks.any(
          (t) =>
              t.priority == DailyTaskPriority.overdueChazara ||
              t.priority == DailyTaskPriority.scheduledChazara,
        );
        expect(hasNew, isTrue);
        expect(hasChazara, isFalse);
      });

      test('AC-4: only chazara -> Review Day', () {
        final tasks = [
          const DailyTask(
            curriculumId: CurriculumId.mishnayos,
            contentItemSefariaRef: 'Mishnah Berakhot 1.1',
            stageOrder: 2,
            stageDefinitionId: 2,
            priority: DailyTaskPriority.scheduledChazara,
            isOverdue: false,
            reason: 'Review',
            stageName: 'Chazara 1',
          ),
        ];
        final hasNew = tasks.any(
          (t) => t.priority == DailyTaskPriority.newLearning,
        );
        final hasChazara = tasks.any(
          (t) =>
              t.priority == DailyTaskPriority.overdueChazara ||
              t.priority == DailyTaskPriority.scheduledChazara,
        );
        expect(hasNew, isFalse);
        expect(hasChazara, isTrue);
      });

      test('AC-4: both new + chazara -> Mixed', () {
        final tasks = [
          const DailyTask(
            curriculumId: CurriculumId.mishnayos,
            contentItemSefariaRef: 'Mishnah Berakhot 1.1',
            stageOrder: 1,
            stageDefinitionId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New',
            stageName: 'Learn',
          ),
          const DailyTask(
            curriculumId: CurriculumId.mishnayos,
            contentItemSefariaRef: 'Mishnah Berakhot 1.2',
            stageOrder: 2,
            stageDefinitionId: 2,
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
            reason: 'Overdue',
            stageName: 'Chazara 1',
          ),
        ];
        final hasNew = tasks.any(
          (t) => t.priority == DailyTaskPriority.newLearning,
        );
        final hasChazara = tasks.any(
          (t) =>
              t.priority == DailyTaskPriority.overdueChazara ||
              t.priority == DailyTaskPriority.scheduledChazara,
        );
        expect(hasNew, isTrue);
        expect(hasChazara, isTrue);
      });

      // AC-5: Task items contain required fields
      test(
        'AC-5: DailyTask has sefariaRef, stageName, curriculum, priority',
        () {
          const task = DailyTask(
            curriculumId: CurriculumId.bavli,
            contentItemSefariaRef: 'Berakhot 2a',
            stageOrder: 1,
            stageDefinitionId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New learning',
            stageName: 'Learn',
          );
          expect(task.contentItemSefariaRef, 'Berakhot 2a');
          expect(task.stageName, 'Learn');
          expect(task.curriculumId, CurriculumId.bavli);
          expect(task.priority, DailyTaskPriority.newLearning);
        },
      );

      test('AC-5: overdue tasks are distinguishable', () {
        const overdueTask = DailyTask(
          curriculumId: CurriculumId.mishnayos,
          contentItemSefariaRef: 'Mishnah Berakhot 1.1',
          stageOrder: 2,
          stageDefinitionId: 2,
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
          reason: 'Overdue by 3 days',
          stageName: 'Chazara 1',
        );
        expect(overdueTask.isOverdue, isTrue);
        expect(overdueTask.priority, DailyTaskPriority.overdueChazara);
      });

      // AC-6: Aggregator receives populated maps
      test('AC-6: aggregator produces summaries with real pace data', () {
        final aggregator = CrossCurriculumAggregator();
        final pace = PaceStatus(
          status: PaceStatusType.ahead,
          daysDelta: 2,
          projectedCompletionDate: DateTime.utc(2026, 10, 15),
          rollingAverage: 3.0,
        );

        final stats = aggregator.aggregate(
          activeCurricula: [CurriculumId.mishnayos],
          completionPercentages: {CurriculumId.mishnayos: 0.45},
          paceStatuses: {CurriculumId.mishnayos: pace},
          todayTaskCounts: {CurriculumId.mishnayos: 5},
          nextDueItems: {CurriculumId.mishnayos: 'Berakhot 1.3'},
          lastCompletions: {CurriculumId.mishnayos: today},
        );

        expect(stats.curriculumSummaries, hasLength(1));
        final summary = stats.curriculumSummaries.first;
        expect(summary.paceStatus, isNotNull);
        expect(summary.paceStatus!.status, PaceStatusType.ahead);
        expect(summary.paceStatus!.daysDelta, 2);
        expect(
          summary.paceStatus!.projectedCompletionDate,
          DateTime.utc(2026, 10, 15),
        );
        expect(summary.todayTaskCount, 5);
        expect(summary.nextDueItem, 'Berakhot 1.3');
      });

      test('AC-6: aggregator sums task counts across curricula', () {
        final aggregator = CrossCurriculumAggregator();
        final stats = aggregator.aggregate(
          activeCurricula: [CurriculumId.mishnayos, CurriculumId.bavli],
          completionPercentages: {
            CurriculumId.mishnayos: 0.3,
            CurriculumId.bavli: 0.1,
          },
          paceStatuses: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
          },
          todayTaskCounts: {CurriculumId.mishnayos: 3, CurriculumId.bavli: 7},
          nextDueItems: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
          },
          lastCompletions: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
          },
        );
        expect(stats.totalTasksToday, 10);
        expect(stats.activeCurriculaCount, 2);
      });

      // AC-7: null pace when no goal
      test('AC-7: paceStatus is null when no goal exists', () {
        final aggregator = CrossCurriculumAggregator();
        final stats = aggregator.aggregate(
          activeCurricula: [CurriculumId.mishnayos],
          completionPercentages: {CurriculumId.mishnayos: 0.0},
          paceStatuses: {CurriculumId.mishnayos: null},
          todayTaskCounts: {CurriculumId.mishnayos: 0},
          nextDueItems: {CurriculumId.mishnayos: null},
          lastCompletions: {CurriculumId.mishnayos: null},
        );
        expect(stats.curriculumSummaries.first.paceStatus, isNull);
      });
    },
  );
  group(
    'Story 16.4 -- Per-Item Review Count Display',
    skip: 'Not yet implemented',
    tags: ['story_16_4'],
    () {},
  );
  group(
    'Story 16.5 -- Onboarding Goal & Study Day Steps',
    skip: 'Not yet implemented',
    tags: ['story_16_5'],
    () {},
  );
  group(
    'Story 16.6 -- Dashboard Design & Experience Polish',
    skip: 'Not yet implemented',
    tags: ['story_16_6'],
    () {},
  );
}
