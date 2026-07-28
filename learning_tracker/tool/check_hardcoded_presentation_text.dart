/// Hardcoded presentation-text checker — AUD-account-05 (AX-2 Rule-0 gap).
///
/// docs/coding-standards.md's AX-2 rule documents its enforcement as:
///   "[Pending] custom_lint flagging string literals passed to `Text(`/
///   `SnackBar(content:`/`Tooltip(message:`."
/// No such checker existed. This script closes the `Text()`/`TextSpan()`
/// slice of that gap (the slice AUD-account-05's acceptance criteria name):
/// it scans every `.dart` file under `lib/features/**/presentation/**`
/// (excluding generated `.g.dart`/`.freezed.dart`) for a string literal
/// passed as `Text(`'s first positional argument, or as `TextSpan(...)`'s
/// `text:` argument, that is NOT purely interpolation/escapes/punctuation —
/// i.e. it still contains a Latin letter once `${...}`/`$identifier`
/// interpolation and `\x` escape sequences are stripped. Such a literal is
/// English shipped straight into the Hebrew build, and `make arb-parity`
/// cannot catch it because it never became an ARB key.
///
/// AUD-account-05's own evidence
/// (email_verification_confirm_panel.dart — the 'Open Email' / 'Send Again'
/// / 'Cancel' literals and the 'Confirm Your Email' default) is the
/// deliberately-broken fixture this checker was built and proven against:
/// running it against that file's pre-fix revision
/// (`git show <pre-fix-rev>:lib/features/account/presentation/widgets/email_verification_confirm_panel.dart`)
/// reports all four hits; running it against the fixed tree reports none.
///
/// Scope discipline / baseline: broadening AX-2 enforcement to the whole
/// presentation layer newly surfaces pre-existing violations this finding
/// does not name and is not scoped to mass-fix (see AUD-account-05's "scope
/// discipline" doctrine). Those sites are baselined below, exactly as
/// `tool/check_empty_catch_blocks.dart` (AUD-app-06) does — the checker
/// still hard-fails on any *new* violation, including a regression of the
/// exact sites this finding fixes. Shrink this set as each site is fixed;
/// never add to it for new code.
///
/// Usage (from `learning_tracker/`):
///   dart run tool/check_hardcoded_presentation_text.dart
///
/// Exit codes:
///   0 — no non-baselined violations found
///   1 — one or more found (prints file:line)
library;

import 'dart:io';

/// Pre-existing hardcoded literals this checker's broadened pattern newly
/// surfaces, none of them AUD-account-05 evidence sites — out of scope here.
/// Captured by running this checker against the tree once written (see the
/// class doc above); shrink this set as each site is fixed under its own
/// finding, never add to it for new code.
///
/// Re-captured against current dev tip while recovering AUD-account-05 (the
/// original commit's baseline predated a large amount of unrelated
/// intervening i18n cleanup, which fixed most of the originally-baselined
/// sites and shifted line numbers on the rest — see AUD-account-05's ledger
/// note for the re-scan).
const _baseline = <String>{
  'lib/features/content_browsing/presentation/widgets/review_count_badge.dart:22',
  'lib/features/dashboard/presentation/widgets/curriculum_summary_card.dart:76',
  'lib/features/dashboard/presentation/widgets/curriculum_summary_card.dart:89',
  'lib/features/dashboard/presentation/widgets/curriculum_summary_card.dart:101',
  'lib/features/gamification/presentation/widgets/points_display_widget.dart:98',
  'lib/features/onboarding/presentation/screens/bulk_mark_screen.dart:776',
  'lib/features/onboarding/presentation/widgets/intro_mishna_page.dart:66',
  // AUD-scheduler-08: pace_indicator.dart (the hardcoded-English site this
  // entry baselined) deleted as dead code — zero production consumers, see
  // that finding's fix commit. Entry removed rather than left dangling.
  // AUD-sacred_time-08: re-pinned from :302 — the SacredTimeSettingsCard
  // Parent-PIN-gate wiring (sacredTimeLocationPinGuardRequiredProvider watch
  // + pinGuardRequired/activeProfileId passed to the card) added near the
  // top of this file's DEVICE section pushed this SAME pre-existing,
  // still-unaddressed AX-2 hit down by 16 lines. No content at this site
  // changed.
  // Theme migration (AppPalette): routing this screen's colours through
  // context.colors collapsed a two-line AppTheme reference above this
  // site, moving this SAME pre-existing, still-unaddressed AX-2 hit up
  // by 1 line. No content at this site changed.
  // Dark-mode legibility burndown (owner decision #2): re-pinned from
  // :317 — a doc comment added above the "Send Diagnostic Logs" tile's
  // iconBackground (explaining its brandCreamSoft dark-mode fix) pushed
  // this SAME pre-existing, still-unaddressed AX-2 hit down by 8 lines.
  // No content at this site changed.
  'lib/features/settings/presentation/screens/settings_screen.dart:325',
  // AUD-t-track_setup-01: re-pinned from :513 — the testability-seam
  // extraction (smartDefaultTrackName + its imports, added near the top of
  // this file so _getSmartDefault can delegate to a ref-free pure function)
  // pushed this SAME pre-existing, still-unaddressed AX-2 hit down by 43
  // lines. No content at this site changed.
  // AUD-scheduler-14: re-pinned from :556 — collapsing two deep
  // features/scheduler/ imports into one features/scheduler/scheduler.dart
  // barrel import moved this SAME pre-existing, still-unaddressed AX-2 hit
  // up by 1 line. No content at this site changed.
  // Theme migration (AppPalette): as above — the colour-token rewrite
  // moved this SAME pre-existing, still-unaddressed AX-2 hit up by 1
  // line. No content at this site changed.
  // R5 bulk-mark-staleness fix: adding the completion_writer_providers.dart
  // import (so _applySelfPacedPriorCompletions can fire
  // completionCommittedProvider alongside onTrackChanged()) pushed this
  // SAME pre-existing, still-unaddressed AX-2 hit down by 1 line, :554 ->
  // :555. No content at this site changed.
  'lib/features/tracks/setup/presentation/screens/add_track_flow_screen.dart:555',
  'lib/features/tracks/setup/presentation/screens/track_management_hub_screen.dart:119',
  'lib/features/tracks/setup/presentation/steps/step_starting_position_calendar.dart:425',
};

void main() {
  final root = Directory('lib/features');
  if (!root.existsSync()) {
    stderr.writeln(
      'ERROR: lib/features not found — run from learning_tracker/',
    );
    exit(2);
  }

  final dartFiles =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.path.contains('/presentation/'))
          .where(
            (f) =>
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final allHits = <String>[];
  for (final file in dartFiles) {
    allHits.addAll(_findHardcodedLiterals(file.path, file.readAsStringSync()));
  }

  final baselined = allHits.where((h) => _baseline.contains(_fileLine(h)));
  final violations = allHits.where((h) => !_baseline.contains(_fileLine(h)));

  if (baselined.isNotEmpty) {
    stdout.writeln(
      '${baselined.length} baselined pre-existing hit(s) (not AUD-account-05 '
      'scope, suppressed):',
    );
    baselined.forEach(stdout.writeln);
    stdout.writeln();
  }

  if (violations.isNotEmpty) {
    violations.forEach(stdout.writeln);
    stdout.writeln();
    stdout.writeln(
      '${violations.length} non-baselined hardcoded Text()/TextSpan() '
      'literal(s) found (AX-2) — route through AppLocalizations/ARB.',
    );
    exit(1);
  }

  stdout.writeln(
    'check_hardcoded_presentation_text OK — no non-baselined hardcoded '
    'Text()/TextSpan() literals under lib/features/**/presentation/**.',
  );
}

/// Extracts the leading `path:line` prefix from a hit string for baseline
/// matching.
String _fileLine(String hit) {
  final secondColon = hit.indexOf(':', hit.indexOf(':') + 1);
  return hit.substring(0, secondColon);
}

final _textCall = RegExp(r'\bText\(');
final _textSpanCall = RegExp(r'\bTextSpan\(');
final _textParam = RegExp(r'\btext\s*:');

/// Scans [content] (the text of [path]) for `Text(<literal>` and
/// `TextSpan(..., text: <literal>` call sites whose literal argument
/// contains hardcoded (non-interpolation, non-punctuation) text. Returns one
/// `file:line: <reason>` string per violation.
List<String> _findHardcodedLiterals(String path, String content) {
  final results = <String>[];

  for (final match in _textCall.allMatches(content)) {
    final openParen = match.end - 1;
    final closeParen = _findMatchingParen(content, openParen);
    if (closeParen == -1) continue; // unterminated — leave to the analyzer
    final args = content.substring(openParen + 1, closeParen);
    final literal = _leadingStringLiteral(args);
    if (literal != null && _hasHardcodedText(literal)) {
      results.add(
        '$path:${_lineOf(content, match.start)}: hardcoded literal passed '
        "to Text(): '$literal' (AX-2)",
      );
    }
  }

  for (final match in _textSpanCall.allMatches(content)) {
    final openParen = match.end - 1;
    final closeParen = _findMatchingParen(content, openParen);
    if (closeParen == -1) continue;
    final args = content.substring(openParen + 1, closeParen);
    final textMatch = _textParam.firstMatch(args);
    if (textMatch == null) continue;
    final literal = _leadingStringLiteral(args.substring(textMatch.end));
    if (literal != null && _hasHardcodedText(literal)) {
      results.add(
        '$path:${_lineOf(content, match.start)}: hardcoded literal passed '
        "to TextSpan(text:): '$literal' (AX-2)",
      );
    }
  }

  return results;
}

int _lineOf(String content, int index) =>
    '\n'.allMatches(content.substring(0, index)).length + 1;

/// If [s], once leading whitespace is trimmed, begins with a quote
/// character, returns the literal's raw (still-escaped) contents.
/// Otherwise null — the argument is an expression/identifier, not a
/// literal, which is fine (it's presumably l10n- or variable-derived).
String? _leadingStringLiteral(String s) {
  var i = 0;
  while (i < s.length && _isWhitespace(s[i])) {
    i++;
  }
  if (i >= s.length) return null;
  final quote = s[i];
  if (quote != "'" && quote != '"') return null;
  final buffer = StringBuffer();
  i++;
  while (i < s.length && s[i] != quote) {
    buffer.write(s[i]);
    if (s[i] == r'\' && i + 1 < s.length) {
      i++;
      buffer.write(s[i]);
    }
    i++;
  }
  return buffer.toString();
}

bool _isWhitespace(String c) => c == ' ' || c == '\n' || c == '\t' || c == '\r';

/// True if [literal] contains a Latin letter once `${...}`/`$identifier`
/// interpolation and `\x` escape sequences are stripped — i.e. it carries
/// real, untranslated English text rather than pure interpolation or
/// punctuation (e.g. a bare `' · '` separator or `'$count'`).
bool _hasHardcodedText(String literal) {
  var stripped = literal.replaceAll(RegExp(r'\\.'), '');
  stripped = stripped.replaceAll(RegExp(r'\$\{[^}]*\}'), '');
  stripped = stripped.replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '');
  return RegExp('[A-Za-z]').hasMatch(stripped);
}

/// Finds the index of the `)` that matches the `(` at [openParenIndex],
/// skipping over parens that appear inside string literals.
int _findMatchingParen(String s, int openParenIndex) {
  var depth = 0;
  var i = openParenIndex;
  while (i < s.length) {
    final c = s[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    } else if (c == "'" || c == '"') {
      final quote = c;
      i++;
      while (i < s.length && s[i] != quote) {
        if (s[i] == r'\') i++;
        i++;
      }
    }
    i++;
  }
  return -1;
}
