import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_screen.dart';

void main() {
  group('ProgressScreen', () {
    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          dashboardActiveCurriculaProvider.overrideWith(
            (ref) => Future.value([]),
          ),
          dashboardActiveCurriculaStreamProvider.overrideWith(
            (ref) => Stream.value(<CurriculumId>[]),
          ),
          dashboardUserModeProvider.overrideWith(
            (ref) => Future.value(UserMode.adult),
          ),
          dashboardStreakProvider.overrideWith(
            (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
          ),
          dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(0)),
        ],
        child: const MaterialApp(home: ProgressScreen()),
      );
    }

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows key UI elements', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Progress'), findsOneWidget);
      // With no active curricula, the empty state is shown
      expect(find.text('No progress yet'), findsOneWidget);
    });
  });
}
