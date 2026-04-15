import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

void main() {
  group('DashboardScreen', () {
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
          allDailyTasksProvider.overrideWith((ref) => Future.value([])),
          dashboardStreakRecoveryProvider.overrideWith(
            (ref) => Future.value(
              const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      );
    }

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows Learning Tracker title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Learning Tracker'), findsOneWidget);
    });

    testWidgets('shows empty dashboard with no active curricula', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // With no active curricula, the streak widget should still render
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}
