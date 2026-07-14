/// Regression test for AUD-t-cross-81.
///
/// `flutter_test_config.dart` used to install a `FlutterError.onError`
/// override in `testExecutable()` (before `testMain()` runs) that filtered
/// out any error whose message contains "GoogleFonts"/"google_fonts",
/// claiming to suppress "residual font not found errors... cosmetic
/// rendering issues, not test logic failures" during test execution.
///
/// That claim was false. `TestWidgetsFlutterBinding._runTest()`
/// (flutter_test's `binding.dart`) saves whatever handler is installed when
/// it starts (`_oldExceptionHandler = FlutterError.onError;`) and then
/// unconditionally overwrites `FlutterError.onError` with its own handler
/// for the duration of the individual test body — the old handler is only
/// restored afterwards, in `postTest()`. Since `testExecutable()` installs
/// its override once, before any individual `test()`/`testWidgets()` body
/// runs, that override is exactly the "old handler" `_runTest()` swaps away
/// — it is never the active `FlutterError.onError` while a test body
/// (including any `pumpWidget`/`pumpAndSettle`) is actually executing.
///
/// This test proves that directly: it throws a `FlutterError` whose message
/// contains "GoogleFonts" from a widget's `build()` mid-`pumpWidget`, with
/// no local `FlutterError.onError` override of its own (unlike several
/// other test files in this suite, e.g. `test/core/navigation/
/// app_shell_test.dart`, which correctly install their own filter *inside*
/// the test body/`setUp()` — that pattern works precisely because it runs
/// inside `_runTest()`'s window, unlike `flutter_test_config.dart`'s
/// file-level override). `WidgetTester.takeException()` reads
/// `TestWidgetsFlutterBinding`'s `_pendingExceptionDetails`, which the SDK's
/// own handler (not `flutter_test_config.dart`'s dead filter) populates —
/// `takeException()` is exactly "a mechanism that actually executes during
/// `_runTest`'s window" (AUD-t-cross-81's acceptance criterion). If the
/// error had been suppressed by `flutter_test_config.dart`'s filter,
/// `_pendingExceptionDetails` would never be set and `takeException()`
/// would return null.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Throws mid-build so the framework reports the exact exception object via
/// `FlutterError.reportError` (see framework.dart's `_reportException`,
/// which passes the caught exception through unmodified).
class _ThrowsGoogleFontsErrorWidget extends StatelessWidget {
  const _ThrowsGoogleFontsErrorWidget();

  @override
  Widget build(BuildContext context) {
    throw FlutterError(
      'GoogleFonts font not found (AUD-t-cross-81 regression fixture)',
    );
  }
}

void main() {
  testWidgets(
    'a mid-pump FlutterError whose message contains "GoogleFonts" is not '
    'suppressed — flutter_test_config.dart\'s file-level onError override '
    'never runs during a test body (AUD-t-cross-81)',
    (tester) async {
      await tester.pumpWidget(const _ThrowsGoogleFontsErrorWidget());

      final exception = tester.takeException();

      expect(
        exception,
        isNotNull,
        reason:
            'If flutter_test_config.dart\'s GoogleFonts onError filter ran '
            'during this pump, the error would have been swallowed and '
            'takeException() would return null. It is non-null here, '
            'proving the filter never executes inside '
            "TestWidgetsFlutterBinding._runTest()'s window (AUD-t-cross-81).",
      );
      expect(
        exception.toString(),
        contains('GoogleFonts'),
        reason:
            'sanity-check that we captured the fixture\'s own error, '
            'not something else',
      );
    },
  );
}
