import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/track_label_step.dart';

void main() {
  group('TrackLabelStep', () {
    testWidgets('pre-fills with default label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackLabelStep(defaultLabel: 'דף היומי', onComplete: (_) {}),
          ),
        ),
      );

      final textField = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );
      expect(textField.controller?.text, 'דף היומי');
    });

    testWidgets('calls onComplete with entered text', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackLabelStep(
              defaultLabel: '',
              onComplete: (label) => result = label,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'My Track');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(result, 'My Track');
    });

    testWidgets('shows validation error for empty input', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackLabelStep(
              defaultLabel: '',
              onComplete: (label) => result = label,
            ),
          ),
        ),
      );

      // Clear any default and try to submit empty
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Please enter a name'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('accepts default without editing', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackLabelStep(
              defaultLabel: 'משניות',
              onComplete: (label) => result = label,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(result, 'משניות');
    });
  });
}
