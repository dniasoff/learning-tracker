/// EH-3 log-less-catch checker — AUD-profiles-16 (AC2).
///
/// EH-3 ("Never swallow an error: every `catch` rethrows, converts, or logs
/// through `AppLogger`") already has two checkers for the *empty*-body half:
/// the `empty_catches` analyzer lint and `make audit` check 9 (literally-empty
/// `catch (_) {}` bodies). Neither catches the comment-only shape this
/// finding found — `catch (_) { // no-op: cloud push failure is non-fatal }`
/// in `profile_repository_impl.dart` and `catch (_) { set(() => err = null); }`
/// in `add_profile_dialog.dart` — a catch whose body runs real code (or a
/// comment) but never logs and never rethrows.
///
/// This script closes that log-less gap: it finds every `catch (...) { ... }`
/// block in the scoped file(s) below and fails if the body contains neither
/// an `AppLogger`/`_log` call nor a `rethrow`.
///
/// **Scope (Rule 0 — start scoped, expand later; mirrors the
/// `check_eh3_log_less_catch.dart` precedent for AUD-sync-03 /
/// AUD-core-database-16):** the three files this finding's evidence named —
/// `profile_repository_impl.dart` and `add_profile_dialog.dart` (both fixed
/// by this finding) plus `profile_picker_screen.dart` (its own log-less catch
/// site was already removed wholesale by the unrelated AUD-profiles-04 fix,
/// before this finding was dispatched — kept in scope here purely as a
/// regression guard against a log-less catch being reintroduced there).
/// A generic lib/-wide `no_log_less_catch` custom_lint rule already exists
/// (AUD-onboarding-11, `packages/custom_lints/lib/src/rules/
/// no_log_less_catch.dart`) for once custom_lint itself is unblocked
/// (AUD-guardrails-03) — this script is the real, currently-runnable
/// enforcement for this finding's own files in the meantime. Widening this
/// script to all of `lib/` is real, larger follow-up work, intentionally NOT
/// attempted here.
///
/// Usage:
///   dart run tool/check_eh3_profiles_log_less_catch.dart
///
/// Exit codes:
///   0 — every catch in the scoped files logs or rethrows
///   1 — one or more log-less catch bodies found (prints file:line)
library;

import 'dart:io';

/// Files this finding's AC is scoped to. Add to this list (never widen the
/// underlying scan logic silently) as later findings burn down the same
/// pattern elsewhere — see the `check_eh3_log_less_catch.dart` precedent in
/// docs/coding-standards.md for the established shape of this ratchet.
const _scopedFiles = [
  'lib/features/profiles/data/repositories/profile_repository_impl.dart',
  'lib/features/profiles/presentation/widgets/add_profile_dialog.dart',
  'lib/features/profiles/presentation/screens/profile_picker_screen.dart',
];

/// Any of these substrings appearing in a catch body counts as "logs the
/// error" for this checker's purposes. `_log` covers this codebase's common
/// `final _log = AppLogger.instance;` top-level alias (used throughout
/// profile_repository_impl.dart) in addition to a direct `AppLogger.instance`
/// call (used in add_profile_dialog.dart).
const _logMarkers = ['AppLogger', '_log', 'rethrow'];

void main() {
  final violations = <String>[];

  for (final path in _scopedFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('ERROR: scoped file not found: $path');
      exit(1);
    }
    final content = _stripComments(file.readAsStringSync());
    violations.addAll(_findLogLessCatches(path, content));
  }

  if (violations.isNotEmpty) {
    stderr.writeln('EH-3 log-less-catch check FAILED (AUD-profiles-16):');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'EH-3 log-less-catch check passed (AUD-profiles-16) — every catch in '
    'the scoped file(s) logs through AppLogger or rethrows.',
  );
}

List<String> _findLogLessCatches(String path, String content) {
  final violations = <String>[];

  final catchKeyword = RegExp(r'\bcatch\s*\(');
  for (final match in catchKeyword.allMatches(content)) {
    final parenEnd = _matchingDelimiter(content, match.end - 1, '(', ')');
    if (parenEnd == null) continue;
    var bodyStart = parenEnd + 1;
    while (bodyStart < content.length && content[bodyStart].trim().isEmpty) {
      bodyStart++;
    }
    if (bodyStart >= content.length || content[bodyStart] != '{') continue;
    final bodyEnd = _matchingDelimiter(content, bodyStart, '{', '}');
    if (bodyEnd == null) continue;
    final body = content.substring(bodyStart + 1, bodyEnd);
    if (_logMarkers.every((m) => !body.contains(m))) {
      violations.add(_violationMessage(path, content, match.start));
    }
  }

  return violations;
}

String _violationMessage(String path, String content, int offset) {
  final line = '\n'.allMatches(content.substring(0, offset)).length + 1;
  return '$path:$line: log-less catch — body has no AppLogger/_log call '
      'and no rethrow (EH-3, AUD-profiles-16). Log the caught error through '
      'AppLogger before continuing, or rethrow.';
}

/// Given the index of an opening delimiter (`(` or `{`), returns the index of
/// its matching closing delimiter, tracking nested pairs and skipping over
/// string literals so a `)`/`}` inside a string is never mistaken for the
/// real terminator. Returns null if unmatched (malformed input).
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

/// Blanks out `//` and `/* */` comments (replacing non-newline characters
/// with spaces so line numbers are preserved), leaving string literal
/// contents untouched. Copied from tool/check_eh3_log_less_catch.dart's
/// helper of the same name/behaviour — kept local so each checker script
/// stays a single, independently-runnable file.
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
