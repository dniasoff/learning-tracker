import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs before every test file in this directory tree.
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
