import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/main.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  setUp(() {
    AppLogger.init();
  });

  testWidgets('app renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LearningTrackerApp()));
    expect(find.text('Mishnayos Tracker'), findsWidgets);
  });

  testWidgets('Talker Flutter UI is accessible in debug mode via debug menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LearningTrackerApp()));

    // In debug mode, the bug_report icon button should be visible.
    final debugButton = find.byIcon(Icons.bug_report);
    expect(debugButton, findsOneWidget);

    // Tap the debug button to open TalkerScreen.
    await tester.tap(debugButton);
    await tester.pumpAndSettle();

    // TalkerScreen should now be displayed.
    expect(find.byType(TalkerScreen), findsOneWidget);
  });

  testWidgets(
    'Talker Flutter UI displays recent log entries with correct log levels',
    (WidgetTester tester) async {
      final talker = AppLogger.instance;

      // Log entries at different levels before opening the UI.
      talker.info('Test info message');
      talker.warning('Test warning message');
      talker.error('Test error message');

      await tester.pumpWidget(const ProviderScope(child: LearningTrackerApp()));

      // Open the Talker debug screen.
      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pumpAndSettle();

      // The TalkerScreen should show recent log entries.
      expect(find.textContaining('Test info message'), findsOneWidget);
      expect(find.textContaining('Test warning message'), findsOneWidget);
      expect(find.textContaining('Test error message'), findsOneWidget);
    },
  );
}
