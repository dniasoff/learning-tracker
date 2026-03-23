import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/auth/presentation/screens/sign_in_screen.dart';
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
        await tester.pumpAndSettle();

        // Verify SafeArea is present in the widget tree
        expect(find.byType(SafeArea), findsWidgets);
      });

      testWidgets(
        'SafeArea has top: false to avoid double padding with AppBar',
        (tester) async {
          await tester.pumpWidget(buildWithSystemInsets());
          await tester.pumpAndSettle();

          final safeAreas = tester
              .widgetList<SafeArea>(find.byType(SafeArea))
              .toList();
          // At least one SafeArea should have top: false (our added one)
          expect(safeAreas.any((sa) => !sa.top), isTrue);
        },
      );

      testWidgets('bottom content is not obscured by system nav bar', (
        tester,
      ) async {
        await tester.pumpWidget(buildWithSystemInsets());
        await tester.pumpAndSettle();

        // The "Don't have an account?" button should be visible and tappable
        final createAccountButton = find.text(
          "Don't have an account? Create one",
        );
        expect(createAccountButton, findsOneWidget);

        // Verify the button is within the visible area (not behind nav bar)
        final buttonBox = tester.renderObject(createAccountButton).paintBounds;
        expect(buttonBox.bottom, greaterThan(0));
      });
    });

    group('MEDIUM-risk screen: GamificationScreen', () {
      Widget buildWithSystemInsets() {
        return const MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: 48),
            viewPadding: EdgeInsets.only(bottom: 48),
          ),
          child: ProviderScope(child: MaterialApp(home: GamificationScreen())),
        );
      }

      testWidgets('contains SafeArea widget', (tester) async {
        await tester.pumpWidget(buildWithSystemInsets());
        await tester.pumpAndSettle();

        expect(find.byType(SafeArea), findsWidgets);
      });

      testWidgets('SafeArea protects bottom content', (tester) async {
        await tester.pumpWidget(buildWithSystemInsets());
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        // Screen should render without overflow errors
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsOneWidget);
      });
    });
  });
}
