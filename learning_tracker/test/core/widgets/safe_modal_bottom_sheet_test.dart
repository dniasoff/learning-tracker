import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/safe_modal_bottom_sheet.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('opens the requested content and returns its result', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSafeModalBottomSheet<int>(
                context: context,
                builder: (sheetContext) => TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(42),
                  child: const Text('Close sheet'),
                ),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Close sheet'), findsOneWidget);

    await tester.tap(find.text('Close sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Close sheet'), findsNothing);
  });
}
