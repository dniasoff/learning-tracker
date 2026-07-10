// AUD-tutoring-18 — no hardcoded Color/Colors literals in tutoring screens.
//
// Regression for the P3 finding: ~43 sites across 9 tutoring screens used
// inline `Color(0xFF...)` hex literals or `Colors.<name>.shadeN` calls
// instead of the semantic tokens in AppColors/AppTheme, blocking a future
// systematic dark-mode/theme change from reaching these surfaces
// consistently and matching decline_invite_screen.dart's own inconsistency
// (AppColors.statusWarningSoft next to a raw Color(0xFFB07A00) for the same
// icon).
//
// The custom_lint `no_color_literal_outside_theme` rule only flags
// `Color(0x...)` hex-literal constructor calls (see
// packages/custom_lints/lib/src/rules/no_color_literal_outside_theme.dart)
// — it does not cover `Colors.<name>.shadeN`. This test covers both, per
// the finding's own title/evidence ("Replace hardcoded Color/Colors
// literals with theme tokens"), and doubles as this finding's red-first
// checker while custom_lint itself cannot be flipped on repo-wide
// (AUD-guardrails-03).
//
// `Colors.white` / `Colors.black` / `Colors.transparent` are intentionally
// exempt — they are structural primitives, not brand/theme colours, and
// are outside the lint rule's own stated concern.

@Tags(['tutoring', 'aud_tutoring_18'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no Color(0x...) hex literals or Colors.<name>.shadeN calls under '
      'lib/features/tutoring/presentation/screens/', () {
    final dir = Directory('lib/features/tutoring/presentation/screens');
    final violations = <String>[];

    final hexLiteral = RegExp(r'Color\(0[xX][0-9A-Fa-f]{6,8}\)');
    // Matches Colors.<name>.shadeNNN — but not the exempt primitives.
    final shadeCall = RegExp(
      r'Colors\.(?!white\b|black\b|transparent\b)\w+\.shade\d+',
    );

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (hexLiteral.hasMatch(line) || shadeCall.hasMatch(line)) {
          violations.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found hardcoded Color/Colors literals outside AppColors/AppTheme '
          'under lib/features/tutoring/presentation/screens/ '
          '(AUD-tutoring-18):\n${violations.join('\n')}',
    );
  });
}
