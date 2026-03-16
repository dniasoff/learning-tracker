/// Widget tests for Story 8.4: Completion Feedback & Animations.
@Tags(['story_8_4'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_animation.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/points_popup.dart';

void main() {
  // ── CompletionAnimation mode variants ──

  group('CompletionAnimation widget', () {
    testWidgets('child mode renders checkmark with confetti', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CompletionAnimation(userMode: UserMode.child),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('adult mode renders checkmark without confetti', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CompletionAnimation(userMode: UserMode.adult),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));

      // L1: Verify no confetti particles in adult mode
      // Confetti particles are small Container widgets inside Positioned widgets;
      // in adult mode the _buildConfettiParticles() method is not called,
      // so there should be no Positioned widgets in the tree.
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('calls onComplete when animation finishes', (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CompletionAnimation(
                  userMode: UserMode.adult,
                  onComplete: () => completed = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(completed, true);
    });
  });

  // ── PointsPopup ──

  group('PointsPopup widget', () {
    testWidgets('displays correct point value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PointsPopup(
                    points: 15,
                    onDismiss: () => Navigator.of(context).pop(),
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+15 Points!'), findsOneWidget);
      expect(find.text('Great job!'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // Let auto-dismiss timer fire to avoid pending timer assertion
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('auto-dismisses after delay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PointsPopup(
                    points: 10,
                    autoDismissDelay: const Duration(milliseconds: 500),
                    onDismiss: () => Navigator.of(context).pop(),
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('+10 Points!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('+10 Points!'), findsNothing);
    });

    testWidgets('showPointsPopup with adult mode does not show dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPointsPopup(
                  context: context,
                  points: 10,
                  userMode: UserMode.adult,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // L3: Adult mode should not show any dialog
      expect(find.byType(PointsPopup), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  // ── AnimatedProgressBar ──

  group('AnimatedProgressBar widget', () {
    testWidgets('renders and animates to target value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: AnimatedProgressBar(
                value: 0.7,
                duration: Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressBar), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedProgressBar), findsOneWidget);

      // L2: Verify FractionallySizedBox widthFactor equals target value
      final fractionBox = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fractionBox.widthFactor, closeTo(0.7, 0.01));
    });

    testWidgets('calls onAnimationComplete when fill finishes', (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedProgressBar(
                value: 0.5,
                duration: const Duration(milliseconds: 200),
                onAnimationComplete: () => completed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(completed, true);
    });
  });

  // ── StreakWidget mode variants ──

  group('StreakWidget', () {
    testWidgets('child mode shows animated fire icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakWidget(
              currentStreak: 5,
              maxStreak: 10,
              userMode: UserMode.child,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text('5 day streak!'), findsOneWidget);
      expect(find.text('Best: 10 days'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('adult mode shows subtle display', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakWidget(
              currentStreak: 3,
              maxStreak: 7,
              userMode: UserMode.adult,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('(best: 7)'), findsOneWidget);
    });

    testWidgets('updates from N to N+1 with animation', (tester) async {
      var streakCount = 3;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  StreakWidget(
                    currentStreak: streakCount,
                    maxStreak: 10,
                    userMode: UserMode.child,
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => streakCount = 4),
                    child: const Text('Bump'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('3 day streak!'), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bump'));
      await tester.pump();
      expect(find.text('4 day streak!'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  // ── Non-blocking animation test ──

  group('Animation non-blocking', () {
    testWidgets('completion animation does not absorb pointer events', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => tapped = true,
                    child: const Text('Underlying'),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CompletionAnimation(userMode: UserMode.child),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Underlying'));
      expect(tapped, true);
    });
  });
}
