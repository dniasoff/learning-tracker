import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart';

void main() {
  group('GamificationScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GamificationScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows key UI elements', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GamificationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Gamification'), findsOneWidget);
      expect(find.text('Gamification Screen'), findsOneWidget);
    });
  });
}
