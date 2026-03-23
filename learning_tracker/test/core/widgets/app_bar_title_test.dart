import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';

void main() {
  group('AppBarTitle', () {
    testWidgets('displays text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const AppBarTitle(text: 'Dashboard')),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('wraps text in FittedBox', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const AppBarTitle(text: 'Dashboard')),
          ),
        ),
      );

      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('scales down long text without truncation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const AppBarTitle(
                text:
                    'Mark Prior Completions — Mishnah Berurah Extended Edition',
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('Mark Prior Completions — Mishnah Berurah Extended Edition'),
        findsOneWidget,
      );
      expect(find.byType(FittedBox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses BoxFit.scaleDown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const AppBarTitle(text: 'Test')),
          ),
        ),
      );

      final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fittedBox.fit, BoxFit.scaleDown);
    });

    testWidgets('child widget is used when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const AppBarTitle(child: Icon(Icons.search))),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(FittedBox), findsOneWidget);
    });
  });
}
