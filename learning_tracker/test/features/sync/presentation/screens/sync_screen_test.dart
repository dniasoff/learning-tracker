import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sync/presentation/screens/sync_screen.dart';

void main() {
  group('SyncScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SyncScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows key UI elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SyncScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('Sync Screen'), findsOneWidget);
    });
  });
}
