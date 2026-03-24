/// Story acceptance tests for Epic 16 -- Pace, Study Days & Dashboard Polish.
@Tags(['epic_16'])
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/goal_progress_calculator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:test/test.dart';

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
    test('AC-1: GoalEntity supports pace goalType with paceValue and paceUnit', () {
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
    });

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
  group('Story 16.2 -- Study Day Configuration', skip: 'Not yet implemented', tags: ['story_16_2'], () {});
  group('Story 16.3 -- Dashboard Pace & Progress Integration', skip: 'Not yet implemented', tags: ['story_16_3'], () {});
  group('Story 16.4 -- Per-Item Review Count Display', skip: 'Not yet implemented', tags: ['story_16_4'], () {});
  group('Story 16.5 -- Onboarding Goal & Study Day Steps', skip: 'Not yet implemented', tags: ['story_16_5'], () {});
  group('Story 16.6 -- Dashboard Design & Experience Polish', skip: 'Not yet implemented', tags: ['story_16_6'], () {});
}
