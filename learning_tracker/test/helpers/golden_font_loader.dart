/// Shared font loader for `test/golden/*_test.dart` widget-golden tests
/// (AUD-t-cross-03, TQ-5).
///
/// Golden screenshots need the real Material fonts (Roboto + MaterialIcons)
/// loaded, otherwise text renders as Ahem boxes / tofu glyphs and every
/// `matchesGoldenFile` comparison mismatches the checked-in PNGs. Those
/// fonts ship inside the Flutter SDK's cache
/// (`<FLUTTER_ROOT>/bin/cache/artifacts/material_fonts`), never as a repo
/// asset — so this helper resolves the directory dynamically via
/// `FLUTTER_ROOT` (which `flutter test` always sets for the child test
/// process) instead of a path hardcoded to one developer's machine/FVM
/// install.
library;

import 'dart:io';

import 'package:flutter/services.dart';

/// Resolves the Flutter SDK's bundled Material fonts directory.
///
/// Prefers the `FLUTTER_ROOT` environment variable — `flutter test` sets it
/// for every child test process, pointing at whatever SDK invoked the run,
/// so this works unchanged on any developer machine or CI runner. Falls
/// back to deriving the SDK root from the running executable's path
/// (`<FLUTTER_ROOT>/bin/cache/artifacts/engine/<platform>/flutter_tester`)
/// when the env var is absent. Returns `null` if neither source resolves —
/// callers should skip font loading rather than fall back to a
/// machine-specific literal.
///
/// [environment] and [resolvedExecutable] are injectable for testing;
/// production callers omit both and get `Platform.environment` /
/// `Platform.resolvedExecutable`.
String? materialFontsDir({
  Map<String, String>? environment,
  String? resolvedExecutable,
}) {
  final env = environment ?? Platform.environment;
  final root = env['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    return '$root/bin/cache/artifacts/material_fonts';
  }

  final exePath = resolvedExecutable ?? Platform.resolvedExecutable;
  const marker = '/bin/cache/artifacts';
  final idx = exePath.indexOf(marker);
  if (idx > 0) {
    return '${exePath.substring(0, idx)}/bin/cache/artifacts/material_fonts';
  }

  return null;
}

/// Loads real Roboto + MaterialIcons fonts so text renders in golden
/// screenshots instead of Ahem boxes/tofu glyphs.
///
/// No-ops (leaving fallback glyphs) if [materialFontsDir] cannot resolve a
/// directory, or if the resolved directory doesn't contain the expected
/// font files — better than throwing and blocking the whole suite.
Future<void> loadFonts() async {
  final fontDir = materialFontsDir();
  if (fontDir == null) return;

  const robotoVariants = {
    'Roboto': [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Light.ttf',
      'Roboto-Thin.ttf',
      'Roboto-Black.ttf',
      'Roboto-Italic.ttf',
    ],
  };

  for (final entry in robotoVariants.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final path = '$fontDir/$file';
      if (File(path).existsSync()) {
        final bytes = File(path).readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
    }
    await loader.load();
  }

  final iconsPath = '$fontDir/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final loader = FontLoader('MaterialIcons');
    final bytes = File(iconsPath).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}
