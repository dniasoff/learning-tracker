import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/services/goal_progress_calculator.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/goal_progress_card.dart';

void main() {
  group('GoalProgressCard', () {
    testWidgets(
      'displays "X% complete, Y days remaining, Z items/day needed"',
      (tester) async {
        const progress = GoalProgress(
          percentComplete: 0.239,
          daysRemaining: 292,
          itemsPerDay: 14.32,
          totalItems: 4192,
          completedItems: 10,
          remainingItems: 4182,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GoalProgressCard(
                progress: progress,
                description: 'Complete Mishnayos',
              ),
            ),
          ),
        );

        expect(find.text('Complete Mishnayos'), findsOneWidget);
        expect(find.textContaining('0.2% complete'), findsOneWidget);
        expect(find.textContaining('292 days remaining'), findsOneWidget);
        expect(find.textContaining('14.3 items/day needed'), findsOneWidget);
      },
    );

    testWidgets('shows edit/delete actions when callbacks provided', (
      tester,
    ) async {
      var editTapped = false;
      var deleteTapped = false;

      const progress = GoalProgress(
        percentComplete: 50.0,
        totalItems: 100,
        completedItems: 50,
        remainingItems: 50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalProgressCard(
              progress: progress,
              onEdit: () => editTapped = true,
              onDelete: () => deleteTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.edit));
      expect(editTapped, isTrue);

      await tester.tap(find.byIcon(Icons.delete));
      expect(deleteTapped, isTrue);
    });

    testWidgets('no-deadline mode omits days remaining and items/day', (
      tester,
    ) async {
      const progress = GoalProgress(
        percentComplete: 50.0,
        totalItems: 100,
        completedItems: 50,
        remainingItems: 50,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GoalProgressCard(progress: progress)),
        ),
      );

      expect(find.textContaining('50.0% complete'), findsOneWidget);
      expect(find.textContaining('days remaining'), findsNothing);
      expect(find.textContaining('items/day'), findsNothing);
    });
  });
}
