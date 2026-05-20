// Regression test for the `features/progress/progress.dart` barrel
// (F5 — W7-D adversarial fix wave).
//
// Rule 2 (DNI-386): cross-feature deep imports into `lib/features/progress/`
// sub-paths are forbidden — the only permitted cross-feature reference is
// this barrel. The dashboard relies on `ProgressTierCounterRow` exported
// via the barrel; if that export is dropped or renamed, the dashboard's
// import (`features/progress/progress.dart`) breaks at compile time.
// Importing the barrel here and naming the symbol asserts that contract.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/progress.dart';

void main() {
  test('progress barrel exposes ProgressTierCounterRow', () {
    // Reference the symbol so the analyzer/test runner forces the import
    // to resolve. If the export is dropped from the barrel this test
    // fails to compile — exactly the regression we want to surface.
    // `Type` is sufficient — we don't need to instantiate the widget.
    const widgetType = ProgressTierCounterRow;
    expect(widgetType.toString(), 'ProgressTierCounterRow');
  });
}
