import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

import 'helpers/golden_font_loader.dart';

/// Runs before every test file in this directory tree.
///
/// Sets GoogleFonts to offline mode so widget tests do not make HTTP requests
/// for fonts (which causes 10-minute timeouts in fake-async test environments).
/// PlusJakartaSans and Inter fonts are bundled in assets/fonts/ so they load
/// from the asset bundle instead.
///
/// Also loads real typefaces (AUD-t-cross-51, TQ-5: "fonts loaded in
/// `flutter_test_config.dart`") before any test runs. `flutter test` never
/// loads fonts on its own — declaring one under pubspec's `fonts:` section
/// only makes it available to real app runs, not the test sandbox — so
/// without this step every `Text`/golden render in the whole suite paints
/// either nothing (blank) or a fallback tofu-glyph box, which is why every
/// `goldenTest()` call site previously had to skip its pixel assertion.
/// [loadFonts] covers Roboto + MaterialIcons (the SDK-bundled defaults);
/// [loadHebrewFont] covers "Noto Sans Hebrew", the only family this repo
/// declares under pubspec's `flutter: fonts:` section.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await loadFonts();
  await loadHebrewFont();

  // NOTE (AUD-t-cross-81): a `FlutterError.onError` override used to be
  // installed here to filter out font-not-found errors. It never worked:
  // `TestWidgetsFlutterBinding._runTest()` saves whatever handler is
  // installed at that point and unconditionally overwrites
  // `FlutterError.onError` with its own handler for the duration of each
  // individual test body, restoring the saved handler only afterwards (in
  // `postTest()`). An override installed once here, before any individual
  // test runs, is exactly the handler `_runTest()` swaps away — it is never
  // active while a test body (including any `pumpWidget`/`pumpAndSettle`) is
  // actually executing, so it could never have suppressed an error raised
  // mid-pump. See `test/flutter_test_config_error_filter_test.dart` for the
  // regression proof. A handful of individual test files (e.g.
  // `test/core/navigation/app_shell_test.dart`) install an equivalent filter
  // correctly, from *inside* the test body/`setUp()`, where it does run
  // inside `_runTest()`'s window — that per-test pattern is the one that
  // actually works.

  await testMain();
}
