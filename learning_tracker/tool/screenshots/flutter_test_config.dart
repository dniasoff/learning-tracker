import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs before store_screenshots_test.dart (the only test file in this
/// directory tree).
///
/// AUD-t-cross-33: duplicated from `test/flutter_test_config.dart` rather
/// than shared, because Flutter's test harness discovers
/// `flutter_test_config.dart` by walking UP from a test file's own
/// directory to the package root (stopping at the first `pubspec.yaml` it
/// finds) — it does not walk sideways into `test/`, so a file moved out of
/// `test/` (here, into `tool/screenshots/`) loses `test/`'s config unless a
/// copy exists on its own path. Keep this in sync with
/// `test/flutter_test_config.dart` if that file's GoogleFonts handling
/// changes.
///
/// Sets GoogleFonts to offline mode so widget tests do not make HTTP requests
/// for fonts (which causes 10-minute timeouts in fake-async test environments).
/// PlusJakartaSans and Inter fonts are bundled in assets/fonts/ so they load
/// from the asset bundle instead.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  // Suppress residual "font not found" errors for any font variants not yet
  // bundled — they are cosmetic rendering issues, not test logic failures.
  final savedOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    if (msg.contains('GoogleFonts') || msg.contains('google_fonts')) return;
    savedOnError?.call(details);
  };

  await testMain();
}
