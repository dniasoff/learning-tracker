/// SM-7 ad-hoc `ParentAnalyticsRepositoryImpl(` construction checker —
/// AUD-sync-05 / AUD-core-navigation-04 / AUD-core-navigation-04 gate-repair.
///
/// SM-7 ("repositories/services/DAOs are constructed only inside their
/// `@riverpod` provider or a test override") originally shipped as a
/// hand-maintained grep over exactly the 4 files the first 4 findings named
/// (`local_data_upload_service.dart`, `outbox_sync_write_facade.dart`,
/// `reward_settings_merge_delegate.dart`, `restore_guard.dart`). That
/// hardcoded list structurally could not catch a NEW ad-hoc construction
/// site anywhere else in `lib/` — which is exactly how
/// `lib/app/restore/device_restore_service.dart:101` shipped an inline
/// `ParentAnalyticsRepositoryImpl(_database)` uncaught (AUD-core-navigation-04
/// gate-repair).
///
/// This script closes that scope gap for `ParentAnalyticsRepositoryImpl(`
/// specifically: it scans every `.dart` file under `lib/` (excluding
/// `lib/core/analytics/`, where the class itself and its real DB-backed
/// implementation legitimately live) for `ParentAnalyticsRepositoryImpl(`
/// call sites and fails unless each one is one of:
///
///   1. **Injectable default** — the call is the right-hand side of a `??`
///      null-coalescing default for an optional constructor/factory
///      parameter, e.g.
///      `_analyticsRepository = analyticsRepository ?? ParentAnalyticsRepositoryImpl(database);`
///      — the accepted DI seam used by `local_data_upload_service.dart`
///      (AUD-sync-05) and `device_restore_service.dart`
///      (AUD-core-navigation-04). A bare tear-off default
///      (`ParentAnalyticsRepositoryImpl.new`, as used by
///      `restore_guard.dart`) never matches the `Impl(` call pattern this
///      script scans for in the first place, so it doesn't need special
///      handling here.
///   2. **`@riverpod` provider body** — the call is textually inside a block
///      whose immediately-enclosing declaration is annotated `@riverpod` (or
///      `@Riverpod(...)`), or inside an old-style `Provider<...>(`/
///      `StreamProvider<...>(`/`FutureProvider<...>(`/`AsyncNotifierProvider`
///      callback body.
///   3. **Allowlisted with a stated reason** — the construction line (or the
///      line immediately above it) carries a `// SM-7-ALLOW: <reason>`
///      comment with non-empty reason text.
///
/// Anything else fails the check — this is what turns a re-introduced ad-hoc
/// `ParentAnalyticsRepositoryImpl(...)` anywhere in `lib/` (outside
/// `core/analytics/`) into a `make audit` failure, regardless of which file
/// it lands in.
///
/// Usage:
///   dart run tool/check_sm7_analytics_repository_construction.dart
///
/// Exit codes:
///   0 — every `ParentAnalyticsRepositoryImpl(` call site outside
///       `lib/core/analytics/` is an injectable default, inside a
///       `@riverpod`/`Provider` body, or allowlisted with a reason
///   1 — one or more ad-hoc construction sites found (prints file:line)
library;

import 'dart:io';

/// Directory (relative to `lib/`) exempt from this check — this is where
/// `ParentAnalyticsRepositoryImpl` itself and its real DB-backed
/// implementation legitimately live.
const _exemptPrefix = 'lib/core/analytics/';

final _constructionCall = RegExp(r'ParentAnalyticsRepositoryImpl\s*\(');

/// Heuristic markers on an enclosing block-opening line that mean "this
/// block is a riverpod provider body" — covers both the `@riverpod`
/// function/class-generator annotation and the legacy
/// `Provider<T>((ref) { ... })`-style factories.
final _riverpodAnnotation = RegExp(r'@[Rr]iverpod\b');
final _legacyProviderOpener = RegExp(r'\bProvider(?:<[^>]*>)?\s*\(');

final _allowlistMarker = RegExp(r'//\s*SM-7-ALLOW:\s*(\S.*)$');

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln(
      'ERROR: lib/ not found — run from the learning_tracker/ '
      'package root.',
    );
    exit(1);
  }

  final violations = <String>[];

  for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.startsWith(_exemptPrefix)) continue;

    final raw = entity.readAsStringSync();
    final masked = _maskStringsAndComments(raw);

    for (final match in _constructionCall.allMatches(masked)) {
      if (_isInjectableDefault(masked, match.start)) continue;
      if (_isInsideRiverpodProviderBody(masked, match.start)) continue;
      if (_isAllowlisted(raw, masked, match.start)) continue;

      final line = _lineNumber(raw, match.start);
      violations.add(
        '$path:$line: ad-hoc ParentAnalyticsRepositoryImpl(...) construction '
        'outside core/analytics/ — inject via a constructor/factory '
        'parameter instead (mirror local_data_upload_service.dart /'
        ' device_restore_service.dart), or add "// SM-7-ALLOW: <reason>" if '
        'this site is an intentional exception (SM-7).',
      );
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln(
      'SM-7 ParentAnalyticsRepositoryImpl construction check FAILED:',
    );
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'SM-7 ParentAnalyticsRepositoryImpl construction check passed — every '
    'call site outside lib/core/analytics/ is an injectable default, a '
    '@riverpod provider body, or allowlisted with a reason.',
  );
}

/// True when the text immediately preceding [matchStart] in [masked]
/// (ignoring whitespace) ends with `??` — the accepted
/// `field = param ?? ParentAnalyticsRepositoryImpl(db)` injectable-default
/// shape.
bool _isInjectableDefault(String masked, int matchStart) {
  var i = matchStart - 1;
  while (i >= 0 && masked[i].trim().isEmpty) {
    i--;
  }
  return i >= 1 && masked[i] == '?' && masked[i - 1] == '?';
}

/// True when [matchStart] lies inside a block whose enclosing declaration —
/// at any nesting level — looks like a riverpod provider body: a
/// `@riverpod`/`@Riverpod(...)`-annotated function or class a few lines
/// above the block's opening brace, or a legacy `Provider<...>(`-style
/// factory callback.
bool _isInsideRiverpodProviderBody(String masked, int matchStart) {
  final opens = _enclosingBraceOpenIndices(masked, matchStart);
  for (final openIndex in opens) {
    final lineStart = masked.lastIndexOf('\n', openIndex) + 1;
    final lineEnd = masked.indexOf('\n', openIndex);
    final line = masked.substring(
      lineStart,
      lineEnd == -1 ? masked.length : lineEnd,
    );
    if (_legacyProviderOpener.hasMatch(line)) return true;

    // Look up to 5 physical lines above the block-opening line for a
    // `@riverpod` annotation (covers both top-level generator functions and
    // class-based generators, where the annotation sits on the class
    // declaration above the method containing this block).
    var searchFrom = lineStart - 1;
    for (var hop = 0; hop < 5 && searchFrom >= 0; hop++) {
      final prevLineStart = masked.lastIndexOf('\n', searchFrom - 1) + 1;
      final prevLine = masked.substring(
        prevLineStart,
        searchFrom + 1 > masked.length ? masked.length : searchFrom + 1,
      );
      if (_riverpodAnnotation.hasMatch(prevLine)) return true;
      searchFrom = prevLineStart - 1;
    }
  }
  return false;
}

/// Returns the byte offsets of every unmatched `{` enclosing [pos], ordered
/// outermost-first.
List<int> _enclosingBraceOpenIndices(String masked, int pos) {
  final stack = <int>[];
  for (var i = 0; i < pos; i++) {
    final c = masked[i];
    if (c == '{') {
      stack.add(i);
    } else if (c == '}') {
      if (stack.isNotEmpty) stack.removeLast();
    }
  }
  return stack;
}

/// True when the construction's own line, or the line immediately above it,
/// carries a `// SM-7-ALLOW: <reason>` marker with non-empty reason text.
/// Checked against the RAW (unmasked) source since the marker itself is a
/// comment.
bool _isAllowlisted(String raw, String masked, int matchStart) {
  final lineStart = masked.lastIndexOf('\n', matchStart) + 1;
  final lineEndIdx = masked.indexOf('\n', matchStart);
  final lineEnd = lineEndIdx == -1 ? raw.length : lineEndIdx;
  final sameLine = raw.substring(lineStart, lineEnd);
  if (_allowlistMarker.hasMatch(sameLine)) return true;

  if (lineStart == 0) return false;
  final prevLineEnd = lineStart - 1;
  final prevLineStart = raw.lastIndexOf('\n', prevLineEnd - 1) + 1;
  final prevLine = raw.substring(prevLineStart, prevLineEnd);
  return _allowlistMarker.hasMatch(prevLine);
}

int _lineNumber(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}

/// Replaces `//`/`/* */` comment bodies AND string-literal interiors with
/// spaces (preserving length, line breaks, and all non-string/comment
/// source) so brace-depth and `??`-adjacency scanning never trips on braces
/// or `?`s that only appear inside a comment or a string.
String _maskStringsAndComments(String source) {
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
      buffer.write(closer);
      i += closer.length;
      while (i < n && !source.startsWith(closer, i)) {
        if (source[i] == r'\' && i + 1 < n) {
          buffer.write(source[i] == '\n' ? '\n' : ' ');
          buffer.write(source[i + 1] == '\n' ? '\n' : ' ');
          i += 2;
          continue;
        }
        buffer.write(source[i] == '\n' ? '\n' : ' ');
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
      i += 2;
      continue;
    }

    buffer.write(c);
    i++;
  }
  return buffer.toString();
}
