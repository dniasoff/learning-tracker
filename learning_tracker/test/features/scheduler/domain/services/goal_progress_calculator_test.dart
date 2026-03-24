import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/services/goal_progress_calculator.dart';

void main() {
  group('GoalProgressCalculator', () {
    group('clearTargetDate / no-deadline mode', () {
      test(
        'returns null daysRemaining and itemsPerDay when targetDate is null',
        () {
          final progress = GoalProgressCalculator.calculate(
            targetPercent: 100.0,
            targetDate: null,
            currentDate: DateTime.utc(2026, 3, 15),
            totalItems: 100,
            completedItems: 25,
          );

          expect(progress.daysRemaining, isNull);
          expect(progress.itemsPerDay, isNull);
          expect(progress.percentComplete, 25.0);
          expect(progress.remainingItems, 75);
          expect(progress.totalItems, 100);
          expect(progress.completedItems, 25);
        },
      );

      test(
        'switching from deadline to no-deadline changes pace fields to null',
        () {
          final withDeadline = GoalProgressCalculator.calculate(
            targetPercent: 100.0,
            targetDate: DateTime.utc(2026, 6, 15),
            currentDate: DateTime.utc(2026, 3, 15),
            totalItems: 100,
            completedItems: 25,
          );

          expect(withDeadline.daysRemaining, isNotNull);
          expect(withDeadline.itemsPerDay, isNotNull);

          // Simulate clearing the target date (no-deadline mode)
          final withoutDeadline = GoalProgressCalculator.calculate(
            targetPercent: 100.0,
            targetDate: null,
            currentDate: DateTime.utc(2026, 3, 15),
            totalItems: 100,
            completedItems: 25,
          );

          expect(withoutDeadline.daysRemaining, isNull);
          expect(withoutDeadline.itemsPerDay, isNull);
          // Progress stats remain unchanged
          expect(withoutDeadline.percentComplete, withDeadline.percentComplete);
          expect(withoutDeadline.remainingItems, withDeadline.remainingItems);
        },
      );
    });

    group('pace-based goal mode', () {
      test('pace mode calculates daysRemaining from pace', () {
        final result = GoalProgressCalculator.calculate(
          targetPercent: 100.0,
          targetDate: null,
          currentDate: DateTime.utc(2026, 3, 24),
          totalItems: 500,
          completedItems: 100,
          pacePerDay: 2.0,
        );
        expect(result.remainingItems, 400);
        expect(result.daysRemaining, 200);
        expect(result.itemsPerDay, 2.0);
      });

      test('pace mode with all items completed returns 0 daysRemaining', () {
        final result = GoalProgressCalculator.calculate(
          targetPercent: 100.0,
          targetDate: null,
          currentDate: DateTime.utc(2026, 3, 24),
          totalItems: 500,
          completedItems: 500,
          pacePerDay: 2.0,
        );
        expect(result.remainingItems, 0);
        expect(result.daysRemaining, 0);
        expect(result.itemsPerDay, 2.0);
      });

      test('pace mode with partial target percent', () {
        final result = GoalProgressCalculator.calculate(
          targetPercent: 50.0,
          targetDate: null,
          currentDate: DateTime.utc(2026, 3, 24),
          totalItems: 500,
          completedItems: 100,
          pacePerDay: 1.0,
        );
        // target = 250 items, remaining = 150
        expect(result.remainingItems, 150);
        expect(result.daysRemaining, 150);
        expect(result.itemsPerDay, 1.0);
      });

      test('pace mode takes priority over targetDate when both provided', () {
        final result = GoalProgressCalculator.calculate(
          targetPercent: 100.0,
          targetDate: DateTime.utc(2026, 6, 24), // 92 days away
          currentDate: DateTime.utc(2026, 3, 24),
          totalItems: 500,
          completedItems: 100,
          pacePerDay: 2.0,
        );
        // pacePerDay should be used, not deadline
        expect(result.itemsPerDay, 2.0);
        expect(result.daysRemaining, 200); // 400/2, not 92
      });
    });
  });
}
