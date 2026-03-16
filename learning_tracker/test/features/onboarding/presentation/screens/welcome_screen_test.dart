import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/welcome_screen.dart';

void main() {
  Widget createTestWidget() {
    return const MaterialApp(home: WelcomeScreen());
  }

  group('WelcomeScreen Widget Tests', () {
    testWidgets('displays app name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.text('Torah Learning Tracker'), findsOneWidget);
    });

    testWidgets('displays app description', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(
        find.textContaining('Track your Torah learning journey'),
        findsOneWidget,
      );
    });

    testWidgets('displays Get Started button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('displays sign in link', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });

    testWidgets('displays app icon', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });
  });
}
