import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/hebrew_date_picker.dart';

Widget _buildTestApp({required ValueChanged<DateTime?> onResult}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async {
            final result = await HebrewDatePicker.show(context);
            onResult(result);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  group('HebrewDatePicker', () {
    testWidgets('renders year, month, day selectors and action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(onResult: (_) {}));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Select Hebrew date'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select date'), findsOneWidget);
    });

    testWidgets('displays Gregorian confirmation text', (tester) async {
      await tester.pumpWidget(_buildTestApp(onResult: (_) {}));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gregorian:'), findsOneWidget);
    });

    testWidgets('cancel returns null', (tester) async {
      DateTime? result;

      await tester.pumpWidget(_buildTestApp(onResult: (v) => result = v));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('select returns a DateTime', (tester) async {
      DateTime? result;

      await tester.pumpWidget(_buildTestApp(onResult: (v) => result = v));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result, isA<DateTime>());
    });

    testWidgets('year increment updates displayed year', (tester) async {
      await tester.pumpWidget(_buildTestApp(onResult: (_) {}));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find the Hebrew year (should be > 5000)
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final yearText = textWidgets.firstWhere(
        (t) =>
            int.tryParse(t.data ?? '') != null &&
            (int.tryParse(t.data!) ?? 0) > 5000,
      );
      final initialYear = int.parse(yearText.data!);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('${initialYear + 1}'), findsOneWidget);
    });
  });
}
