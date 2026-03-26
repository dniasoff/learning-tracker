import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((_) => db),
        // Override stream providers to avoid Drift timer leaks in tests
        allRewardsStreamProvider.overrideWith((_) => Stream.value(<Reward>[])),
        dashboardStreakProvider.overrideWith(
          (_) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
      child: const MaterialApp(home: GamificationScreen()),
    );
  }

  group('GamificationScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows key UI elements', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Achievements'), findsOneWidget);
    });
  });
}
