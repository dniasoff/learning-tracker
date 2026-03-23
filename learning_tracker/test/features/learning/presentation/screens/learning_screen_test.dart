import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';

void main() {
  group('LearningScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LearningScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows key UI elements', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LearningScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Learning Screen'), findsOneWidget);
    });
  });
}
