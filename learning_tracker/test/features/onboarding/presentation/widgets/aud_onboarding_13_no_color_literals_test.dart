// AUD-onboarding-13 — no hardcoded Color(0x...) hex literals in the intro
// carousel illustration widgets.
//
// Finding: the same navy (0xFF1A36A5) was hand-typed as a private
// `const _kNavy = Color(0xFF1A36A5);` constant independently in 3 files
// (intro_mishna_page.dart, intro_page_indicator.dart,
// intro_rewards_page.dart — 19 raw Color literals total: 6+2+11), instead
// of one shared source in AppColors/AppTheme. Fix: all distinct hex values
// used across the 3 files were added to AppColors (the
// "Onboarding intro carousel (AUD-onboarding-13)" section of
// lib/core/theme/app_colors.dart) and the files now import and reference
// those named constants instead of redefining them locally.
//
// The custom_lint `no_color_literal_outside_theme` rule (packages/
// custom_lints/lib/src/rules/no_color_literal_outside_theme.dart) is the
// canonical Rule-0 checker for this pattern, but `dart run custom_lint`
// cannot currently discover this project without an analysis_options.yaml
// plugin marker that breaks the `dart analyze --fatal-infos` hard gate
// (AUD-guardrails-03 — see docs/coding-standards.md "custom_lint toolchain
// status"), so its CLI exit code cannot be trusted as a live gate. This
// test is the AC-named checker that CAN run live in CI/`make test`, mirrors
// the rule's own detection logic (a `Color(0x...)` hex-literal constructor
// call), and doubles as this finding's red-first regression guard: it
// failed (found the 19 pre-fix literals) before the AppColors extraction
// above, and is green now that the 3 files reference AppColors instead.
//
// Scope note: `dart run custom_lint`'s manual-marker scratch-run (see this
// finding's delivery commit) also surfaced pre-existing
// `no_color_literal_outside_theme` violations in two OTHER files under the
// same `lib/features/onboarding/presentation/widgets/` directory —
// `glowing_cta_button.dart` (1 hit) and `intro_daily_plan_page.dart` (12
// hits). Neither file is named in this finding's evidence/"sites": 3, and
// neither is touched by its recommendation ("Add the ~8 distinct hex
// values used across the 3 files..."), so per scope discipline they are
// left as-is and tracked as a follow-up rather than fixed here — hence this
// checker is scoped to exactly the 3 evidence files, not the whole
// directory.

@Tags(['onboarding', 'aud_onboarding_13'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no Color(0x...) hex literals in the intro carousel illustration '
      'widgets named in AUD-onboarding-13 (intro_mishna_page.dart, '
      'intro_page_indicator.dart, intro_rewards_page.dart)', () {
    const files = [
      'lib/features/onboarding/presentation/widgets/intro_mishna_page.dart',
      'lib/features/onboarding/presentation/widgets/intro_page_indicator.dart',
      'lib/features/onboarding/presentation/widgets/intro_rewards_page.dart',
    ];
    final hexLiteral = RegExp(r'Color\(0[xX][0-9A-Fa-f]{6,8}\)');
    final violations = <String>[];

    for (final path in files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must exist');
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (hexLiteral.hasMatch(lines[i])) {
          violations.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found hardcoded Color(0x...) hex literals outside AppColors in '
          'the AUD-onboarding-13 evidence files — extract them into '
          'lib/core/theme/app_colors.dart instead:\n${violations.join('\n')}',
    );
  });
}
