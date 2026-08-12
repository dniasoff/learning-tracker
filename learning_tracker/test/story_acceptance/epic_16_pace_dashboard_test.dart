/// Story acceptance coverage for Epic 16 — pace dashboard.
@Tags(['epic_16'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/review_count_badge.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';

void main() {
  group('Story 16.1 — pace-based goals', () {
    test('goal Firestore shape carries pace fields', () {
      final goal = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
        description: 'Finish',
        dateType: 'gregorian',
        goalType: 'pace',
        paceValue: 5,
        pacePeriod: 'per_day',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(goal.toFirestore(), containsPair('goal_type', 'pace'));
      expect(goal.toFirestore(), containsPair('pace_value', 5));
      expect(goal.toFirestore(), containsPair('pace_unit', 'per_day'));
    });

    test('PaceCalculator projects completion from the target pace', () {
      final today = DateTime.utc(2026, 8, 12);
      final status = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: 5,
        totalItems: 100,
        completedItems: 40,
        dailyCompletionCounts: const {},
        today: today,
      );
      expect(status.projectedCompletionDate, DateTime.utc(2026, 8, 24));
      expect(status.status, PaceStatusType.behind);
    });

    test('weekly pace values convert to a daily rate', () {
      expect(PaceCalculator.paceToDaily(14, 'per_week'), closeTo(2, 0.001));
      expect(PaceCalculator.paceToDaily(2, 'per_day'), 2);
    });
  });

  group('Story 16.3 — dashboard pace and aggregation', () {
    test('PaceStatus carries typed delta and status', () {
      const status = PaceStatus(
        status: PaceStatusType.ahead,
        daysDelta: 2,
        delta: DateScheduleDelta(DateDelta(2)),
        projectedCompletionDate: null,
        rollingAverage: 3,
      );
      expect(status.status, PaceStatusType.ahead);
      expect(status.delta, isA<DateScheduleDelta>());
      expect(status.daysDelta, 2);
    });

    test('aggregator preserves summaries and sums task counts', () {
      final pace = PaceStatus(
        status: PaceStatusType.onPace,
        daysDelta: 0,
        delta: const DateScheduleDelta(DateDelta(0)),
        projectedCompletionDate: DateTime.utc(2026, 10, 1),
        rollingAverage: 2,
      );
      final stats = CrossCurriculumAggregator().aggregate(
        activeCurricula: const [CurriculumId.mishnayos, CurriculumId.bavli],
        completionPercentages: const {
          CurriculumId.mishnayos: 0.4,
          CurriculumId.bavli: 0.2,
        },
        paceStatuses: {
          CurriculumId.mishnayos: pace,
          CurriculumId.bavli: null,
        },
        todayTaskCounts: const {
          CurriculumId.mishnayos: 3,
          CurriculumId.bavli: 7,
        },
        nextDueItems: const {
          CurriculumId.mishnayos: 'Berakhot 1.3',
          CurriculumId.bavli: null,
        },
        lastCompletions: {
          CurriculumId.mishnayos: DateTime.utc(2026, 8, 10),
          CurriculumId.bavli: null,
        },
      );
      expect(stats.curriculumSummaries, hasLength(2));
      expect(stats.curriculumSummaries.first.paceStatus, same(pace));
      expect(stats.totalTasksToday, 10);
      expect(stats.activeCurriculaCount, 2);
    });

    test('DailyTask exposes the fields needed by dashboard actions', () {
      const task = DailyTask(
        curriculumId: CurriculumId.mishnayos,
        contentItemSefariaRef: 'Berakhot.1.1',
        stageOrder: 1,
        stageDefinitionId: 1,
        priority: DailyTaskPriority.newLearning,
        isOverdue: false,
        reason: 'New',
        stageName: 'Learn',
        trackLabel: 'Mishnayos',
      );
      expect(task.curriculumId, CurriculumId.mishnayos);
      expect(task.contentItemSefariaRef, 'Berakhot.1.1');
      expect(task.priority, DailyTaskPriority.newLearning);
      expect(task.isOverdue, isFalse);
    });
  });

  group('Story 16.4 — per-item review count display', () {
    testWidgets('zero review count renders no badge text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ReviewCountBadge(count: 0))),
      );
      expect(find.text('0x'), findsNothing);
    });

    testWidgets('positive review count renders the Nx badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ReviewCountBadge(count: 11))),
      );
      expect(find.text('11x'), findsOneWidget);
    });
  });

  group('Story 16.6 — dashboard visual polish', () {
    testWidgets('AnimatedProgressBar applies value, color, and duration', (
      tester,
    ) async {
      const color = Color(0xFF123456);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: AnimatedProgressBar(
                value: 0.5,
                color: color,
                duration: Duration(milliseconds: 10),
              ),
            ),
          ),
        ),
      );
      final widget = tester.widget<AnimatedProgressBar>(
        find.byType(AnimatedProgressBar),
      );
      expect(widget.color, color);
      expect(widget.duration, const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor,
        closeTo(0.5, 0.01),
      );
    });
  });

  group('Story 16 — remaining Drift-only integration', skip:
      'The remaining CRUD and provider-integration cases directly exercise Drift DAOs; no equivalent Firestore-native acceptance seam exists yet.', () {
    test('placeholder for the pending Firestore integration seam', () {});
  });
}
