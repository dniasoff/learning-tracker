import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/scrollable_step_body.dart';

void main() {
  group('ScrollableStepBody', () {
    testWidgets('renders children without overflow in normal viewport',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScrollableStepBody(
              child: Column(
                children: List.generate(
                  10,
                  (i) => Container(height: 60, color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ScrollableStepBody), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'does not overflow in a small 320×480 viewport (simulated keyboard inset)',
      (tester) async {
        // Simulate a small viewport (e.g. a keybaord eating half the screen).
        tester.view.physicalSize = const Size(411 * 2.75, 480 * 2.75);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ScrollableStepBody(
                child: Column(
                  children: List.generate(
                    20,
                    (i) => Container(
                      height: 60,
                      color: i.isEven ? Colors.blue : Colors.green,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // No RenderFlex overflow exception should be thrown.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('accepts custom padding', (tester) async {
      const customPadding = EdgeInsets.all(32);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScrollableStepBody(
              padding: customPadding,
              child: const Text('Hello'),
            ),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.padding, equals(customPadding));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboardDismissBehavior is onDrag', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScrollableStepBody(child: const Text('test')),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scrollView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });
  });
}
