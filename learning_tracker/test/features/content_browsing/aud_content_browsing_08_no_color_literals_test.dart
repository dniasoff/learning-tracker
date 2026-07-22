// AUD-content_browsing-08 -- no raw Colors.* named-constant literals in the
// 2 evidence files under lib/features/content_browsing/presentation/.
//
// Finding: hierarchy_selection_panel.dart's inline breadcrumb separator used
// `color: Colors.grey` (instead of the theme.colorScheme.onSurfaceVariant
// token that the sibling separator in breadcrumb_navigation.dart already
// uses), and text_display_screen.dart used `color: Colors.white` /
// `foregroundColor: Colors.white` twice for text/foreground drawn over a
// branded background. All 3 sites now route through
// Theme.of(context).colorScheme.onSurfaceVariant / .onPrimary instead of a
// hand-typed Colors.* literal, so they repaint on a future theme/brand
// change instead of staying pinned to Material's default grey/white.
//
// Acceptance criterion (verbatim): "once dart run custom_lint is repaired,
// no_color_literal_outside_theme reports zero hits in these 2 files." The
// named rule (packages/custom_lints/lib/src/rules/
// no_color_literal_outside_theme.dart) only flags `Color(0x...)`
// hex-literal *constructor calls* -- its own test suite has an explicit
// case "does not flag named Color constants (e.g. Colors.white)" -- so it
// structurally never inspects `Colors.grey` / `Colors.white` prefixed-
// identifier static field access regardless of fix-or-no-fix, and
// `dart run custom_lint` cannot currently discover this project anyway
// (AUD-guardrails-03; see docs/coding-standards.md "custom_lint toolchain
// status" and learning_tracker/CLAUDE.md's Layering Rules note -- a green
// custom_lint run is never a trustworthy signal here). This test is the
// live, in-repo checker that actually exercises the finding's real claim
// ("every other color reference in this batch routes through
// context.colors.brand*/Theme.of(context).colorScheme.*"; these 2 files no
// longer contain a bare `Colors.<name>` reference) rather than relying on a
// rule that was never going to fire for this violation class.
//
// RED before the fix: this test found 1 hit in hierarchy_selection_panel.dart
// (Colors.grey) and 2 hits in text_display_screen.dart (Colors.white x2).
// GREEN after the fix: 0 hits in both files.

@Tags(['content_browsing', 'aud_content_browsing_08'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no bare Colors.<name> literal in hierarchy_selection_panel.dart or '
      'text_display_screen.dart (AUD-content_browsing-08)', () {
    const paths = [
      'lib/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart',
      'lib/features/content_browsing/presentation/screens/text_display_screen.dart',
    ];

    // `\b` before `Colors` excludes `context.colors.*` (no word boundary
    // between the 'p' and 'C' of "AppColors") while still matching a
    // bare `Colors.<name>` reference.
    final colorsLiteral = RegExp(r'\bColors\.\w+');
    final violations = <String>[];

    for (final path in paths) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must exist');

      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip comment-only lines so the finding's own explanatory
        // comments (which necessarily name `Colors.grey`/`Colors.white`
        // when describing what was removed) don't self-trigger.
        if (line.trim().startsWith('//')) continue;
        if (colorsLiteral.hasMatch(line)) {
          violations.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found raw Colors.<name> literals outside theme.colorScheme.* '
          '-- use a theme token instead (AUD-content_browsing-08):\n'
          '${violations.join('\n')}',
    );
  });
}
