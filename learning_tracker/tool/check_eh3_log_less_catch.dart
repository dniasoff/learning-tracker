/// EH-3 log-less-catch checker — AUD-sync-03.
///
/// EH-3 ("Never swallow an error: every `catch` rethrows, converts, or logs
/// through `AppLogger`") already has two checkers for the *empty*-body half:
/// the `empty_catches` analyzer lint and `make audit` check 9 (literally-empty
/// `catch (_) {}` bodies). Neither catches the "comment-only" or
/// "swallow-with-a-no-op-lambda" shape — a `catch`/`catchError` whose body
/// runs real code but never logs and never rethrows, e.g. the
/// `.catchError((Object _) {})` this finding (AUD-sync-03) found in
/// `outbox_sync_write_facade.dart`.
///
/// This script closes that log-less gap: it finds every `catch (...) { ... }`
/// block and every `.catchError((...) { ... })` call in the scoped file(s)
/// below and fails if the body contains neither an `AppLogger`/`_logger`
/// call nor a `rethrow`.
///
/// **Scope (Rule 0 — start scoped, expand later; mirrors the EH-4 `make
/// audit` check 27 precedent for `core/sync/{sync_orchestrator,pull_pipeline}`
/// et al.):** only the file(s) this finding's acceptance criterion names.
/// Widening this to all of `lib/` is real, larger follow-up work (a project-
/// wide sweep — the same caveat the newer `no_log_less_catch` custom_lint
/// rule design notes) and is intentionally NOT attempted here.
///
/// AUD-core-database-16 adds its own 3 named files: `content_database.dart`
/// (4 migration-`catch (_)` sites) and `seed_manager.dart` (`_rollback`'s
/// `catch (_) { // Best effort }`) both needed a typed clause + an
/// `AppLogger` call; `device_registry_database.dart` is included too so the
/// checker keeps proving `DeviceAccountX.accountTier`'s catch — removed
/// entirely by that same fix, see EH-4's `avoid_catching_errors` checker —
/// never regresses back to a log-less swallow.
///
/// Usage:
///   dart run tool/check_eh3_log_less_catch.dart
///
/// Exit codes:
///   0 — every catch/catchError in the scoped files logs or rethrows
///   1 — one or more log-less catch/catchError bodies found (prints file:line)
library;

import 'dart:io';

/// Files this finding's AC is scoped to. Add to this list (never widen the
/// underlying scan logic silently) as later findings burn down the same
/// pattern elsewhere — see the EH-4 check 27 precedent in
/// docs/coding-standards.md for the established shape of this ratchet.
const _scopedFiles = [
  'lib/features/sync/data/outbox_sync_write_facade.dart',
  'lib/core/database/content/content_database.dart',
  'lib/core/database/seed_manager.dart',
  'lib/core/database/registry/device_registry_database.dart',
];

/// Any of these substrings appearing in a catch/catchError body counts as
/// "logs the error" for this checker's purposes.
const _logMarkers = ['AppLogger', '_logger', 'rethrow'];

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
    stderr.writeln('EH-3 log-less-catch check FAILED:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'EH-3 log-less-catch check passed — every catch/catchError in the '
    'scoped file(s) logs through AppLogger or rethrows.',
  );
}

List<String> _findLogLessCatches(String path, String content) {
  final violations = <String>[];

  // ── `catch (...) { ... }` blocks ──────────────────────────────────────────
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
      violations.add(_violationMessage(path, content, match.start, 'catch'));
    }
  }

  // ── `.catchError((...) { ... })` / `.catchError((...) => ...)` calls ──────
  final catchErrorCall = RegExp(r'\.catchError\s*\(');
  for (final match in catchErrorCall.allMatches(content)) {
    final parenEnd = _matchingDelimiter(content, match.end - 1, '(', ')');
    if (parenEnd == null) continue;
    final args = content.substring(match.end, parenEnd);
    if (_logMarkers.every((m) => !args.contains(m))) {
      violations.add(
        _violationMessage(path, content, match.start, 'catchError'),
      );
    }
  }

  return violations;
}

String _violationMessage(String path, String content, int offset, String kind) {
  final line = '\n'.allMatches(content.substring(0, offset)).length + 1;
  return '$path:$line: log-less $kind — body has no AppLogger/_logger call '
      'and no rethrow (EH-3, AUD-sync-03). Log the caught error through '
      'AppLogger before discarding it, or rethrow.';
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
/// contents untouched. Copied from tool/check_analytics_catalog.dart's
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
