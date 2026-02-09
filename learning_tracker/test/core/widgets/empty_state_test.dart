import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';

void main() {
  group('EmptyState', () {
    testWidgets('displays message', (WidgetTester tester) async {
      const message = 'No items found';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyState(message: message)),
        ),
      );

      expect(find.text(message), findsOneWidget);
    });

    testWidgets('displays default icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyState(message: 'Empty')),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('displays custom icon when provided', (
      WidgetTester tester,
    ) async {
      const customIcon = Icons.search;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(message: 'No results', icon: customIcon),
          ),
        ),
      );

      expect(find.byIcon(customIcon), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    });

    testWidgets('displays subtitle when provided', (WidgetTester tester) async {
      const message = 'No items';
      const subtitle = 'Try adding some items';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(message: message, subtitle: subtitle),
          ),
        ),
      );

      expect(find.text(message), findsOneWidget);
      expect(find.text(subtitle), findsOneWidget);
    });

    testWidgets('does not display subtitle when not provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyState(message: 'Empty')),
        ),
      );

      // Only one Text widget (the message)
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('displays action widget when provided', (
      WidgetTester tester,
    ) async {
      var actionPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              message: 'No items',
              action: ElevatedButton(
                onPressed: () => actionPressed = true,
                child: const Text('Add Item'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Add Item'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();

      expect(actionPressed, isTrue);
    });

    testWidgets('does not display action when not provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyState(message: 'Empty')),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('centers content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyState(message: 'Empty')),
        ),
      );

      // EmptyState uses Center widget
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Empty'), findsOneWidget);
    });
  });
}
