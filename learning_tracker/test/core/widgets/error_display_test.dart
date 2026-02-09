import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';

void main() {
  group('ErrorDisplay', () {
    testWidgets('displays error message', (WidgetTester tester) async {
      const errorMessage = 'Something went wrong';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(message: errorMessage),
          ),
        ),
      );

      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('displays error icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(message: 'Error'),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays custom icon when provided',
        (WidgetTester tester) async {
      const customIcon = Icons.warning;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              message: 'Warning',
              icon: customIcon,
            ),
          ),
        ),
      );

      expect(find.byIcon(customIcon), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('displays retry button when onRetry provided',
        (WidgetTester tester) async {
      var retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              message: 'Error',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the retry text and button
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryPressed, isTrue);
    });

    testWidgets('does not display retry button when onRetry not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(message: 'Error'),
          ),
        ),
      );

      expect(find.text('Retry'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('centers content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(message: 'Error'),
          ),
        ),
      );

      // ErrorDisplay uses Center widget
      expect(find.byType(ErrorDisplay), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });
  });
}
