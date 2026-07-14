/// AUD-t-scheduler-01 candidate Rule-0 checker — test-name/body similarity
/// guard for test/features/scheduler/.
///
/// AUD-t-scheduler-01 found three independent pairs of test files under
/// test/features/scheduler/ that pinned the exact same production behavior
/// under the same `group()` name — evidently written by separate fix-wave
/// passes that never checked for existing coverage:
///  - goal_entity_extended_test.dart / goal_entity_extra_test.dart (now
///    merged into the former; the latter is deleted)
///  - scheduler_content_repository_impl_test.dart (data/repositories/) /
///    scheduler_content_repository_test.dart (domain/repositories/) — the
///    getLeafItems suite now lives solely in data/repositories/, the
///    AG-5-correct mirrored home
///  - daily_task_generator_extended_test.dart /
///    daily_task_generator_generate_all_test.dart (now merged into the
///    former; the latter is deleted)
///
/// Its first acceptance criterion names this checker: "No two files under
/// test/features/scheduler/ share a >=80%-similar block of assertions
/// against the same production symbol (spot-checked; flag as a candidate
/// Rule-0 checker: a test-name/body similarity script)."
///
/// Algorithm: for every `group('Name', () { ... })` call found anywhere in
/// test/features/scheduler/ (this codebase's convention names groups after
/// the production symbol under test, e.g. 'GoalEntity.firestoreId',
/// 'DailyTaskGenerator.generateAll'), find every `test('name', () { ... })`
/// call nested directly inside it. When the SAME normalized group name
/// appears in files A and B, each test in A's group is compared against
/// every test in B's group with two complementary, independently-sufficient
/// signals:
///
///  1. Exact name match — the test descriptions are identical after
///     trimming/lowercasing. Two files independently landing a
///     verbatim-identical test name under the same group name is
///     near-conclusive evidence of copy-paste duplication (e.g. this
///     finding's own evidence: 'returns empty list for empty curricula
///     list' appeared byte-for-byte in both daily_task_generator files).
///  2. Body similarity — Jaccard similarity of normalized token sets
///     >= 80%. Each test's own body is prefixed with any simple
///     `final`/`const`/`var` declarations hoisted above it directly inside
///     the group (but NOT nested helper *functions* — those are excluded
///     so a large, non-matching per-file helper definition cannot drown
///     out a genuinely-matching short test body), because
///     AUD-t-scheduler-01's own evidence includes a pair where one file
///     hoisted shared setup above the individual `test()` bodies and the
///     other repeated it per-test. Normalization strips comments, collapses
///     string/numeric literals to placeholders, and collapses any locally
///     `final`/`const`/`var`-declared identifier to a placeholder too — so
///     two blocks that differ only in literal values or local variable
///     names (`a`/`b` vs `t1`/`t2`, `d` vs `target`, ...) still compare as
///     the same structure, while the production symbols/method/matcher
///     names that actually identify duplicated *behavior* are preserved.
///
/// Braces embedded in string literals (this suite's stage-schedule JSON
/// fixtures, e.g. `'{"type":"delay","delay_days":0}'`) are skipped by the
/// brace matcher so they never desynchronize a body span.
///
/// Known scope limitation (documented, not silently swept under the rug):
/// two tests that are semantically duplicate but differ in BOTH exact test
/// name AND rely on a shared, non-locally-declared fixture built in an
/// enclosing `setUp()` (so neither signal above fires — e.g. one file's
/// test calls a `generator` instance field wired up in `setUp()`, the
/// other constructs its own `DailyTaskGenerator` inline) can slip past this
/// checker. This is an accepted false-negative gap for a "candidate"
/// mechanical checker (per AUD-t-scheduler-01's own "spot-checked" framing
/// of its evidence) — closing it fully would require semantic (AST-level)
/// analysis, not a text-similarity script. Groups are located by a linear
/// scan for `group(`/`test(` call sites, not full nesting-depth tracking; a
/// `test()` inside a nested inner `group()` is still counted as part of its
/// enclosing outer group. This suite has no nested groups today. Only
/// cross-FILE occurrences are compared — a repeated group name within a
/// single file is a different defect shape and out of this checker's scope.
///
/// Usage:
///   dart run tool/check_scheduler_test_duplication.dart
///
/// Exit codes:
///   0 — no two files under test/features/scheduler/ share an exact test
///       name or a >=80%-similar test body under the same group name
///   1 — one or more such pairs found (prints the group name, the matching
///       test names/similarity, and the offending files)
library;

import 'dart:io';

const _scanDir = 'test/features/scheduler';
const _similarityThreshold = 0.8;

/// Below this normalized-token count, two short bodies can trivially clear
/// the similarity threshold by coincidence (shared boilerplate like
/// `expect`, `final`, `await`) without representing a real duplicated
/// assertion. The exact-name signal has no such floor — an identical test
/// description is significant regardless of body length.
const _minTokensForBodyComparison = 8;

void main() {
  final dir = Directory(_scanDir);
  if (!dir.existsSync()) {
    stderr.writeln('ERROR: $_scanDir not found — run from learning_tracker/.');
    exit(2);
  }

  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // normalized group name -> test occurrences across all scanned files
  final groupsByName = <String, List<_TestOccurrence>>{};
  var totalGroups = 0;

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    final src = file.readAsStringSync();
    for (final group in _extractCalls(src, 'group')) {
      totalGroups++;
      final normName = group.name.trim().toLowerCase();
      if (normName.isEmpty) continue;
      final tests = _extractCalls(group.body, 'test');
      if (tests.isEmpty) continue;
      final preamble = _declarationsOnly(
        group.body.substring(0, tests.first.callStart),
      );
      for (final t in tests) {
        groupsByName
            .putIfAbsent(normName, () => [])
            .add(
              _TestOccurrence(
                path: path,
                name: t.name,
                effectiveBody: '$preamble\n${t.body}',
              ),
            );
      }
    }
  }

  final violations = <String>[];
  for (final groupName in groupsByName.keys.toList()..sort()) {
    final occurrences = groupsByName[groupName]!;
    for (var i = 0; i < occurrences.length; i++) {
      for (var j = i + 1; j < occurrences.length; j++) {
        final a = occurrences[i];
        final b = occurrences[j];
        if (a.path == b.path) continue; // same-file repeats are out of scope

        final sameName =
            a.name.trim().toLowerCase() == b.name.trim().toLowerCase();

        double sim = 0;
        final tokensA = _normalizeTokens(a.effectiveBody);
        final tokensB = _normalizeTokens(b.effectiveBody);
        if (tokensA.length >= _minTokensForBodyComparison &&
            tokensB.length >= _minTokensForBodyComparison) {
          sim = _jaccard(tokensA.toSet(), tokensB.toSet());
        }

        if (sameName || sim >= _similarityThreshold) {
          final reason = sameName
              ? 'identical test name'
              : '${(sim * 100).toStringAsFixed(0)}% similar body';
          violations.add(
            'group "$groupName" — $reason:\n'
            '    ${a.path}: "${a.name}"\n'
            '    ${b.path}: "${b.name}"',
          );
        }
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln(
      'test/features/scheduler/ test duplication check FAILED '
      '(AUD-t-scheduler-01) — the following test(s) carry an identical name '
      'or a >=${(_similarityThreshold * 100).toStringAsFixed(0)}%-similar '
      'body against the same production symbol (group name) in more than '
      'one file. Merge into one file, keeping the union of distinct '
      'assertions and deleting the fully-subsumed tests (TQ-7 / Fowler '
      'duplication, docs/coding-standards.md):',
    );
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'test/features/scheduler/ test duplication check passed — no two files '
    'share an identical test name or a '
    '>=${(_similarityThreshold * 100).toStringAsFixed(0)}%-similar test '
    'body under the same group name ($totalGroups group(s), '
    '${groupsByName.length} distinct group name(s), scanned across '
    '${files.length} file(s)).',
  );
}

class _TestOccurrence {
  final String path;
  final String name;
  final String effectiveBody;

  _TestOccurrence({
    required this.path,
    required this.name,
    required this.effectiveBody,
  });
}

class _Call {
  final String name;
  final String body;

  /// Index, within the string that was searched, where this call's
  /// keyword (`group`/`test`) starts.
  final int callStart;

  _Call(this.name, this.body, this.callStart);
}

/// Finds every `<keyword>('name', () { ... })` call in [src] and returns
/// its name, full body span (including any nested calls and hoisted
/// setup), and start offset.
List<_Call> _extractCalls(String src, String keyword) {
  final calls = <_Call>[];
  final callRegex = RegExp('(?<![A-Za-z0-9_])$keyword\\s*\\(');
  for (final match in callRegex.allMatches(src)) {
    final afterParen = match.end;
    final name = _firstStringLiteral(src, afterParen);
    if (name == null) continue;
    final braceIdx = _findUnquotedChar(src, afterParen, '{');
    if (braceIdx == -1) continue;
    final closeIdx = _findMatchingBrace(src, braceIdx);
    if (closeIdx == -1) continue;
    calls.add(_Call(name, src.substring(braceIdx + 1, closeIdx), match.start));
  }
  return calls;
}

/// Extracts only simple `final`/`const`/`var NAME = ...;` declaration
/// statements from [text] (dropping comments, blank lines, and — crucially
/// — nested helper *function* definitions, which have no top-level `=`
/// and would otherwise drown out a genuinely-matching short test body with
/// a large, per-file-unique block of unrelated tokens).
String _declarationsOnly(String text) {
  final declRegex = RegExp(r'(?:final|const|var)\s+[A-Za-z_]\w*\s*=[^;]*;');
  return declRegex.allMatches(text).map((m) => m.group(0)).join('\n');
}

/// Returns the content of the first quoted string literal at/after [from],
/// bailing out (returning null) if a `{` or `;` is hit first — a
/// defensive bound so a malformed/unexpected call shape is skipped rather
/// than mis-parsed.
String? _firstStringLiteral(String src, int from) {
  var i = from;
  while (i < src.length) {
    final c = src[i];
    if (c == '{' || c == ';') return null;
    if (c == "'" || c == '"') {
      final quote = c;
      final start = i + 1;
      var j = start;
      while (j < src.length) {
        if (src[j] == r'\') {
          j += 2;
          continue;
        }
        if (src[j] == quote) break;
        j++;
      }
      return src.substring(start, j);
    }
    i++;
  }
  return null;
}

/// Scans forward from [from] for the first occurrence of [target] that is
/// not inside a string literal.
int _findUnquotedChar(String src, int from, String target) {
  var i = from;
  while (i < src.length) {
    final c = src[i];
    if (c == "'" || c == '"') {
      final quote = c;
      i++;
      while (i < src.length) {
        if (src[i] == r'\') {
          i += 2;
          continue;
        }
        if (src[i] == quote) {
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    if (c == target) return i;
    i++;
  }
  return -1;
}

/// Returns the index of the `}` matching the `{` at [openIdx], skipping
/// characters inside single/double-quoted string literals so embedded JSON
/// (e.g. `'{"type":"delay","delay_days":0}'`) never desynchronizes the
/// brace count.
int _findMatchingBrace(String src, int openIdx) {
  var depth = 0;
  var i = openIdx;
  while (i < src.length) {
    final c = src[i];
    if (c == "'" || c == '"') {
      final quote = c;
      i++;
      while (i < src.length) {
        if (src[i] == r'\') {
          i += 2;
          continue;
        }
        if (src[i] == quote) {
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return -1;
}

/// Normalizes a test's effective body into a token list: strips `//`
/// comments, collapses string and numeric literals to placeholders,
/// collapses locally `final`/`const`/`var`-declared identifiers to a
/// placeholder too (so two blocks that differ only in literal values or
/// local variable names still compare as the same structure), lowercases,
/// and splits on non-word characters.
List<String> _normalizeTokens(String body) {
  final noComments = body.replaceAll(RegExp(r'//[^\n]*'), ' ');
  final noSingleQuoted = noComments.replaceAll(
    RegExp(r"'(?:[^'\\]|\\.)*'"),
    ' STR ',
  );
  final noStrings = noSingleQuoted.replaceAll(
    RegExp(r'"(?:[^"\\]|\\.)*"'),
    ' STR ',
  );
  final noNumbers = noStrings.replaceAll(RegExp(r'\b\d+(\.\d+)?\b'), 'NUM');

  final declRegex = RegExp(
    r'\b(?:final|const|var)\s+([A-Za-z_][A-Za-z0-9_]*)\b',
  );
  final declaredNames = declRegex
      .allMatches(noNumbers)
      .map((m) => m.group(1)!)
      .toSet();
  var result = noNumbers;
  for (final name in declaredNames) {
    result = result.replaceAll(RegExp('\\b${RegExp.escape(name)}\\b'), 'VAR');
  }

  return result
      .toLowerCase()
      .split(RegExp('[^a-zA-Z0-9_]+'))
      .where((t) => t.isNotEmpty)
      .toList();
}

double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  final union = a.union(b).length;
  if (union == 0) return 0;
  return a.intersection(b).length / union;
}
