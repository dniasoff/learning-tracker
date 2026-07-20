/// Rule-0 checker — no duplicate top-level keys in an ARB file
/// (AUD-l10n-01).
///
/// AUD-l10n-01 found 5 top-level keys duplicated in both
/// `lib/l10n/app_en.arb` and `lib/l10n/app_he.arb` (`todaysLearning`,
/// `errorLoadingTasks`, `today`, `notificationReminderTitle`,
/// `notificationReminderBody`). ARB is plain JSON, and JSON's
/// last-key-wins parsing means the SECOND definition silently shadows
/// the first everywhere — including in `dart:convert`'s `jsonDecode`,
/// which every existing checker (`tool/arb_parity_check.dart`,
/// `flutter gen-l10n`, `flutter analyze`) relies on. None of them can
/// ever see the shadowed copy, so an editor who "fixes" the dead first
/// definition has the fix silently discarded, and dead ICU branches
/// (e.g. a zero-count `plural` case) can sit unused indefinitely.
///
/// This checker parses each ARB file's *raw source text* — not via
/// `jsonDecode`, which would already have collapsed the duplicates
/// before we ever saw them — walking bracket depth so it only flags
/// keys duplicated at the top level (depth 1). Nested keys (e.g. every
/// `@key`'s `"description"`/`"placeholders"` object legitimately
/// reuses names like `count`/`type`/`description` across entries) are
/// correctly ignored.
///
/// Usage:
///   dart run tool/check_arb_duplicate_keys.dart
///   dart run tool/check_arb_duplicate_keys.dart <path-to-arb> [<path-to-arb> ...]
///     # test-only override so the regression test
///     # (test/tool/check_arb_duplicate_keys_test.dart) can exercise
///     # deliberately-broken fixtures without touching this repo's real
///     # ARB files.
///
/// Exit codes:
///   0 — no top-level key is duplicated in any checked file
///   1 — at least one top-level key is duplicated (file:line printed
///       for every occurrence)
///   2 — a required input file is missing/unreadable
library;

import 'dart:io';

const _defaultPaths = ['lib/l10n/app_en.arb', 'lib/l10n/app_he.arb'];

/// One occurrence of a top-level ARB key: its 1-indexed source line.
class _KeyOccurrence {
  _KeyOccurrence(this.key, this.line);
  final String key;
  final int line;
}

/// Walks [source] tracking `{`/`}`/`[`/`]` depth (respecting quoted
/// strings and `\`-escapes) and records every `"key":` that appears
/// immediately inside the root object (depth == 1, i.e. a direct child
/// of the file's outermost `{`).
List<_KeyOccurrence> _topLevelKeyOccurrences(String source) {
  final occurrences = <_KeyOccurrence>[];
  var depth = 0;
  var line = 1;
  var inString = false;
  var escapeNext = false;
  var i = 0;
  final len = source.length;

  while (i < len) {
    final ch = source[i];

    if (ch == '\n') line++;

    if (inString) {
      if (escapeNext) {
        escapeNext = false;
      } else if (ch == r'\') {
        escapeNext = true;
      } else if (ch == '"') {
        inString = false;
      }
      i++;
      continue;
    }

    switch (ch) {
      case '"':
        inString = true;
        // Only a key at depth 1 (a direct child of the root object) is
        // a top-level key. Peek ahead: is this string followed (after
        // whitespace) by a `:`? Every ARB key is `"...":`; string
        // VALUES at depth 1 don't occur (all root-level entries are
        // either strings or `@`-metadata objects, both keyed), so this
        // condition alone would already exclude values, but we still
        // guard on depth defensively.
        if (depth == 1) {
          final keyStart = i + 1;
          final keyEnd = _findStringEnd(source, keyStart);
          if (keyEnd != null) {
            final afterKey = _skipWhitespace(source, keyEnd + 1);
            if (afterKey < len && source[afterKey] == ':') {
              occurrences.add(
                _KeyOccurrence(source.substring(keyStart, keyEnd), line),
              );
            }
          }
        }
      case '{' || '[':
        depth++;
      case '}' || ']':
        depth--;
    }
    i++;
  }

  return occurrences;
}

/// Returns the index of the closing (unescaped) `"` starting the scan
/// at [start], or `null` if the string is unterminated.
int? _findStringEnd(String source, int start) {
  var i = start;
  while (i < source.length) {
    final ch = source[i];
    if (ch == r'\') {
      i += 2;
      continue;
    }
    if (ch == '"') return i;
    i++;
  }
  return null;
}

int _skipWhitespace(String source, int start) {
  var i = start;
  while (i < source.length && source[i].trim().isEmpty) {
    i++;
  }
  return i;
}

/// Checks a single ARB file; returns the human-readable violation
/// lines (empty if clean).
List<String> _checkFile(String path) {
  final file = File(path);
  final source = file.readAsStringSync();
  final occurrences = _topLevelKeyOccurrences(source);

  final byKey = <String, List<int>>{};
  for (final occ in occurrences) {
    byKey.putIfAbsent(occ.key, () => []).add(occ.line);
  }

  final violations = <String>[];
  final duplicateKeys = byKey.keys.where((k) => byKey[k]!.length > 1).toList()
    ..sort();
  for (final key in duplicateKeys) {
    final lines = byKey[key]!;
    final metadataKey = key.startsWith('@') ? null : '@$key';
    final metadataNote = metadataKey == null
        ? ''
        : ' (and its matching `$metadataKey` metadata block, if any)';
    violations.add(
      '$path: top-level key "$key" is duplicated at lines '
      '${lines.join(', ')} — JSON last-key-wins means only the '
      'definition at line ${lines.last} is live; the earlier '
      '${lines.length - 1 == 1 ? "one is" : "ones are"} silently dead '
      '(AUD-l10n-01). Delete the shadowed copy$metadataNote — never '
      'leave it in place.',
    );
  }
  return violations;
}

void main(List<String> args) {
  final paths = args.isEmpty ? _defaultPaths : args;

  final allViolations = <String>[];
  for (final path in paths) {
    if (!File(path).existsSync()) {
      stderr.writeln('ERROR: $path not found.');
      exit(2);
    }
    allViolations.addAll(_checkFile(path));
  }

  if (allViolations.isNotEmpty) {
    stderr.writeln(
      'ARB duplicate-key check FAILED (AUD-l10n-01) — '
      '${allViolations.length} violation(s):',
    );
    for (final v in allViolations) {
      stderr.writeln('  - $v');
    }
    exit(1);
  }

  stdout.writeln(
    'ARB duplicate-key check passed — no top-level key duplicated in '
    '${paths.join(", ")} (AUD-l10n-01).',
  );
}
