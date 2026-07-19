// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_color_literal_outside_theme.dart';

/// AUD-settings-11 regression test.
///
/// The finding flagged 9 raw `Color(0xFF…)` / `Color(0x…)` hex-literal
/// constructor calls in user_profile_header_card.dart, bypassing the
/// `core/theme/` token system: the parent/tutor badge pair (background +
/// text, 4 sites), the avatar ring (1 site), two card drop-shadow tints (2
/// sites), and the offline "no backup" cloud-off icon/text colour (2 sites,
/// duplicated within the file). One of them (0xFFE65100) was byte-for-byte
/// identical to the already-defined `AppColors.accentBurntOrange`.
///
/// Like `sacred_time_no_color_literal_regression_test.dart`
/// (AUD-sacred_time-09), this test resolves and analyzes the REAL
/// production file on disk (via [DartLintRule.testAnalyzeAndRun], which
/// drives the analyzer directly and does not depend on the `dart run
/// custom_lint` plugin-discovery path that is currently broken — see
/// docs/coding-standards.md, "custom_lint toolchain status"). That means
/// this is a live, non-fabricated regression guard: if a future edit
/// reintroduces a raw hex literal in the file, this test fails again
/// automatically — it is not a one-time snapshot.
void main() {
  group('AUD-settings-11 — no_color_literal_outside_theme', () {
    const rule = NoColorLiteralOutsideTheme();

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
          .where((e) => e.errorCode.name == 'no_color_literal_outside_theme')
          .map((e) => 'offset ${e.offset}: ${e.message}')
          .toList();
    }

    test(
      'user_profile_header_card.dart has zero raw Color(0x…) literals',
      () async {
        final hits = await violationsIn(
          '../../learning_tracker/lib/features/settings/presentation/'
          'widgets/user_profile_header_card.dart',
        );
        expect(
          hits,
          isEmpty,
          reason: 'AUD-settings-11: user_profile_header_card.dart must route '
              'its badge/avatar/shadow palette through '
              'core/theme/app_colors.dart, found: $hits',
        );
      },
    );
  });
}
