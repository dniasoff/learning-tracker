import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/rewards_setup_screen.dart';

void main() {
  group('RewardsSetupScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RewardsSetupScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Add mystery rewards for your child to earn!'),
          findsOneWidget);
    });
  });
}
