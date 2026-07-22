// AUD-core-widgets-03 — no hardcoded Color(0x...) hex literals anywhere
// under lib/core/widgets/.
//
// Finding: stat_card.dart, preference_list_tile.dart,
// preference_segmented_tile.dart, and app_dialog.dart mix AppColors/AppTheme
// tokens with raw `Color(0xFF...)` hex literals — most notably
// stat_card.dart:89,104 duplicating context.colors.blueNavy's exact hex
// (0xFF03174C) instead of referencing it, and preference_list_tile.dart:79 /
// preference_segmented_tile.dart:90 independently hardcoding the identical
// 0xFF929BAA. All 10 raw-literal sites across the 4 files were extracted
// into either the existing context.colors.blueNavy constant or new named
// constants in the "Core widgets (AUD-core-widgets-03)" section of
// lib/core/theme/app_colors.dart.
//
// Acceptance criteria (verbatim):
//   1. "grep for `Color(0xFF` in lib/core/widgets/ returns no matches for
//      the 3 currently-duplicated values (0xFF03174C, 0xFF929BAA) once
//      fixed." This checker enforces the stronger, whole-directory form of
//      that requirement (no raw Color(0x...) literal anywhere under
//      lib/core/widgets/, not just the 2 named duplicated values) so it
//      cannot go stale/green again if a new file with a raw literal is
//      added later, and matches the recommendation to also "name or fold
//      the remaining one-off literals in stat_card.dart/
//      preference_segmented_tile.dart/app_dialog.dart."
//   2. "Once custom_lint_core/analyzer versions are reconciled (tracked
//      separately), no_color_literal_outside_theme passes clean on these
//      files." The custom_lint `no_color_literal_outside_theme` rule
//      (packages/custom_lints/lib/src/rules/no_color_literal_outside_theme.dart)
//      is the canonical Rule-0 checker for this pattern, but `dart run
//      custom_lint` cannot currently discover this project (AUD-guardrails-03
//      — see docs/coding-standards.md "custom_lint toolchain status"), so
//      its CLI exit code cannot be trusted as a live gate. This test mirrors
//      the rule's own detection logic (a `Color(0x...)` hex-literal
//      constructor call) and its own whitelist (skip `lib/core/theme/`,
//      `*.g.dart`, `*.freezed.dart`) so it can run live in CI/`make test`
//      today, and will already be clean once custom_lint itself is
//      reconciled.
//
// Red-first: before the fix, running this test against the pre-fix tree
// found exactly 10 violations (the finding's stated "sites": 10) across the
// 4 evidence files:
//   lib/core/widgets/stat_card.dart:73,75,80,89,104
//   lib/core/widgets/preference_list_tile.dart:79
//   lib/core/widgets/preference_segmented_tile.dart:82,90,117
//   lib/core/widgets/app_dialog.dart:290

@Tags(['core_widgets', 'aud_core_widgets_03'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no Color(0x...) hex literals anywhere under lib/core/widgets/ '
      '(AUD-core-widgets-03)', () {
    const dirPath = 'lib/core/widgets';
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
            // and files under lib/core/theme/ (none live under this
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
          'Found hardcoded Color(0x...) hex literals outside the theme layer '
          'somewhere under $dirPath/ — extract them into '
          'lib/core/theme/app_palette.dart instead:\n${violations.join('\n')}',
    );
  });
}
