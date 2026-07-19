// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_log_less_catch.dart';

/// AUD-tracks-04 regression test (EH-3 acceptance criterion 3: "EH-3's
/// log-less-catch grep (once made a checker) passes on both files").
///
/// The finding flagged:
///   - step_starting_position.dart: `_loadContent`'s `catch (_) { ... }`
///     swallowed the exception with no `AppLogger` call and no `rethrow`.
///   - step_starting_position_calendar.dart: `_refreshCalendarEntry` had no
///     `catch` clause at all (only `finally`), so a thrown exception left
///     no diagnostic trail scoped to this widget.
///
/// Both catches now call `AppLogger.instance.error(...)` before updating
/// state. Like sacred_time_no_color_literal_regression_test.dart
/// (AUD-sacred_time-09), this test resolves and analyzes the REAL
/// production files on disk via [DartLintRule.testAnalyzeAndRun], which
/// drives the analyzer directly and does not depend on the `dart run
/// custom_lint` plugin-discovery path that is currently broken (see
/// docs/coding-standards.md, "custom_lint toolchain status"). It is a live,
/// non-fabricated regression guard: if a future edit reintroduces a
/// log-less catch in either file, this test fails again automatically.
///
/// `NoLogLessCatch`'s own "fires on a violation" behaviour is already
/// covered by no_log_less_catch_test.dart's `violations` group — this file
/// only needs to prove the two AUD-tracks-04 fix sites are clean.
void main() {
  group('AUD-tracks-04 — no_log_less_catch', () {
    const rule = NoLogLessCatch();

    /// Resolves [relativePathFromThisPackage] (relative to
    /// `packages/custom_lints/`, the working directory `dart test` runs
    /// from — see `make lint-rules-test`) to an absolute, symlink-resolved
    /// path and runs the rule against it.
    Future<List<String>> violationsIn(
      String relativePathFromThisPackage,
    ) async {
      final absolute = File(relativePathFromThisPackage).absolute.path;
      final normalized = File(absolute).resolveSymbolicLinksSync();
      final errors = await rule.testAnalyzeAndRun(File(normalized));
      return errors
          .where((e) => e.errorCode.name == 'no_log_less_catch')
          .map((e) => 'offset ${e.offset}: ${e.message}')
          .toList();
    }

    test(
      'step_starting_position.dart has zero log-less catch blocks',
      () async {
        final hits = await violationsIn(
          '../../learning_tracker/lib/features/tracks/setup/presentation/'
          'steps/step_starting_position.dart',
        );
        expect(
          hits,
          isEmpty,
          reason: 'AUD-tracks-04: _loadContent\'s catch must log via '
              'AppLogger.instance.error before updating state, found: $hits',
        );
      },
    );

    test(
      'step_starting_position_calendar.dart has zero log-less catch blocks',
      () async {
        final hits = await violationsIn(
          '../../learning_tracker/lib/features/tracks/setup/presentation/'
          'steps/step_starting_position_calendar.dart',
        );
        expect(
          hits,
          isEmpty,
          reason: 'AUD-tracks-04: _refreshCalendarEntry\'s catch must log via '
              'AppLogger.instance.error before updating state, found: $hits',
        );
      },
    );
  });
}
