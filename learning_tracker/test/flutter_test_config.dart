import 'dart:async';

import 'package:flutter/material.dart';
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
