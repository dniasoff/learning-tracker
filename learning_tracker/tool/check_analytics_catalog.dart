/// Analytics catalog checker — AUD-core-analytics-01 (PV-1 / PV-5).
///
/// [AnalyticsService.logEvent] fires real events to Firebase Analytics in
/// release/profile builds (see `lib/core/analytics/analytics_provider.dart`).
/// `AnalyticsEvent` (`lib/core/analytics/analytics_service.dart`) is the ONLY
/// audited, PV-1-reviewed catalog of event names. `LogEvents`
/// (`lib/core/logging/log_events.dart`) is a SEPARATE catalog scoped to
/// [AppLogger] structured logs and must never reach `logEvent` — doing so
/// bypasses PV-1 review and has historically leaked per-child identifiers
/// and content identifiers straight to Google's servers.
///
/// This script greps every `.logEvent(` call site under `lib/` and fails
/// with `file:line` on any call whose first (event-name) argument is not an
/// `AnalyticsEvent.<member>` reference.
///
/// Usage:
///   dart run tool/check_analytics_catalog.dart
///
/// Exit codes:
///   0 — every `.logEvent(` call site passes an `AnalyticsEvent.*` member
///   1 — one or more call sites pass something else (prints file:line)
library;

import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln(
      'ERROR: lib/ not found — run from the learning_tracker/ directory',
    );
    exit(1);
  }

  // Matches `.logEvent(` followed (possibly across newlines) by the first
  // argument, captured up to the next `,` or `)`. All real call sites in
  // this codebase pass a single identifier/member-access expression as the
  // event name (never a nested call), so stopping at the first `,`/`)` is
  // safe and keeps the checker a plain regex rather than a full parser.
  final callPattern = RegExp(r'\.logEvent\(\s*([^,)]+)');

  // The two files that DEFINE the AnalyticsService.logEvent abstraction are
  // exempt: analytics_service.dart's own convenience methods are the
  // catalog itself, and firebase_analytics_service.dart forwards an
  // already-validated `name` to the real `package:firebase_analytics`
  // `FirebaseAnalytics.logEvent(name: ..., parameters: ...)` SDK call (a
  // different, named-parameter API) — the one file the coding standards
  // permit to import `package:firebase_analytics/` at all.
  const exemptFiles = {
    'lib/core/analytics/analytics_service.dart',
    'lib/core/analytics/firebase_analytics_service.dart',
  };

  final violations = <String>[];

  final dartFiles =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .where((f) => !f.path.endsWith('.freezed.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in dartFiles) {
    final relPath = file.path.replaceFirst(RegExp(r'^\.[\\/]'), '');
    if (exemptFiles.contains(relPath)) continue;

    // Strip comments before matching so a doc comment that merely mentions
    // `.logEvent(` (like this checker's own docs, or this file's) can't
    // trip a false positive.
    final content = _stripComments(file.readAsStringSync());

    for (final match in callPattern.allMatches(content)) {
      final arg = match.group(1)!.trim();
      if (arg.startsWith('AnalyticsEvent.')) continue;
      final line =
          '\n'.allMatches(content.substring(0, match.start)).length + 1;
      violations.add(
        '$relPath:$line: .logEvent() called with `$arg` — event name '
        'must be an AnalyticsEvent.* member (AUD-core-analytics-01, PV-1/PV-5). '
        'LogEvents.* is for AppLogger only; promote the event into '
        'AnalyticsEvent in lib/core/analytics/analytics_service.dart with '
        'PV-1-safe parameters if it genuinely belongs in analytics.',
      );
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Analytics catalog check FAILED:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'Analytics catalog check passed — every .logEvent() call site in lib/ '
    'uses an AnalyticsEvent.* member.',
  );
}

/// Blanks out `//` and `/* */` comments (replacing non-newline characters
/// with spaces so line numbers are preserved), while leaving string literal
/// contents untouched — a source string containing `//` (a URL, say) must
/// not be mistaken for a comment.
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
