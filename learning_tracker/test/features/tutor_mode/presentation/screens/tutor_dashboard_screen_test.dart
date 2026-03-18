import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutor_mode/domain/services/tutor_dashboard_aggregator.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/providers/tutor_dashboard_providers.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_dashboard_screen.dart';

void main() {
  group('TutorDashboardScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorDashboardDataProvider.overrideWith(
              (ref) => Future.value(
                const TutorDashboardData(
                  activeCurricula: [],
                  completionHistory: [],
                  chazaraQueue: [],
                  paceInfo: {},
                  dailyTasks: [],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: TutorDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
