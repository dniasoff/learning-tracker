// AUD-gamification-21 — no hardcoded Color(0x...) hex literals anywhere
// under lib/features/gamification/.
//
// Finding: 38+ sites across 10 evidence files (point_config_screen.dart,
// pro_tip_card.dart, achievement_unlock_celebration.dart,
// child_redemption_screen.dart, achievement_tier_card.dart,
// locked_achievement_shell.dart, progress_summary_card.dart,
// reward_configuration_screen.dart, parent_pending_redemptions_screen.dart,
// avatar_picker_row.dart) bypassed the design-token system with inline
// `Color(0x...)` hex literals -- in fact a full sweep of the feature
// directory found 126 occurrences (100 distinct values) across 14 files,
// including tier_style.dart's entire achievement-tier palette (not named in
// the finding's own evidence list, but squarely inside its "No
// lib/features/gamification/**/*.dart file ... contains a Color(0x...)
// literal outside core/theme" acceptance criterion). All 100 distinct
// values were extracted into lib/core/theme/app_colors.dart (5 reused an
// already-existing AppColors constant with the same value instead of
// duplicating it) and every call site now references the named constant.
//
// Acceptance criterion (verbatim): "no_color_literal_outside_theme reports
// zero violations in this feature once custom_lint is functional again."
// `dart run custom_lint` cannot currently discover this project without an
// analysis_options.yaml plugin marker that breaks the `dart analyze
// --fatal-infos` hard gate (AUD-guardrails-03 -- see
// docs/coding-standards.md "custom_lint toolchain status"), so its CLI exit
// code cannot be trusted as a live gate. This test is the AC-named checker
// that CAN run live in CI/`make test`, following the same precedent as
// AUD-notifications-12 / AUD-tutoring-18: it mirrors the
// no_color_literal_outside_theme rule's own detection logic (a
// `Color(0x...)` hex-literal constructor call, see
// packages/custom_lints/lib/src/rules/no_color_literal_outside_theme.dart)
// AND the rule's own whitelist (skip `lib/core/theme/`, `*.g.dart`,
// `*.freezed.dart`), scanning the entire lib/features/gamification/
// directory so it cannot go stale/green again if a new file with a raw
// literal is added later. It doubles as this finding's red-first
// regression guard: scanning the pre-fix tree found all 126 literals across
// 14 files; the tree is clean now that every one references AppColors.

@Tags(['gamification', 'aud_gamification_21'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no Color(0x...) hex literals anywhere under '
      'lib/features/gamification/ (AUD-gamification-21 AC scope, the whole '
      'feature directory, not just the finding\'s 10 evidence files)', () {
    const dirPath = 'lib/features/gamification';
    final dir = Directory(dirPath);
    expect(dir.existsSync(), isTrue, reason: '$dirPath must exist');

    final hexLiteral = RegExp(r'Color\(0[xX][0-9A-Fa-f]{6,8}\)');
    final violations = <String>[];

    final dartFiles =
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            // Mirror the custom_lint rule's own whitelist: generated files
            // and files under lib/core/theme/ (none live under this feature
            // directory today, but keep parity with the rule's logic).
            .where(
              (f) =>
                  !f.path.endsWith('.g.dart') &&
                  !f.path.endsWith('.freezed.dart'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    // Sanity check: the directory scan must actually find files (guards
    // against a typo'd path silently producing a vacuous pass).
    expect(
      dartFiles,
      isNotEmpty,
      reason: 'expected to find .dart files under $dirPath',
    );

    for (final file in dartFiles) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (hexLiteral.hasMatch(lines[i])) {
          violations.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found hardcoded Color(0x...) hex literals outside AppColors '
          'somewhere under $dirPath/ -- extract them into '
          'lib/core/theme/app_colors.dart instead:\n${violations.join('\n')}',
    );
  });
}
