import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';
import 'package:learning_tracker/features/parent_mode/presentation/providers/parent_dashboard_providers.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/parent_mode_screen.dart';

void main() {
  group('ParentModeScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parentDashboardDataProvider.overrideWith(
              (ref) => Future.value(
                const ParentDashboardData(
                  curricula: [],
                  globalPoints: 0,
                  currentStreak: 0,
                  maxStreak: 0,
                  recentCompletions: [],
                  engagement: EngagementMetrics(
                    daysActiveThisWeek: 0,
                    averageDailyCompletions: 0,
                  ),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: ParentModeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
