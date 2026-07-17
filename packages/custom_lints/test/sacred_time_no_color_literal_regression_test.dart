// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_color_literal_outside_theme.dart';

/// AUD-sacred_time-09 regression test.
///
/// The finding flagged 6 raw `Color(0xFF…)` / `Color(0x…)` hex-literal
/// constructor calls in these two Sacred Time widget files, bypassing the
/// `core/theme/` token system:
///   - sacred_time_lock_overlay.dart (4 sites — the per-window-kind lock
///     screen background palette)
///   - sacred_time_settings_card.dart (2 sites — the header background and
///     card drop-shadow)
///
/// Unlike every other rule test in this directory, this test resolves and
/// analyzes the REAL production files on disk (via [DartLintRule
/// .testAnalyzeAndRun], which drives the analyzer directly and does not
/// depend on the `dart run custom_lint` plugin-discovery path that is
/// currently broken — see docs/coding-standards.md, "custom_lint toolchain
/// status"). That means this is a live, non-fabricated regression guard: if
/// a future edit reintroduces a raw hex literal in either file, this test
/// fails again automatically — it is not a one-time snapshot.
///
/// (`Colors.white` usages in these files are untouched: they are named
/// Flutter constants, not `Color(0x…)` literal constructor calls, and are
/// deliberately excluded by this rule — see the "allowed" group in
/// no_color_literal_outside_theme_test.dart. That exclusion is the rule's
/// own documented, tested design, not a gap introduced by this fix.)
void main() {
  group('AUD-sacred_time-09 — no_color_literal_outside_theme', () {
    const rule = NoColorLiteralOutsideTheme();

    /// Resolves [relativePathFromThisPackage] (relative to
    /// `packages/custom_lints/`, the working directory `dart test` runs
    /// from — see `make lint-rules-test`) to an absolute, symlink-resolved
    /// path and runs the rule against it.
    Future<List<String>> violationsIn(
        String relativePathFromThisPackage) async {
      final absolute = File(relativePathFromThisPackage).absolute.path;
      final normalized = File(absolute).resolveSymbolicLinksSync();
      final errors = await rule.testAnalyzeAndRun(File(normalized));
      return errors
          .where((e) => e.errorCode.name == 'no_color_literal_outside_theme')
          .map((e) => 'offset ${e.offset}: ${e.message}')
          .toList();
    }

    test(
      'sacred_time_lock_overlay.dart has zero raw Color(0x…) literals',
      () async {
        final hits = await violationsIn(
          '../../learning_tracker/lib/features/sacred_time/presentation/'
          'widgets/sacred_time_lock_overlay.dart',
        );
        expect(
          hits,
          isEmpty,
          reason:
              'AUD-sacred_time-09: sacred_time_lock_overlay.dart must route '
              'its lock-screen palette through core/theme/app_colors.dart, '
              'found: $hits',
        );
      },
    );

    test(
      'sacred_time_settings_card.dart has zero raw Color(0x…) literals',
      () async {
        final hits = await violationsIn(
          '../../learning_tracker/lib/features/sacred_time/presentation/'
          'widgets/sacred_time_settings_card.dart',
        );
        expect(
          hits,
          isEmpty,
          reason:
              'AUD-sacred_time-09: sacred_time_settings_card.dart must route '
              'its header/shadow colours through core/theme/app_colors.dart, '
              'found: $hits',
        );
      },
    );
  });
}
