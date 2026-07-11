/// EH-4 typed-catch checker for the core/sync periodic-drain / recovery-pull
/// / listener-dispatch paths — AUD-core-sync-26.
///
/// `docs/coding-standards.md` EH-4 requires `catch` clauses to be typed
/// (`on <Type> catch`) rather than bare, so a programming-error `Error`
/// subtype (`TypeError`/`StateError`/`RangeError`/`NoSuchMethodError`)
/// propagates to the zone's uncaught-error handler instead of being folded
/// into an ordinary "operation failed" warning and swallowed forever.
///
/// The project-wide `avoid_catches_without_on_clauses` / `avoid_catching_
/// errors` analyzer lints named in EH-4's Lint Baseline table cannot be
/// flipped on globally yet — the codebase has ~150 other bare `catch` sites
/// outside this finding's scope (`grep -rn '} catch (' lib/ | wc -l`), so
/// enabling them in `analysis_options.yaml` would fail `flutter analyze` on
/// unrelated files. This checker instead enforces the rule precisely where
/// AUD-core-sync-26 fixed it: the three files whose periodic-drain,
/// recovery-pull-trigger, and listener-dispatch catches were narrowed.
///
/// A catch site is compliant when ONE of the following holds:
///   1. It carries an `on <Type>` clause (`on Exception catch (e, st)`), or
///   2. It is a `Future.catchError(...)` call with a `test:` parameter
///      (the `on`-clause equivalent for the zone-error-callback API), or
///   3. It is a wildcard catch (`catch (_)` / `catchError((Object _, ...)`)
///      — deliberately out of scope for this finding, or
///   4. The catch body carries an inline `// audit:eh4-broad-catch-ok`
///      marker comment documenting why it must stay broad (mirrors
///      sync_orchestrator.dart:768's classifier-based pattern).
///
/// Usage:
///   dart run tool/check_eh4_typed_catches.dart
///
/// Exit codes:
///   0 — every named catch site in the target files is typed, wildcard, or
///       carries the exemption marker.
///   1 — one or more untyped, unmarked named catch sites remain (prints
///       file:line).
library;

import 'dart:io';

/// The exact files AUD-core-sync-26 narrows. Deliberately NOT `lib/`-wide —
/// see the file doc comment above.
const _targetFiles = [
  'lib/core/sync/sync_orchestrator.dart',
  'lib/core/sync/pull_pipeline.dart',
  'lib/core/sync/tutored_listener_supervisor.dart',
];

const _exemptionMarker = 'audit:eh4-broad-catch-ok';

/// Matches a `try`-block `catch` clause, optionally preceded by `on <Type>`.
/// Group 1: the `on <Type>` prefix (null when the catch is bare).
/// Group 2: the bound variable's first identifier (`_` for a wildcard).
final _tryCatchPattern = RegExp(
  r'(on\s+[\w<>.]+\s+)?catch\s*\(\s*([A-Za-z_]\w*)',
);

/// Matches a `Future.catchError(` call. Group 1: the callback's error
/// parameter name (`_` for a wildcard), when the callback types it as
/// `Object <name>`. A callback that doesn't type its first parameter as
/// `Object` (untyped `catchError((e, st) { ... })`) still matches with
/// group 1 null — treated as non-wildcard (must be typed or marked).
final _catchErrorPattern = RegExp(
  r'\.catchError\(\s*\(\s*(?:Object\s+([A-Za-z_]\w*))?',
);

void main() {
  final violations = <String>[];

  for (final relPath in _targetFiles) {
    final file = File(relPath);
    if (!file.existsSync()) {
      stderr.writeln(
        'ERROR: $relPath not found — run from the learning_tracker/ directory',
      );
      exit(1);
    }
    final content = file.readAsStringSync();
    final stripped = _stripComments(content);

    for (final match in _tryCatchPattern.allMatches(stripped)) {
      final boundName = match.group(2)!;
      if (boundName == '_') continue; // wildcard — out of scope.
      final isTyped = match.group(1) != null;
      if (isTyped) continue;
      if (_hasExemptionMarker(content, match.end)) continue;
      final line = _lineNumber(stripped, match.start);
      violations.add(
        '$relPath:$line: bare `catch ($boundName...)` with no `on <Type>` '
        'clause and no `$_exemptionMarker` marker (AUD-core-sync-26, EH-4).',
      );
    }

    for (final match in _catchErrorPattern.allMatches(stripped)) {
      final boundName = match.group(1);
      if (boundName == '_') continue; // wildcard — out of scope.
      // The regex match starts at the `.` of `.catchError(` — the FIRST `(`
      // from there is unambiguously the call's own opening paren (the
      // callback's inner `(` comes later), so its balanced close marks the
      // end of the whole `.catchError(...)` call, `test:` param included.
      final openParen = stripped.indexOf('(', match.start);
      final closeParen = _matchingParen(stripped, openParen);
      final body = closeParen == null
          ? stripped.substring(match.end)
          : stripped.substring(match.start, closeParen + 1);
      if (body.contains('test:') || body.contains('test :')) continue;
      if (_hasExemptionMarker(content, match.end)) continue;
      final line = _lineNumber(stripped, match.start);
      violations.add(
        '$relPath:$line: `.catchError(...)` with no `test:` filter and no '
        '`$_exemptionMarker` marker (AUD-core-sync-26, EH-4) — an Error '
        'subtype will be swallowed instead of propagating.',
      );
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('EH-4 typed-catch check FAILED:');
    for (final v in violations..sort()) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'EH-4 typed-catch check passed — every named catch site in '
    '${_targetFiles.join(', ')} is typed, wildcard, or explicitly '
    'marked $_exemptionMarker.',
  );
}

/// True when the exemption marker appears within the next 400 characters
/// (comments included — this scans the ORIGINAL content, not the
/// comment-stripped copy) after [searchFrom]. 400 chars comfortably covers
/// a multi-line doc comment immediately following the catch clause's `{`
/// without accidentally reaching into the NEXT catch site's body.
bool _hasExemptionMarker(String original, int searchFrom) {
  final windowEnd = (searchFrom + 400).clamp(0, original.length);
  return original.substring(searchFrom, windowEnd).contains(_exemptionMarker);
}

/// 1-indexed line number of [index] within [source].
int _lineNumber(String source, int index) =>
    '\n'.allMatches(source.substring(0, index)).length + 1;

/// Returns the index of the `(` at [openIndex]'s matching `)`, or null if
/// unbalanced (should not happen on valid Dart source).
int? _matchingParen(String source, int openIndex) {
  if (openIndex >= source.length || source[openIndex] != '(') return null;
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

/// Blanks out `//` and `/* */` comments (replacing every non-newline
/// character — including `//` line-comment bodies — with a space so both
/// line numbers AND raw character offsets are preserved 1:1 against
/// [source]), while leaving string literal contents untouched. Exact
/// position-preservation (unlike `tool/check_analytics_catalog.dart`'s
/// otherwise-identical helper, which only length-preserves block comments)
/// matters here: [_hasExemptionMarker] re-indexes into the ORIGINAL text
/// using offsets produced by matching against the stripped text, so the two
/// must stay in lockstep.
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
        buffer.write(' ');
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
