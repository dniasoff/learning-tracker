// AUD-progress-04 — no hardcoded Color(0x...) hex literals anywhere under
// lib/features/progress/presentation/widgets/.
//
// Finding: 29 raw `Color(0x...)` hex-literal call sites across 8 of the 15
// widget files in this directory bypassed the design-token system, most
// visibly the "active day" blue (0xFF103BAC) independently retyped in both
// streak_calendar.dart and monthly_activity_sliver_calendar.dart, and the
// "partial" amber (0xFFFFD26A) independently retyped twice inside
// lifetime_folder_styled_widgets.dart — proof that without a shared token, a
// future brand-colour tweak has to be hunted down by eye and will eventually
// miss a call site. All 29 sites now reference either a new named constant
// in the "Progress feature (AUD-progress-04)" section of
// lib/core/theme/app_colors.dart, or an existing AppColors constant with the
// identical value (context.colors.blueMid via .withValues(alpha:) for the two
// cumulative_line_chart.dart gradient stops, and
// context.colors.gamifTierGoldMutedIcon — already 0xFFFFB300 — reused for the
// siyumim_grouped_view.dart hero-card gold instead of minting a duplicate
// token for the same value).
//
// Acceptance criteria (verbatim):
//   1. "grep -o 'Color(0x[0-9A-Fa-f]{6,8})' lib/features/progress/
//      presentation/widgets/*.dart returns zero hits." — verified directly
//      via the shell grep during delivery (0 hits, was 29).
//   2. "no_color_literal_outside_theme passes clean on this directory once
//      custom_lint is functional again." The custom_lint
//      `no_color_literal_outside_theme` rule (packages/custom_lints/lib/src/
//      rules/no_color_literal_outside_theme.dart) is the canonical Rule-0
//      checker for this pattern, but `dart run custom_lint` cannot currently
//      discover this project without an analysis_options.yaml plugin marker
//      that breaks the `dart analyze --fatal-infos` hard gate
//      (AUD-guardrails-03 — see docs/coding-standards.md "custom_lint
//      toolchain status"), so its CLI exit code cannot be trusted as a live
//      gate this wave. This test is the AC-named checker that CAN run live
//      in CI/`make test`, following the same precedent as
//      AUD-notifications-12 / AUD-tutoring-18 / AUD-gamification-21 /
//      AUD-onboarding-13: it mirrors the rule's own detection logic (a
//      `Color(0x...)` hex-literal constructor call) AND the rule's own
//      whitelist (skip `lib/core/theme/`, `*.g.dart`, `*.freezed.dart`), and
//      scans the ENTIRE lib/features/progress/presentation/widgets/
//      directory tree so it cannot go stale/green again if a new file with a
//      raw literal is added later. It doubles as this finding's red-first
//      regression guard: scanning the pre-fix tree found all 29 literals
//      across 8 files; the tree is clean now that every one references
//      AppColors.

@Tags(['progress', 'aud_progress_04'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no Color(0x...) hex literals anywhere under '
      'lib/features/progress/presentation/widgets/ (AUD-progress-04 AC '
      "scope, not just the finding's evidence-listed lines)", () {
    const dirPath = 'lib/features/progress/presentation/widgets';
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
            // are exempt (there are none today under this directory, but
            // keep parity with the rule's logic).
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
          'somewhere under $dirPath/ — extract them into '
          'lib/core/theme/app_colors.dart instead:\n${violations.join('\n')}',
    );
  });
}
