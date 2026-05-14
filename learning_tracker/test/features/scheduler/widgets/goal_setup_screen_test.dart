import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoalEntity _makeGoal() => GoalEntity(
  curriculumId: CurriculumId.mishnayos,
  targetPercent: 80.0,
  targetDate: DateTime.utc(2027, 1, 1),
  description: 'Test goal',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Widget _makeApp({required Widget home}) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GoalSetupScreen', () {
    testWidgets('renders form with target percentage slider and date picker', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      expect(find.text('New Goal'), findsOneWidget);
      expect(find.textContaining('100%'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Create Goal'), findsOneWidget);
    });

    testWidgets('goal type toggle shows Deadline and Pace options', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      expect(find.text('Deadline'), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
      expect(find.text('No deadline'), findsOneWidget);
    });

    testWidgets('slider changes target percentage', (tester) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      expect(find.textContaining('100%'), findsOneWidget);

      final slider = find.byType(Slider);
      final sliderCenter = tester.getCenter(slider);
      await tester.dragFrom(sliderCenter, const Offset(-100, 0));
      await tester.pump();

      expect(find.textContaining('100%'), findsNothing);
    });

    testWidgets('shows mode toggle with deadline and pace options', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      expect(find.text('Deadline'), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
    });

    testWidgets('switching to pace mode shows pace inputs', (tester) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      // Switch to pace mode
      await tester.tap(find.text('Pace'));
      await tester.pump();

      // Pace inputs visible
      expect(find.text('Per day'), findsOneWidget);
      expect(find.text('Per week'), findsOneWidget);
      // Projected completion card visible
      expect(find.textContaining('Projected completion'), findsOneWidget);
    });

    testWidgets('switching back to deadline mode hides pace inputs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      // Switch to pace, then back to deadline
      await tester.tap(find.text('Pace'));
      await tester.pump();
      await tester.tap(find.text('Deadline'));
      await tester.pump();

      // Pace inputs hidden
      expect(find.textContaining('Projected completion'), findsNothing);
    });

    testWidgets('pace mode shows curriculum-appropriate unit label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      await tester.tap(find.text('Pace'));
      await tester.pump();

      // Bavli deepest level is "Amud" — appears in input label and projection card
      expect(find.textContaining('Amud'), findsAtLeast(1));
    });

    testWidgets('edit mode shows Update Goal button', (tester) async {
      await tester.pumpWidget(
        _makeApp(
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
