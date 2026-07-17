/// `Positioned(left:/right:)` RTL-violation checker — AX-1 (AUD-profiles-23).
///
/// Root-Makefile audit check [10/12] (`tool/check_edgeinsets_rtl.dart`,
/// AUD-profiles-18) only ever scanned `EdgeInsets.only(left:/right:)`. A
/// plain `Positioned(left: ...)` / `Positioned(right: ...)` is the same
/// class of AX-1 bug — this app is RTL/Hebrew, so a physical `right:` pins a
/// widget to the LEADING edge (not the trailing one) in RTL — but went
/// completely uncaught by that grep or by any of the other `make audit`
/// checks. See
/// docs/audits/standards-audit-2026-07-03/delivery/findings/AUD-profiles-23.json.
///
/// This script scans every `.dart` file under `learning_tracker/lib/`
/// (excluding generated `.g.dart` / `.freezed.dart` files) for `Positioned(
/// ... )` call sites — regardless of how the arguments are wrapped across
/// lines — whose argument list contains a `left:` or `right:` named
/// parameter, and fails with `file:line` on each hit.
///
/// - `PositionedDirectional(...)` is never matched: the header regex
///   requires `Positioned` to be followed immediately (optional whitespace)
///   by `(`, and `PositionedDirectional` is followed by `Directional(`
///   instead.
/// - `AnimatedPositioned(...)` (or any other `*Positioned(`) is never
///   matched either: the header regex requires the character immediately
///   before `Positioned` to NOT be an identifier character, ruling out a
///   preceding `d` (as in `Animate`+`d`).
/// - `//` line-comments are stripped (their text replaced with spaces, so
///   line numbers stay stable) before scanning, so prose that documents an
///   already-fixed site — e.g. an explanatory comment that spells out
///   `Positioned(right:)` while describing its own prior AX-1 fix — is never
///   mistaken for a live violation.
///
/// Paren-balances from the call's opening `(` to find its true closing `)`,
/// so a nested call in an argument does not truncate the scanned argument
/// list early. `left:`/`right:` are matched with word boundaries so a named
/// parameter like `alignRight:` is never mistaken for the banned `right:`
/// (same precision as `tool/check_edgeinsets_rtl.dart`'s `_leftOrRight`).
///
/// Broadening this check surfaces pre-existing debt beyond AUD-profiles-23's
/// own evidence site (`tutored_children_section.dart:156`) — further
/// `Positioned(left:/right:)` sites elsewhere in `lib/`, none named by this
/// finding. Per scope discipline (fix only the dispatched finding; adjacent
/// defects are follow-ups, not drive-by fixes) those pre-existing sites are
/// baselined below so this checker hard-fails on the AUD-profiles-23 site
/// (and on any *new* violation anywhere else) without turning `make audit`
/// red over debt this finding does not own. Mirrors the baseline/ratchet
/// pattern in `tool/check_empty_catch_blocks.dart` (AUD-app-06) and
/// `tool/check_edgeinsets_rtl.dart` (AUD-profiles-18). Shrink this set as
/// each site is fixed; never add to it for new code.
///
/// Usage:
///   dart run tool/check_positioned_rtl.dart
///
/// Exit codes:
///   0 — no non-baselined Positioned(left:/right:) violations found
///   1 — one or more found (prints file:line)
library;

import 'dart:io';

/// Pre-existing `Positioned(left:/right:)` sites this checker's broadened
/// (multi-line-aware) scan surfaces, none of them the AUD-profiles-23
/// evidence site — out of scope here.
const _baseline = <String>{
  'learning_tracker/lib/features/account/onboarding/presentation/screens/signup_screen.dart:559',
  'learning_tracker/lib/features/account/presentation/screens/sign_in_screen.dart:293',
  'learning_tracker/lib/features/account/presentation/widgets/email_verification_confirm_panel.dart:102',
  'learning_tracker/lib/features/content_browsing/presentation/screens/text_display_screen.dart:544',
  'learning_tracker/lib/features/dashboard/presentation/widgets/child_points_rewards_tab_card.dart:56',
  'learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_all_caught_up_card.dart:56',
  'learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart:238',
  'learning_tracker/lib/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart:276',
  'learning_tracker/lib/features/onboarding/presentation/widgets/intro_daily_plan_page.dart:28',
  'learning_tracker/lib/features/onboarding/presentation/widgets/intro_daily_plan_page.dart:94',
  'learning_tracker/lib/features/onboarding/presentation/widgets/intro_mishna_page.dart:27',
  'learning_tracker/lib/features/onboarding/presentation/widgets/intro_mishna_page.dart:52',
  'learning_tracker/lib/features/onboarding/presentation/widgets/intro_mishna_page.dart:101',
  'learning_tracker/lib/features/onboarding/presentation/widgets/intro_mishna_page.dart:118',
  'learning_tracker/lib/features/onboarding/presentation/widgets/intro_rewards_page.dart:55',
  'learning_tracker/lib/features/onboarding/presentation/widgets/intro_rewards_page.dart:72',
  'learning_tracker/lib/features/profiles/presentation/widgets/add_profile_mode_pick_card.dart:92',
  'learning_tracker/lib/features/profiles/presentation/widgets/profile_card.dart:122',
  'learning_tracker/lib/features/settings/presentation/utils/account_actions.dart:79',
  'learning_tracker/lib/features/tracks/setup/presentation/steps/step_starting_position_calendar.dart:267',
};

void main() {
  final libDir = Directory('learning_tracker/lib');
  if (!libDir.existsSync()) {
    stderr.writeln(
      'ERROR: learning_tracker/lib not found — run from the repo root',
    );
    exit(2);
  }

  final dartFiles =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final allHits = <String>[];
  for (final file in dartFiles) {
    allHits.addAll(_findViolations(file.path, file.readAsStringSync()));
  }

  final baselined = allHits.where((h) => _baseline.contains(_fileLine(h)));
  final violations = allHits.where((h) => !_baseline.contains(_fileLine(h)));

  if (baselined.isNotEmpty) {
    stdout.writeln(
      '${baselined.length} baselined pre-existing hit(s) (not '
      'AUD-profiles-23 scope, suppressed):',
    );
    baselined.forEach(stdout.writeln);
    stdout.writeln();
  }

  if (violations.isNotEmpty) {
    violations.forEach(stdout.writeln);
    stdout.writeln();
    stdout.writeln(
      '${violations.length} non-baselined Positioned(left:/right:) '
      'violation(s) found.',
    );
    exit(1);
  }

  stdout.writeln(
    'check_positioned_rtl OK — no non-baselined Positioned(left:/right:) '
    'violations.',
  );
}

/// Extracts the leading `path:line` prefix from a `_findViolations` hit
/// string for baseline matching.
String _fileLine(String hit) {
  final secondColon = hit.indexOf(':', hit.indexOf(':') + 1);
  return hit.substring(0, secondColon);
}

/// Matches a `Positioned(` call header. The negative lookbehind for a
/// preceding identifier character rules out `AnimatedPositioned(` (and any
/// other `*Positioned(`); requiring `(` immediately after (optional
/// whitespace) rules out `PositionedDirectional(` (followed by
/// `Directional(`, not `(`).
final _positionedHeader = RegExp(r'(?<![A-Za-z0-9_])Positioned\s*\(');

/// Matches a `left:` or `right:` named parameter (word-bounded so
/// `alignRight:` is never mistaken for it).
final _leftOrRight = RegExp(r'\b(left|right)\s*:');

/// Strips the text of `//` line-comments (replacing it with spaces so line
/// numbers are unaffected) so prose documenting the banned pattern is never
/// mistaken for a live violation.
String _stripLineComments(String content) {
  final buffer = StringBuffer();
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final idx = line.indexOf('//');
    buffer.write(idx == -1 ? line : line.substring(0, idx));
    if (i != lines.length - 1) buffer.write('\n');
  }
  return buffer.toString();
}

/// Scans [content] (the text of [path]) for `Positioned(...)` calls whose
/// argument list — found via paren-balancing, so nested calls inside an
/// argument don't truncate it early — contains a `left:`/`right:` named
/// parameter. Returns one `file:line: <reason>` string per violation.
List<String> _findViolations(String path, String content) {
  final results = <String>[];
  final codeOnly = _stripLineComments(content);

  for (final match in _positionedHeader.allMatches(codeOnly)) {
    final openParenIndex = match.end - 1;
    final closeParenIndex = _matchingParen(codeOnly, openParenIndex);
    if (closeParenIndex == -1) continue; // unterminated — leave to analyzer

    final args = codeOnly.substring(openParenIndex + 1, closeParenIndex);
    if (_leftOrRight.hasMatch(args)) {
      final line =
          '\n'.allMatches(codeOnly.substring(0, match.start)).length + 1;
      results.add(
        '$path:$line: Positioned(left:/right:) — use '
        'PositionedDirectional(start:/end:) instead (AX-1)',
      );
    }
  }

  return results;
}

/// Returns the index of the `)` that balances the `(` at [openParenIndex],
/// accounting for nested parens (e.g. a function call inside an argument).
/// Returns -1 if unterminated.
int _matchingParen(String content, int openParenIndex) {
  var depth = 0;
  for (var i = openParenIndex; i < content.length; i++) {
    final char = content[i];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}
