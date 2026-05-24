import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';

void main() {
  Widget buildWidget({
    required int currentStreak,
    required int maxStreak,
    required ProfileMode userMode,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StreakWidget(
          currentStreak: currentStreak,
          maxStreak: maxStreak,
          userMode: userMode,
        ),
      ),
    );
  }

  group('StreakWidget', () {
    testWidgets('displays current streak count and max streak', (tester) async {
      await tester.pumpWidget(
        buildWidget(currentStreak: 5, maxStreak: 10, userMode: ProfileMode.child),
      );

      expect(find.text('5 day streak!'), findsOneWidget);
      expect(find.text('Best: 10 days'), findsOneWidget);
    });

    testWidgets('shows animated variant in child mode', (tester) async {
      await tester.pumpWidget(
        buildWidget(currentStreak: 3, maxStreak: 7, userMode: ProfileMode.child),
      );

      // Child mode uses Card with larger fire icon and bold text
      expect(find.byType(Card), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text('3 day streak!'), findsOneWidget);
      expect(find.text('Best: 7 days'), findsOneWidget);
    });

    testWidgets('shows subtle variant in adult mode', (tester) async {
      await tester.pumpWidget(
        buildWidget(currentStreak: 3, maxStreak: 7, userMode: ProfileMode.adult),
      );

      // Adult mode — no Card, just simple text
      expect(find.byType(Card), findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('(best: 7)'), findsOneWidget);
    });
  });
}
