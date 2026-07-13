// AUD-t-cross-08 — profiles _buildApp/_buildAppLoading/_buildAppError test
// helpers must not leak the UserDatabase they create.
//
// drift_memory.dart's own contract says callers MUST `await db.close()` in
// `tearDown` to free the native sqlite3 resources. In these 3 files,
// _buildApp (and the db-parameter-less _buildAppLoading/_buildAppError in
// parent_track_management_screen_l1_test.dart) construct a fresh
// `inMemoryDb()` whenever the optional `db:` is omitted — and the caller has
// no reference to that database, so nothing can ever close it.
//
// This is a source-level regression test rather than a runtime widget test:
// "does this function register cleanup for the database it creates?" is a
// structural property of the helper, not an externally observable
// input/output difference of any single test run — the leaked native handle
// is exactly the kind of defect that does NOT show up as a widget-test
// assertion failure (that's the whole reason it shipped unnoticed across ~30
// call sites). It fails red against the pre-fix source (none of these
// _buildApp*/… variants required `db:` or called `addTearDown` to close a
// database they created) and passes green once each variant does one or the
// other, per the finding's acceptance criterion.

@Tags(['profiles', 'aud_t_cross_08'])
library;

import 'dart:io';

import 'package:test/test.dart';

/// (file, function name) pairs AUD-t-cross-08 named as leaking sites.
const _targets = [
  (
    file:
        'test/features/profiles/presentation/screens/parent_settings_screen_l1_test.dart',
    function: '_buildApp',
  ),
  (
    file:
        'test/features/profiles/presentation/screens/parent_track_management_screen_l1_test.dart',
    function: '_buildApp',
  ),
  (
    file:
        'test/features/profiles/presentation/screens/parent_track_management_screen_l1_test.dart',
    function: '_buildAppLoading',
  ),
  (
    file:
        'test/features/profiles/presentation/screens/parent_track_management_screen_l1_test.dart',
    function: '_buildAppError',
  ),
  (
    file:
        'test/features/profiles/presentation/screens/ts14_parent_track_management_copy_test.dart',
    function: '_buildApp',
  ),
];

void main() {
  for (final target in _targets) {
    test('AUD-t-cross-08: ${target.file} ${target.function}() requires db: or '
        'closes the database it creates', () {
      final file = File(target.file);
      expect(
        file.existsSync(),
        isTrue,
        reason: '${target.file} not found — run from learning_tracker/.',
      );
      // Comments (e.g. "the caller's responsibility") can contain
      // apostrophes that would otherwise be misread as opening a string
      // literal by the paren/brace matcher below, desyncing its depth
      // count. Stripping first (spaces replace comment chars 1:1, so
      // offsets stay stable) avoids that.
      final source = _stripComments(file.readAsStringSync());

      final span = _extractFunctionSpan(source, target.function);
      expect(
        span,
        isNotNull,
        reason:
            'Could not locate ${target.function}( in ${target.file} — has '
            'it been renamed? Update this regression test.',
      );

      final requiresDb = RegExp(
        r'required\s+UserDatabase\s+db\s*,',
      ).hasMatch(span!.signature);

      // Any addTearDown(...) call whose argument chain reaches a .close —
      // e.g. `addTearDown(resolvedDb.close);` or
      // `addTearDown(() => database.close());`.
      final registersCleanup = RegExp(
        r'addTearDown\([^;]*\.close',
      ).hasMatch(span.body);

      expect(
        requiresDb || registersCleanup,
        isTrue,
        reason:
            'AUD-t-cross-08: ${target.function} in ${target.file} must '
            'either make db: a required parameter (forcing the caller to '
            'own+close it) or call addTearDown to close the database it '
            'creates when db: is omitted — otherwise every call site that '
            'omits db: leaks a native Drift handle (drift_memory.dart: '
            '"Callers MUST await db.close() in tearDown").',
      );
    });
  }
}

class _FunctionSpan {
  _FunctionSpan(this.signature, this.body);

  /// The parameter-list text, including the enclosing parens.
  final String signature;

  /// The text between the function's outermost `{` and its matching `}`.
  final String body;
}

/// Finds the first top-level occurrence of `functionName(` in [source] and
/// returns its parameter-list text plus its `{...}` body. Mirrors
/// `tool/check_dao_stateerror_messages.dart`'s `_extractMethodBody` +
/// `_matchingDelimiter` (duplicated, not shared, per that file's own
/// precedent for small single-purpose parsing helpers).
_FunctionSpan? _extractFunctionSpan(String source, String functionName) {
  final sigMatch = RegExp(
    '\\b${RegExp.escape(functionName)}\\s*\\(',
  ).firstMatch(source);
  if (sigMatch == null) return null;

  final paramListOpenParen = sigMatch.end - 1;
  final paramListCloseParen = _matchingDelimiter(
    source,
    paramListOpenParen,
    '(',
    ')',
  );
  if (paramListCloseParen == null) return null;

  final signature = source.substring(
    paramListOpenParen,
    paramListCloseParen + 1,
  );

  final openBrace = source.indexOf('{', paramListCloseParen + 1);
  if (openBrace == -1) return null;
  final closeBrace = _matchingDelimiter(source, openBrace, '{', '}');
  if (closeBrace == null) return null;

  return _FunctionSpan(signature, source.substring(openBrace + 1, closeBrace));
}

/// Blanks out `//` and `/* */` comments (replacing non-newline characters
/// with spaces so offsets are preserved), leaving string literal contents
/// untouched. Duplicated from (not shared with)
/// `tool/check_dao_stateerror_messages.dart`'s helper of the same name.
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
/// matching closing delimiter, skipping over string literals and tracking
/// only this pair's nesting depth.
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
