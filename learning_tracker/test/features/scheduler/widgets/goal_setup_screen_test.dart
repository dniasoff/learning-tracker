import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';

GoalEntity _makeGoal() => GoalEntity(
  curriculumId: CurriculumId.mishnayos,
  targetPercent: 80.0,
  targetDate: DateTime.utc(2027, 1, 1),
  description: 'Test goal',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('GoalSetupScreen', () {
    testWidgets('renders form with target percentage slider and date picker', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      expect(find.text('New Goal'), findsOneWidget);
      expect(find.text('Target: 100%'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Use Hebrew date'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('No deadline (learn at your own pace)'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.text('Create Goal'), findsOneWidget);
    });

    testWidgets('Hebrew date toggle switches between Hebrew and Gregorian', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(find.text('Use Hebrew date'));
      await tester.pump();

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('slider changes target percentage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      expect(find.text('Target: 100%'), findsOneWidget);

      final slider = find.byType(Slider);
      final sliderCenter = tester.getCenter(slider);
      await tester.dragFrom(sliderCenter, const Offset(-100, 0));
      await tester.pump();

      expect(find.text('Target: 100%'), findsNothing);
    });

    testWidgets('shows mode toggle with deadline and pace options', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GoalSetupScreen(
              curriculumId: CurriculumId.bavli,
              totalItems: 2711,
            ),
          ),
        ),
      );

      expect(find.text('Set a deadline'), findsOneWidget);
      expect(find.text('Set a pace'), findsOneWidget);
    });

    testWidgets('switching to pace mode shows pace inputs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GoalSetupScreen(
              curriculumId: CurriculumId.bavli,
              totalItems: 2711,
            ),
          ),
        ),
      );

      // Default is deadline mode
      expect(find.text('Use Hebrew date'), findsOneWidget);

      // Switch to pace mode
      await tester.tap(find.text('Set a pace'));
      await tester.pump();

      // Pace inputs visible
      expect(find.text('Per day'), findsOneWidget);
      expect(find.text('Per week'), findsOneWidget);
      // Date picker hidden
      expect(find.text('Use Hebrew date'), findsNothing);
      // Projected completion card visible
      expect(find.textContaining('Projected completion'), findsOneWidget);
    });

    testWidgets('switching back to deadline mode hides pace inputs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GoalSetupScreen(
              curriculumId: CurriculumId.bavli,
              totalItems: 2711,
            ),
          ),
        ),
      );

      // Switch to pace, then back to deadline
      await tester.tap(find.text('Set a pace'));
      await tester.pump();
      await tester.tap(find.text('Set a deadline'));
      await tester.pump();

      // Deadline UI restored
      expect(find.text('Use Hebrew date'), findsOneWidget);
      // Pace inputs hidden
      expect(find.textContaining('Projected completion'), findsNothing);
    });

    testWidgets('pace mode shows curriculum-appropriate unit label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GoalSetupScreen(
              curriculumId: CurriculumId.bavli,
              totalItems: 2711,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Set a pace'));
      await tester.pump();

      // Bavli deepest level is "Amud" — appears in input label and projection card
      expect(find.textContaining('Amud'), findsAtLeast(1));
    });

    testWidgets('edit mode shows Update Goal button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GoalSetupScreen(
            curriculumId: CurriculumId.mishnayos,
            existingGoal: _makeGoal(),
          ),
        ),
      );

      expect(find.text('Edit Goal'), findsOneWidget);
      expect(find.text('Update Goal'), findsOneWidget);
    });
  });
}
