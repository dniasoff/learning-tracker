/// EH-5 DAO-layer pre-formatted-message checker — AUD-core-database-14.
///
/// AUD-core-database-14 replaced 4 raw, pre-formatted English `StateError`
/// messages in the DAO layer with a stable [DaoErrorCode] carried on
/// [DaoInvariantError] (`lib/core/database/daos/dao_invariant_error.dart`).
/// Its own acceptance criterion names the Rule-0 checker to add: "a
/// grep-based Rule-0 check... to catch new pre-formatted messages in the
/// DAO layer." The AC's literal suggested pattern
/// (`grep -rn "StateError('[A-Z]" lib/core/database/`) is a single-line
/// grep that does not actually match this codebase's formatting (every
/// fixed site wrapped its message on the following line, e.g.
/// `throw StateError(\n  'Cannot ...',\n)`) — this script implements the
/// same intent (no `StateError(` construction reappearing in the 4 fixed
/// call sites) without that formatting fragility.
///
/// **Scope (Rule 0 — start scoped, expand later; mirrors the DB-2/DB-3/EH-3
/// scoped-checker precedent in this codebase):** exactly the 4 (file,
/// method) pairs this finding fixed. `ActiveCurriculumDao.archiveByProfile`
/// (same file as one fixed site) carries the identical unfixed
/// `StateError('Cannot deactivate the last active curriculum for this
/// profile')` message — out of scope for AUD-core-database-14 (not named by
/// its evidence) — a whole-file or whole-directory scope would immediately
/// fail the audit gate on that unrelated, un-named site; widening this
/// checker (and fixing that sibling) is a follow-up, not part of this fix.
///
/// Usage:
///   dart run tool/check_dao_stateerror_messages.dart
///
/// Exit codes:
///   0 — none of the 4 fixed methods construct a StateError
///   1 — one or more regressed to StateError construction (prints file:line)
library;

import 'dart:io';

/// (file, method-or-static-function name) pairs this finding fixed.
const _targets = [
  (
    file: 'lib/core/database/daos/active_curriculum_dao.dart',
    method: 'deactivateByProfile',
  ),
  (
    file: 'lib/core/database/daos/learning_ledger_dao.dart',
    method: 'insertEntry',
  ),
  (
    file: 'lib/core/database/daos/study_day_config_dao.dart',
    method: 'seedDefaultsForTrack',
  ),
  (file: 'lib/core/database/daos/user_profile_dao.dart', method: 'fromDb'),
];

void main() {
  final violations = <String>[];

  for (final target in _targets) {
    final file = File(target.file);
    if (!file.existsSync()) {
      stderr.writeln('ERROR: scoped file not found: ${target.file}');
      exit(1);
    }
    final content = file.readAsStringSync();
    // Comments (e.g. "The companion's ulid must be present...") can contain
    // apostrophes that would otherwise be misread as opening a string
    // literal by the paren/brace matcher below, desyncing its depth count.
    // Stripping first (spaces replace comment chars 1:1, so line numbers —
    // computed against the ORIGINAL content below — stay accurate) avoids
    // that; mirrors `tool/check_db_transactions.dart`'s `_stripComments`.
    final stripped = _stripComments(content);
    final body = _extractMethodBody(stripped, target.method);
    if (body == null) {
      stderr.writeln(
        'ERROR: could not locate method ${target.method}( in ${target.file} '
        '— has it been renamed? Update this checker\'s _targets list.',
      );
      exit(1);
    }

    final match = RegExp(r'StateError\(').firstMatch(body.text);
    if (match == null) continue;
    final line =
        '\n'.allMatches(content.substring(0, body.start + match.start)).length +
        1;
    violations.add(
      '${target.file}:$line: ${target.method}( regressed to constructing a '
      'StateError — EH-5 requires a stable DaoErrorCode on DaoInvariantError '
      '(dao_invariant_error.dart) instead of a pre-formatted English '
      'message (AUD-core-database-14).',
    );
  }

  if (violations.isNotEmpty) {
    stderr.writeln('EH-5 DAO pre-formatted-message check FAILED:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'EH-5 DAO pre-formatted-message check passed — none of the '
    'AUD-core-database-14 fixed methods construct a StateError.',
  );
}

class _MethodBody {
  _MethodBody(this.text, this.start);
  final String text;
  final int start;
}

/// Finds the first `{...}` block following the first occurrence of
/// `methodName(` in [source] — the method/static-function's body (works for
/// both a regular `{ ... }` block body and a `=>`-bodied method whose
/// expression itself opens with `{` (e.g. a `switch` expression), since
/// either way the first `{` after the signature's PARAMETER LIST starts the
/// body we care about.
///
/// Skips the parameter list itself via paren-depth tracking so a
/// `{required ...}` named-parameter block (which opens its own `{...}`
/// before the real body does) is never mistaken for the body.
_MethodBody? _extractMethodBody(String source, String methodName) {
  final sigMatch = RegExp(
    '\\b${RegExp.escape(methodName)}\\s*\\(',
  ).firstMatch(source);
  if (sigMatch == null) return null;

  // sigMatch consumed the opening '(' of the parameter list — find its
  // matching ')', which may itself contain a nested `{...}` (named params).
  final paramListOpenParen = sigMatch.end - 1;
  final paramListCloseParen = _matchingDelimiter(
    source,
    paramListOpenParen,
    '(',
    ')',
  );
  if (paramListCloseParen == null) return null;

  final openBrace = source.indexOf('{', paramListCloseParen + 1);
  if (openBrace == -1) return null;

  final closeBrace = _matchingDelimiter(source, openBrace, '{', '}');
  if (closeBrace == null) return null;

  return _MethodBody(
    source.substring(openBrace + 1, closeBrace),
    openBrace + 1,
  );
}

/// Blanks out `//` and `/* */` comments (replacing non-newline characters
/// with spaces so line numbers are preserved), while leaving string literal
/// contents untouched. Duplicated from (not shared with)
/// `tool/check_db_transactions.dart`'s helper of the same name — both are
/// single-file `dart run` scripts with no shared library target.
String _stripComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';

    if (c == "'" || c == '"') {
      final quote = c;
      final triple =
          i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      final closer = triple ? quote * 3 : quote;
      buffer.write(source.substring(i, i + closer.length));
      i += closer.length;
      while (i < n && !source.startsWith(closer, i)) {
        if (source[i] == r'\' && i + 1 < n) {
          buffer.write(source[i]);
          buffer.write(source[i + 1]);
          i += 2;
          continue;
        }
        buffer.write(source[i]);
        i++;
      }
      if (i < n) {
        buffer.write(closer);
        i += closer.length;
      }
      continue;
    }

    if (c == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }

    if (c == '/' && next == '*') {
      i += 2;
      while (i < n &&
          !(source[i] == '*' && i + 1 < n && source[i + 1] == '/')) {
        buffer.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      i += 2; // consume closing */
      continue;
    }

    buffer.write(c);
    i++;
  }
  return buffer.toString();
}

/// Given the index of an opening delimiter, returns the index of its
/// matching closing delimiter (tracking only THIS pair's nesting depth — a
/// `{...}` named-parameter block nested inside the `()` being scanned, or a
/// `(...)` call nested inside a `{...}` body, is safely ignored since it
/// contributes no unbalanced `(`/`)` of its own) and skipping over string
/// literals. Returns null if unmatched. Mirrors
/// `tool/check_db3_batch_inserts.dart`'s helper of the same name.
int? _matchingDelimiter(String s, int openIndex, String open, String close) {
  var depth = 0;
  var i = openIndex;
  while (i < s.length) {
    final c = s[i];
    if (c == "'" || c == '"') {
      final quote = c;
      i++;
      while (i < s.length && s[i] != quote) {
        if (s[i] == r'\' && i + 1 < s.length) {
          i += 2;
          continue;
        }
        i++;
      }
      i++;
      continue;
    }
    if (c == open) depth++;
    if (c == close) {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return null;
}
