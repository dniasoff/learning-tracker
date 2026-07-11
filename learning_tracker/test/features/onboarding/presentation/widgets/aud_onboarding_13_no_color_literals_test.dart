// AUD-onboarding-13 — no hardcoded Color(0x...) hex literals anywhere under
// lib/features/onboarding/presentation/widgets/.
//
// Finding: the same navy (0xFF1A36A5) was hand-typed as a private
// `const _kNavy = Color(0xFF1A36A5);` constant independently in 3 files
// (intro_mishna_page.dart, intro_page_indicator.dart,
// intro_rewards_page.dart — 19 raw Color literals total: 6+2+11), instead
// of one shared source in AppColors/AppTheme.
//
// Acceptance criterion (verbatim): "Once custom_lint is fixed, dart run
// custom_lint reports zero no_color_literal_outside_theme violations under
// lib/features/onboarding/presentation/widgets/." The AC's scope is the
// whole directory, not just the 3 files named in the finding's evidence —
// a bounce on the first delivery attempt (which scoped this checker to only
// those 3 files, and left 13 violations unfixed in glowing_cta_button.dart
// and intro_daily_plan_page.dart) confirmed this reading. All hex literals
// across all 5 files in this directory were extracted into the
// "Onboarding intro carousel (AUD-onboarding-13)" section of
// lib/core/theme/app_colors.dart; the files now import and reference those
// named constants instead of redefining/embedding them locally.
//
// The custom_lint `no_color_literal_outside_theme` rule (packages/
// custom_lints/lib/src/rules/no_color_literal_outside_theme.dart) is the
// canonical Rule-0 checker for this pattern, but `dart run custom_lint`
// cannot currently discover this project without an analysis_options.yaml
// plugin marker that breaks the `dart analyze --fatal-infos` hard gate
// (AUD-guardrails-03 — see docs/coding-standards.md "custom_lint toolchain
// status"), so its CLI exit code cannot be trusted as a live gate. This
// test is the AC-named checker that CAN run live in CI/`make test`: it
// mirrors the rule's own detection logic (a `Color(0x...)` hex-literal
// constructor call) AND the rule's own whitelist (skip `lib/core/theme/`,
// `*.g.dart`, `*.freezed.dart`), but scans the ENTIRE
// lib/features/onboarding/presentation/widgets/ directory tree — matching
// the AC's real condition — rather than a fixed file list, so it cannot go
// stale/green again if a new file with a raw literal is added later. It
// doubles as this finding's red-first regression guard: scanning the
// pre-fix tree found all 32 literals (19 in the 3 originally-named files +
// 13 in glowing_cta_button.dart/intro_daily_plan_page.dart); the tree is
// clean now that every file references AppColors instead.

@Tags(['onboarding', 'aud_onboarding_13'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no Color(0x...) hex literals anywhere under '
      'lib/features/onboarding/presentation/widgets/ (AUD-onboarding-13 AC '
      'scope, not just the finding\'s 3 evidence files)', () {
    const dirPath = 'lib/features/onboarding/presentation/widgets';
    final dir = Directory(dirPath);
    expect(dir.existsSync(), isTrue, reason: '$dirPath must exist');

    final hexLiteral = RegExp(r'Color\(0[xX][0-9A-Fa-f]{6,8}\)');
    final violations = <String>[];

    final dartFiles =
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            // Mirror the custom_lint rule's own whitelist: generated
            // files are exempt (there are none today under this
            // directory, but keep parity with the rule's logic).
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
