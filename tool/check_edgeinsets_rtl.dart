/// `EdgeInsets.only(left:/right:)` RTL-violation checker — AX-1
/// (AUD-profiles-18).
///
/// Root-Makefile audit check [10/12] used a single-line grep
/// (`EdgeInsets\.only([^)]*(left|right):`) which is blind to the common
/// `dart format` output shape where `EdgeInsets.only(` opens on its own line
/// and `left:`/`right:` land on subsequent lines — exactly the shape at
/// `learning_tracker/lib/features/profiles/presentation/screens/parent_track_management_screen.dart:120`,
/// which shipped past `make audit` undetected. See
/// docs/audits/standards-audit-2026-07-03/delivery/findings/AUD-profiles-18.json.
///
/// This script scans every `.dart` file under `learning_tracker/lib/`
/// (excluding generated `.g.dart` / `.freezed.dart` files) for
/// `EdgeInsets.only(...)` call sites — regardless of how the arguments are
/// wrapped across lines — whose argument list contains a `left:` or `right:`
/// named parameter, and fails with `file:line` on each hit.
/// `EdgeInsetsDirectional.only(...)` is never matched (the header requires
/// the literal substring `EdgeInsets.only(`, and `EdgeInsetsDirectional`
/// does not contain that substring).
///
/// Paren-balances from the call's opening `(` to find its true closing `)`,
/// so a nested call in an argument (e.g.
/// `bottom: 16 + MediaQuery.viewInsetsOf(ctx).bottom`) does not truncate the
/// scanned argument list early.
///
/// Broadening this check surfaces pre-existing debt beyond AUD-profiles-18's
/// own evidence site — further multi-line `EdgeInsets.only(left:/right:)`
/// sites elsewhere in `lib/`, none of them named by this finding. Per scope
/// discipline (fix only the dispatched finding; adjacent defects are
/// follow-ups, not drive-by fixes) those pre-existing sites are baselined
/// below so this checker hard-fails on the AUD-profiles-18 site (and on any
/// *new* violation anywhere else) without turning `make audit` red over
/// debt this finding does not own. Mirrors the baseline/ratchet pattern in
/// `tool/check_empty_catch_blocks.dart` (AUD-app-06). Shrink this set as
/// each site is fixed; never add to it for new code.
///
/// `track_management_body.dart:134` was one such baselined site; it has
/// since been fixed by AUD-tracks-13 and removed from the baseline below.
///
/// Usage:
///   dart run tool/check_edgeinsets_rtl.dart
///
/// Exit codes:
///   0 — no non-baselined `EdgeInsets.only(left:/right:)` violations found
///   1 — one or more found (prints file:line)
library;

import 'dart:io';

/// Pre-existing multi-line `EdgeInsets.only(left:/right:)` sites this
/// checker's broadened (multi-line-aware) scan newly surfaces, none of
/// them the AUD-profiles-18 evidence site — out of scope here.
///
/// `track_management_body.dart:134` was baselined here by AUD-profiles-18
/// and has since been fixed by AUD-tracks-13 (replaced with
/// `EdgeInsetsDirectional.only`), so it has been removed from this set.
const _baseline = <String>{
  'learning_tracker/lib/features/gamification/presentation/screens/reward_configuration_screen.dart:111',
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
      'AUD-profiles-18 scope, suppressed):',
    );
    baselined.forEach(stdout.writeln);
    stdout.writeln();
  }

  if (violations.isNotEmpty) {
    violations.forEach(stdout.writeln);
    stdout.writeln();
    stdout.writeln(
      '${violations.length} non-baselined EdgeInsets.only(left:/right:) '
      'violation(s) found.',
    );
    exit(1);
  }

  stdout.writeln(
    'check_edgeinsets_rtl OK — no non-baselined EdgeInsets.only'
    '(left:/right:) violations.',
  );
}

/// Extracts the leading `path:line` prefix from a `_findViolations` hit
/// string for baseline matching.
String _fileLine(String hit) {
  final secondColon = hit.indexOf(':', hit.indexOf(':') + 1);
  return hit.substring(0, secondColon);
}

/// Matches an `EdgeInsets.only(` call header up to (and including) its
/// opening paren. Never matches `EdgeInsetsDirectional.only(` — that
/// identifier does not contain the literal substring `EdgeInsets.only(`.
final _onlyHeader = RegExp(r'EdgeInsets\.only\s*\(');

/// Matches a `left:` or `right:` named parameter.
final _leftOrRight = RegExp(r'\b(left|right)\s*:');

/// Scans [content] (the text of [path]) for `EdgeInsets.only(...)` calls
/// whose argument list — found via paren-balancing, so nested calls inside
/// an argument don't truncate it early — contains a `left:`/`right:` named
/// parameter. Returns one `file:line: <reason>` string per violation.
List<String> _findViolations(String path, String content) {
  final results = <String>[];

  for (final match in _onlyHeader.allMatches(content)) {
    final openParenIndex = match.end - 1;
    final closeParenIndex = _matchingParen(content, openParenIndex);
    if (closeParenIndex == -1) continue; // unterminated — leave to analyzer

    final args = content.substring(openParenIndex + 1, closeParenIndex);
    if (_leftOrRight.hasMatch(args)) {
      final line =
          '\n'.allMatches(content.substring(0, match.start)).length + 1;
      results.add(
        '$path:$line: EdgeInsets.only(left:/right:) — use '
        'EdgeInsetsDirectional.only(start:/end:) instead (AX-1)',
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
