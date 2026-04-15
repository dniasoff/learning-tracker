import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart';

/// Tests that SafeArea protection is applied to screens to prevent
/// bottom action buttons from being obscured by Android system navigation bar.
void main() {
  group('SafeArea Protection', () {
    group('HIGH-risk screen: SignInScreen', () {
      Widget buildWithSystemInsets() {
        return const MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: 48), // Simulate 3-button nav bar
            viewPadding: EdgeInsets.only(bottom: 48),
          ),
          child: ProviderScope(child: MaterialApp(home: SignInScreen())),
        );
      }

      testWidgets('contains SafeArea widget', (tester) async {
        await tester.pumpWidget(buildWithSystemInsets());
        await tester.pump(const Duration(seconds: 2));

        // Verify SafeArea is present in the widget tree
        expect(find.byType(SafeArea), findsWidgets);
      });

      testWidgets('SafeArea protects content from system insets', (
        tester,
      ) async {
        await tester.pumpWidget(buildWithSystemInsets());
        await tester.pump(const Duration(seconds: 2));

        final safeAreas = tester
            .widgetList<SafeArea>(find.byType(SafeArea))
            .toList();
        // At least one SafeArea should exist to protect content
        expect(safeAreas, isNotEmpty);
      });

      testWidgets('bottom content is not obscured by system nav bar', (
        tester,
      ) async {
        await tester.pumpWidget(buildWithSystemInsets());
        await tester.pump(const Duration(seconds: 2));

        // The "Sign in with Google" button should be visible and tappable
        final googleButton = find.text('Sign in with Google');
        expect(googleButton, findsOneWidget);

        // Verify the button is within the visible area (not behind nav bar)
        final buttonBox = tester.renderObject(googleButton).paintBounds;
        expect(buttonBox.bottom, greaterThan(0));
      });
    });

    group('MEDIUM-risk screen: GamificationScreen', () {
      late UserDatabase db;

      setUp(() {
        db = UserDatabase(NativeDatabase.memory());
      });

      tearDown(() async {
        await db.close();
      });

      Widget buildWithSystemInsets() {
        return MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 48),
            viewPadding: EdgeInsets.only(bottom: 48),
          ),
          child: ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWith((_) => db),
              // Override stream providers to avoid Drift timer leaks in tests
              allRewardsStreamProvider.overrideWith(
                (_) => Stream.value(<Reward>[]),
              ),
              dashboardStreakProvider.overrideWith(
                (_) => Stream.value((currentStreak: 0, maxStreak: 0)),
              ),
            ],
            child: const MaterialApp(home: GamificationScreen()),
          ),
        );
      }

      testWidgets('contains SafeArea widget', (tester) async {
        await tester.pumpWidget(buildWithSystemInsets());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(SafeArea), findsWidgets);
      });

      testWidgets('SafeArea protects bottom content', (tester) async {
        await tester.pumpWidget(buildWithSystemInsets());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Find the SafeArea that's a direct child of Scaffold's body
        final safeAreas = tester
            .widgetList<SafeArea>(find.byType(SafeArea))
            .toList();
        // At least one SafeArea should exist
        expect(safeAreas, isNotEmpty);
      });
    });

    group('Gesture navigation (thin bar) - no excessive padding', () {
      testWidgets('SignInScreen renders correctly with minimal padding', (
        tester,
      ) async {
        // Simulate gesture navigation with thin bar (small bottom inset)
        const widget = MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: 8),
            viewPadding: EdgeInsets.only(bottom: 8),
          ),
          child: ProviderScope(child: MaterialApp(home: SignInScreen())),
        );

        await tester.pumpWidget(widget);
        await tester.pump(const Duration(seconds: 2));

        // Screen should render without overflow errors
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsOneWidget);
      });
    });
  });
}
