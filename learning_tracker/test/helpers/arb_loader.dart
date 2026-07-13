/// Shared ARB-loading helper for `test/l10n/*_test.dart` regression tests
/// (AUD-t-cross-22).
///
/// Tests should call [loadArb] rather than hand-rolling their own
/// `_loadArb`/`File('lib/l10n/app_$locale.arb')`. Before this helper
/// existed, several l10n regression tests each defined (or inlined) their
/// own copy, and the copies had already drifted: some resolved only
/// `lib/l10n/app_$locale.arb` (correct when `flutter test` runs from the
/// `learning_tracker/` package root) while others added a
/// `../lib/l10n/...` fallback candidate (correct when a single file is run
/// from a CWD rooted one level up, e.g. inside `test/`). This helper
/// carries both candidates so every ARB-reading l10n test copes with either
/// working directory.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Loads and JSON-decodes `app_<locale>.arb` from `lib/l10n/`, trying the
/// package-root-relative path first and falling back to a path one
/// directory up.
Map<String, dynamic> loadArb(String locale) {
  final candidates = [
    File('lib/l10n/app_$locale.arb'),
    File('../lib/l10n/app_$locale.arb'),
  ];
  final file = candidates.firstWhere(
    (f) => f.existsSync(),
    orElse: () =>
        throw TestFailure('Could not locate lib/l10n/app_$locale.arb.'),
  );
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}
