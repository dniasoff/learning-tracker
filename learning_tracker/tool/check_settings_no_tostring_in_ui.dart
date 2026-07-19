/// EH-5/ST-4 raw-exception-string checker for `lib/features/settings` —
/// AUD-settings-07.
///
/// docs/coding-standards.md's EH-5 requires presentation code to resolve
/// error copy entirely through `AppLocalizations`/ARB, never a caught
/// exception's `.toString()`. The general-purpose `no_e_to_string_in_ui`
/// custom_lint rule (`packages/custom_lints/lib/src/rules/
/// no_e_to_string_in_ui.dart`) already encodes this, but `custom_lint`
/// itself does not currently run against this codebase (AUD-guardrails-03 —
/// see docs/coding-standards.md, "custom_lint toolchain status"), so it
/// cannot gate a regression here today. This script is the scoped,
/// grep-based backstop AUD-settings-07's acceptance criteria calls for: it
/// mechanically greps every `.dart` file under `lib/features/settings` for
/// `.toString()` flowing into a `Text(...)`, `l10n.<method>(...)`, or
/// `AppLocalizations.of(context)!.<method>(...)` call site — the exact shape
/// curriculum_settings_screen.dart:79, lifetime_marking_screen.dart:606,
/// account_actions.dart:588, and send_logs_service.dart:104 had before the
/// fix. Once custom_lint is repaired, `no_e_to_string_in_ui` supersedes this
/// as the primary enforcement (see docs/coding-standards.md EH-5); this
/// checker stays as a belt-and-suspenders regression gate.
///
/// Usage (from `learning_tracker/`):
///   dart run tool/check_settings_no_tostring_in_ui.dart
///
/// Exit codes:
///   0 — no `.toString()` flows into a Text()/l10n()/AppLocalizations.of()
///       call site under lib/features/settings.
///   1 — one or more found (prints file:line).
library;

import 'dart:io';

void main() {
  final root = Directory('lib/features/settings');
  if (!root.existsSync()) {
    stderr.writeln(
      'ERROR: lib/features/settings not found — run from learning_tracker/',
    );
    exit(2);
  }

  final dartFiles =
      root
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

  final violations = <String>[];
  for (final file in dartFiles) {
    violations.addAll(_findViolations(file.path, file.readAsStringSync()));
  }

  if (violations.isNotEmpty) {
    violations.forEach(stdout.writeln);
    stdout.writeln();
    stdout.writeln(
      '${violations.length} raw exception .toString() flowing into a '
      'Text()/l10n()/AppLocalizations.of() call site under '
      'lib/features/settings (EH-5/ST-4, AUD-settings-07) — resolve the '
      'display text via a fixed, already-localized ARB fallback instead; '
      'log the real exception via AppLogger for diagnostics.',
    );
    exit(1);
  }

  stdout.writeln(
    'check_settings_no_tostring_in_ui OK — no raw exception .toString() '
    'flows into a Text()/l10n()/AppLocalizations.of() call site under '
    'lib/features/settings.',
  );
}

/// Matches the opening of a call site we care about. Group 0 is the whole
/// match; the call's own `(` is the character immediately preceding
/// `match.end`.
final _callSitePattern = RegExp(
  r'\bText\(|(?<![\w.])l10n\.[A-Za-z_]\w*\(|AppLocalizations\.of\([^)]*\)!\.[A-Za-z_]\w*\(',
);

/// Scans [content] (the text of [path]) for the call sites [_callSitePattern]
/// matches whose argument list contains `.toString()`. Returns one
/// `file:line: <reason>` string per violation.
List<String> _findViolations(String path, String content) {
  final results = <String>[];

  for (final match in _callSitePattern.allMatches(content)) {
    final openParen = match.end - 1;
    final closeParen = _findMatchingParen(content, openParen);
    if (closeParen == -1) continue; // unterminated — leave to the analyzer
    final args = content.substring(openParen + 1, closeParen);
    if (args.contains('.toString()')) {
      results.add(
        '$path:${_lineOf(content, match.start)}: raw exception .toString() '
        "flows into '${match.group(0)}...)' (EH-5/ST-4, AUD-settings-07)",
      );
    }
  }

  return results;
}

int _lineOf(String content, int index) =>
    '\n'.allMatches(content.substring(0, index)).length + 1;

/// Finds the index of the `)` that matches the `(` at [openParenIndex],
/// skipping over parens that appear inside string literals.
int _findMatchingParen(String s, int openParenIndex) {
  var depth = 0;
  var i = openParenIndex;
  while (i < s.length) {
    final c = s[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    } else if (c == "'" || c == '"') {
      final quote = c;
      i++;
      while (i < s.length && s[i] != quote) {
        if (s[i] == r'\') i++;
        i++;
      }
    }
    i++;
  }
  return -1;
}
