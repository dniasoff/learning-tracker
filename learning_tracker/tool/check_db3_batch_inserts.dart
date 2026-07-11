/// DB-3 batch-insert checker — AUD-sync-02.
///
/// DB-3 ("Bulk same-shape writes use `batch()`/`insertAll`, never a loop of
/// individually awaited inserts") names its own checker shape in
/// docs/coding-standards.md: "audit grep for `for`/`.forEach(` blocks
/// containing `await into(`". That literal pattern doesn't fire in
/// `local_data_upload_service.dart` — the writes there go through
/// `OutboxSyncWriteFacade`, not a direct Drift `into(` call — so this script
/// adapts the same rule to the facade-call shape this finding actually
/// found: a `for`/`.forEach(` loop whose body `await`s a SINGULAR
/// `_facade.pushX(...)`/`_facade.enqueueX(...)` call (as opposed to one of
/// the `*Batch` methods added to fix this finding), which re-triggers one
/// outbox INSERT (and one drain-kick) per iteration.
///
/// **Scope (Rule 0 — start scoped, expand later; mirrors the EH-3/EH-4/SM-7
/// scoped-checker precedent in this codebase):** only
/// `lib/features/sync/data/local_data_upload_service.dart`, the file this
/// finding's evidence names. Other bulk-write call sites in the codebase are
/// out of scope for this finding.
///
/// Usage:
///   dart run tool/check_db3_batch_inserts.dart
///
/// Exit codes:
///   0 — no `for`/`.forEach(` loop in the scoped file awaits a singular
///       facade push/enqueue call
///   1 — one or more such loops found (prints file:line)
library;

import 'dart:io';

const _scopedFiles = ['lib/features/sync/data/local_data_upload_service.dart'];

/// Matches a loop-opening statement: `for (...)` or `...forEach(`.
final _loopOpener = RegExp(r'\bfor\s*\(|\.forEach\s*\(');

/// Matches an awaited singular facade push/enqueue call — i.e. NOT one of
/// the `*Batch` methods (`enqueueXBatch`, `pushXBatch`, ...) added to fix
/// this finding.
final _singularFacadeCall = RegExp(
  r'await\s+_facade\.(push|enqueue)(?!\w*Batch\b)\w*\(',
);

void main() {
  final violations = <String>[];

  for (final path in _scopedFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('ERROR: scoped file not found: $path');
      exit(1);
    }
    violations.addAll(
      _findLoopedSingularInserts(path, file.readAsStringSync()),
    );
  }

  if (violations.isNotEmpty) {
    stderr.writeln('DB-3 batch-insert check FAILED:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'DB-3 batch-insert check passed — no for/.forEach( loop in the scoped '
    'file(s) awaits a singular outbox push/enqueue call.',
  );
}

List<String> _findLoopedSingularInserts(String path, String content) {
  final violations = <String>[];

  for (final loopMatch in _loopOpener.allMatches(content)) {
    // `for (` — find the loop's `(...)` header, then its `{ ... }` body.
    // `.forEach(` — the "body" is the argument list itself (often a
    // one-line arrow or a `{ ... }` block passed as the callback).
    final isForEach = content.startsWith('.forEach', loopMatch.start);
    final headerOpenParen = content.indexOf('(', loopMatch.start);
    final headerCloseParen = _matchingDelimiter(
      content,
      headerOpenParen,
      '(',
      ')',
    );
    if (headerCloseParen == null) continue;

    String body;
    if (isForEach) {
      // For `.forEach(callback)`, the callback IS the parenthesised
      // argument — the body we care about is everything between the parens.
      body = content.substring(headerOpenParen + 1, headerCloseParen);
    } else {
      var bodyStart = headerCloseParen + 1;
      while (bodyStart < content.length && content[bodyStart].trim().isEmpty) {
        bodyStart++;
      }
      if (bodyStart >= content.length || content[bodyStart] != '{') continue;
      final bodyEnd = _matchingDelimiter(content, bodyStart, '{', '}');
      if (bodyEnd == null) continue;
      body = content.substring(bodyStart + 1, bodyEnd);
    }

    for (final callMatch in _singularFacadeCall.allMatches(body)) {
      final absoluteOffset = content.indexOf(
        callMatch.group(0)!,
        isForEach ? headerOpenParen : loopMatch.start,
      );
      final line =
          '\n'.allMatches(content.substring(0, absoluteOffset)).length + 1;
      violations.add(
        '$path:$line: a loop awaits a singular outbox push/enqueue call '
        '(DB-3, AUD-sync-02) — build the payload list first and call the '
        'matching *Batch method once instead: ${callMatch.group(0)}',
      );
    }
  }

  return violations;
}

/// Given the index of an opening delimiter, returns the index of its
/// matching closing delimiter, tracking nested pairs and skipping over
/// string literals. Returns null if unmatched.
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
