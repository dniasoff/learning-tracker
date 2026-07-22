// AUD-notifications-12 — no hardcoded Color(0x...) hex literals anywhere
// under lib/features/notifications/.
//
// Finding: notifications_screen.dart and device_notification_toggle.dart
// mix AppColors/AppTheme tokens with 15 raw `Color(0xFF...)` / `Color(0x...)`
// hex literals (icon tints/backgrounds, card shadow, text tones, badge
// background, and the device-level OS toggle's track colours) instead of
// referencing named AppColors constants. device_notification_toggle.dart in
// particular imported no theme tokens at all before this fix. All 15 sites
// were extracted into the "Notifications settings screen (AUD-notifications-12)"
// section of lib/core/theme/app_colors.dart; both files now import and
// reference those named constants instead of embedding hex values.
//
// Acceptance criterion (verbatim): "Once custom_lint is fixed (tracked
// separately), dart run custom_lint reports zero
// no_color_literal_outside_theme hits in lib/features/notifications/." That
// scope is the whole feature directory, not just the 2 files named in the
// finding's evidence, so this checker scans the full directory tree rather
// than a fixed file list.
//
// The custom_lint `no_color_literal_outside_theme` rule (packages/
// custom_lints/lib/src/rules/no_color_literal_outside_theme.dart) is the
// canonical Rule-0 checker for this pattern, but `dart run custom_lint`
// cannot currently discover this project without an analysis_options.yaml
// plugin marker that breaks the `dart analyze --fatal-infos` hard gate
// (AUD-guardrails-03 — see docs/coding-standards.md "custom_lint toolchain
// status"), so its CLI exit code cannot be trusted as a live gate. This test
// is the AC-named checker that CAN run live in CI/`make test`: it mirrors
// the rule's own detection logic (a `Color(0x...)` hex-literal constructor
// call) AND the rule's own whitelist (skip `lib/core/theme/`, `*.g.dart`,
// `*.freezed.dart`), scanning the entire lib/features/notifications/
// directory so it cannot go stale/green again if a new file with a raw
// literal is added later. It doubles as this finding's red-first regression
// guard: scanning the pre-fix tree found all 15 literals across the 2
// evidence files; the tree is clean now that both reference the shared
// theme layer (AppPalette, via `context.colors.*`).

@Tags(['notifications', 'aud_notifications_12'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no Color(0x...) hex literals anywhere under '
      'lib/features/notifications/ (AUD-notifications-12 AC scope, not just '
      'the finding\'s 2 evidence files)', () {
    const dirPath = 'lib/features/notifications';
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
          'Found hardcoded Color(0x...) hex literals outside the theme layer '
          'somewhere under $dirPath/ — extract them into '
          'lib/core/theme/app_palette.dart instead:\n${violations.join('\n')}',
    );
  });
}
