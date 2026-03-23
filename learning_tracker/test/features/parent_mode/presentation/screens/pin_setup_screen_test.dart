import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/pin_setup_screen.dart';

void main() {
  group('PinSetupScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PinSetupScreen())),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Enter New PIN'), findsOneWidget);
    });
  });
}
