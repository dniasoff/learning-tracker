/// R7 Rule-0 checker — tautological "acceptance" test ratchet
/// (source-text read+assert), TEA-009 / `docs/test-artifacts/reassurance-plan.md`
/// A1.1.
///
/// `docs/test-artifacts/framework-validation-report.md` found dozens of
/// `test/` files — concentrated in `test/story_acceptance/` (21 of 58
/// files) — that read a `lib/` file's SOURCE TEXT at runtime and assert on
/// the string itself (e.g. `expect(routerSrc, contains('extends
/// ConsumerWidget'))`), instead of exercising the code and asserting on
/// observable BEHAVIOR. Such a test passes as long as the literal source
/// text exists somewhere in the file — it can never fail from a real
/// runtime regression (the class could stop extending `ConsumerWidget` in
/// letter but keep the same string in an unrelated comment, or vice versa),
/// and it is the reassurance campaign's R7 surface: "~10,370 green tests
/// still let a ship-blocking P0 and 4 device defects through, because
/// verification sits at the wrong layer."
///
/// This checker treats a test file as an R7 violation when it BOTH:
///   1. reads `lib/` source text at runtime, via either
///      - `test/helpers/lib_source.dart`'s `readLibSource(`/`libFileExists(`
///        helpers (that file's own doc comment states its sole purpose is
///        feeding "acceptance tests" that "inspect a lib/ source file's
///        existence or contents at runtime" — every call site exists to
///        feed an assertion, so usage alone is sufficient here), or
///      - a `File(...)` construction referencing a `lib/` path — a literal
///        `lib/`-prefixed argument, or a bare-identifier argument in a file
///        that has a `lib/` string literal elsewhere (e.g. a `const
///        pathsToCheck = ['lib/a.dart', ...]` list feeding a `for`-loop
///        variable used as `File(relPath)`), or a `for (final f in
///        someListOfFileObjects)` loop over a list literal of `File(...)`s
///        — chained (directly, or via an intermediate variable) to
///        `.readAsStringSync(`/`.readAsLinesSync(`; and
///   2. asserts on that source text — an `expect(...)` call that references
///      the read expression itself (inline), a variable assigned from one,
///      or a variable transitively derived from one (e.g. a regex-match
///      list computed from the source string).
///
/// This is a text-based heuristic — bracket-balance scanning plus a
/// bounded backward-context / variable-derivation trace, the same rigor
/// level as `tool/check_inmemory_db_close.dart`'s scope tracking — not a
/// full Dart parse; it will not perfectly reconstruct every alias chain,
/// and (being name-based, not scope-based) it can in principle conflate
/// two same-named variables in unrelated parts of one file. It deliberately
/// does NOT flag `Directory('lib/...')` tree-walking audits (e.g. the
/// `*_no_color_literals_test.dart` files, or a story test that walks every
/// `.dart` file under a subtree): those derive each per-file path at
/// runtime from directory traversal, so no `lib/`-referencing `File(...)`
/// call exists in the test source itself for this checker's bracket scan
/// to find — a different, more defensible "repo-wide static audit embedded
/// as a test" category (that pattern already has its own dedicated tool/
/// checkers, e.g. `check_hardcoded_presentation_text.dart`), out of this
/// finding's scope.
///
/// This is a RATCHET, not a full-repo hard-fail — the same shape as
/// `tool/check_sm7_learning_program_singleton.dart` (AUD-scheduler-23) and
/// `tool/check_tq3_pump_app_migration.dart` (AUD-t-profiles-02): the
/// pre-existing backlog of files exhibiting this pattern is tracked as a
/// baseline COUNT in [_baselinePath] — this checker's OWN current count
/// (40, generated via `--update-baseline`) is the pinned baseline, the same
/// convention SM-7/TQ-3 use. It is lower than the campaign's headline "67"
/// figure (`docs/test-artifacts/reassurance-plan.md` A1.1 /
/// `docs/test-artifacts/framework-validation-report.md`) by design, not by
/// accident: that figure's methodology sweeps in the `Directory('lib/...')`
/// tree-walking repo-wide audits this checker deliberately excludes (see
/// above), and this checker's alias-tracing has a bounded reach (it does
/// not follow a value through a named helper FUNCTION call — only through
/// direct variable-to-variable derivation) — both documented, deliberate
/// scope calls, not bugs. The gate fails only on a NEW file introducing the
/// pattern this checker detects — matching A1.1's own acceptance criterion:
/// "Ratchet: forbid new readAsStringSync-of-lib asserts under test/".
/// Convert a file's source-text assertion into a real behavioral one (pump
/// the widget/provider, assert the observable effect), delete the file, or
/// move a genuine structural check into `tool/` as a named meta-check, then
/// re-run with `--update-baseline` to lock the win in and burn the backlog
/// down — never raise the baseline to paper over a NEW violation.
///
/// Usage:
///   dart run tool/check_r7_source_text_assertion_ratchet.dart            # ratchet check
///   dart run tool/check_r7_source_text_assertion_ratchet.dart --report    # list matching files, exit 0
///   dart run tool/check_r7_source_text_assertion_ratchet.dart --update-baseline
///
/// Exit codes (ratchet mode):
///   0 — count of matching files is at or below the tracked baseline
///   1 — count exceeds the tracked baseline (prints the file list)
library;

import 'dart:io';

/// Baseline occurrence count (the pre-existing, not-yet-converted backlog
/// per `docs/test-artifacts/reassurance-plan.md` A1.1). Maintainers burn
/// this down by converting a source-text assertion into a real behavioral
/// test (or deleting/relocating it) and re-running with
/// `--update-baseline`; the ratchet then locks the new, smaller count.
const _baselinePath = 'tool/r7_source_text_assertion_baseline.txt';

final _helperUse = RegExp(r'\breadLibSource\s*\(|\blibFileExists\s*\(');
final _fileCallOpener = RegExp(r'\bFile\s*\(');
final _readChainImmediate = RegExp(
  r'^\s*\.\s*read(?:AsStringSync|AsLinesSync)\s*\(',
);
final _assignedVarBefore = RegExp(r'(\w+)\s*=(?!=)\s*$');
final _precededByExpectOpen = RegExp(r'expect\(\s*$');
final _bareIdentifier = RegExp(r'^\w+$');
final _libLiteralAnywhere = RegExp(r'''['"](?:\.\./|learning_tracker/)?lib/''');
final _forIn = RegExp(
  r'for\s*\(\s*(?:final\s+)?(?:\w+\s+)?(\w+)\s+in\s+(\w+)\s*\)',
);

/// A plain `name = <rhs>;` assignment (not `==`/`!=`/`<=`/`>=`/`+=`/etc —
/// the negative lookahead excludes a trailing `=` making it `==`, and
/// requiring a bare word directly before the `=` naturally excludes the
/// compound-operator and comparison-operator forms, whose preceding
/// character is a symbol, not whitespace).
final _assignmentOpener = RegExp(r'(\w+)\s*=(?!=)\s*');

/// Returns the index just after the matching close bracket for the open
/// bracket at [openIndex] (one of `(`, `[`, `{`), or -1 if unbalanced.
int _matchingBracketEnd(String content, int openIndex) {
  const opens = '([{';
  const closes = ')]}';
  final openCh = content[openIndex];
  final closeCh = closes[opens.indexOf(openCh)];
  var depth = 0;
  for (var i = openIndex; i < content.length; i++) {
    final ch = content[i];
    if (ch == openCh) {
      depth++;
    } else if (ch == closeCh) {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return -1;
}

/// Returns the index just after the top-level terminating `;` for the
/// statement whose RHS begins at [start] — tracks `(`/`[`/`{` depth so a
/// semicolon inside a nested call/list/map doesn't cut the RHS short, and
/// stops at an unbalanced close bracket (the RHS is nested inside an
/// enclosing call/loop header, e.g. a classic `for (int i = 0; ...)`).
/// Bracket-balance only, not a full parse — good enough for well-formatted
/// Dart source.
int _statementEnd(String content, int start) {
  var depth = 0;
  var i = start;
  for (; i < content.length; i++) {
    final ch = content[i];
    if (ch == '(' || ch == '[' || ch == '{') {
      depth++;
    } else if (ch == ')' || ch == ']' || ch == '}') {
      if (depth == 0) break;
      depth--;
    } else if (ch == ';' && depth == 0) {
      break;
    }
  }
  return i;
}

/// Every top-level `name = <rhs>;` assignment in [content], name -> every
/// RHS text it was ever assigned (multiple entries if reassigned).
Map<String, List<String>> _assignments(String content) {
  final result = <String, List<String>>{};
  for (final m in _assignmentOpener.allMatches(content)) {
    final end = _statementEnd(content, m.end);
    result
        .putIfAbsent(m.group(1)!, () => [])
        .add(content.substring(m.end, end));
  }
  return result;
}

/// Looks at up to [window] characters of [content] immediately before
/// [index] and returns the variable name assigned there (`foo = ` /
/// `final foo = `), or null.
String? _assignedVarEndingAt(String content, int index, {int window = 100}) {
  final start = (index - window).clamp(0, content.length);
  return _assignedVarBefore
      .firstMatch(content.substring(start, index))
      ?.group(1);
}

/// True when [content] immediately before [index] (within [window] chars)
/// ends in `expect(` — i.e. [index] is the start of `expect(...)`'s actual
/// (first) argument.
bool _isExpectActualArgAt(String content, int index, {int window = 80}) {
  final start = (index - window).clamp(0, content.length);
  return _precededByExpectOpen.hasMatch(content.substring(start, index));
}

/// True when [content] (one test file's full source) exhibits the R7
/// "read lib/ source text at runtime, assert on the string" shape.
bool isSourceTextAssertionFile(String content) {
  // Mechanism 1: test/helpers/lib_source.dart's readLibSource()/
  // libFileExists() — that helper's sole documented purpose is feeding an
  // assertion, so usage alone qualifies.
  if (_helperUse.hasMatch(content)) return true;

  // Mechanism 2: File(<lib/ reference>) chained to
  // .readAsStringSync()/.readAsLinesSync(), the result flowing (directly,
  // via a variable, or via a for-in loop binding) into an expect(...) call.
  final assignments = _assignments(content);
  final hasLibLiteralAnywhere = _libLiteralAnywhere.hasMatch(content);

  final fileObjVars = <String>{};
  final sourceTextVars = <String>{};

  for (final m in _fileCallOpener.allMatches(content)) {
    final openIdx = content.indexOf('(', m.start);
    final closeIdx = _matchingBracketEnd(content, openIdx);
    if (closeIdx == -1) continue;
    final arg = content.substring(openIdx + 1, closeIdx - 1);

    // Qualifies when the File(...) argument itself names a lib/ path, or
    // (when it's a bare variable — e.g. a for-loop path variable) the file
    // has a lib/-prefixed string literal somewhere feeding that variable.
    final qualifies =
        arg.contains('lib/') ||
        (_bareIdentifier.hasMatch(arg.trim()) && hasLibLiteralAnywhere);
    if (!qualifies) continue;

    final chained = _readChainImmediate.hasMatch(content.substring(closeIdx));
    if (chained) {
      // File('...lib/...').readAsStringSync()/.readAsLinesSync() chained
      // directly onto the File(...) call — the assigned/expect-embedded
      // value IS the source text itself.
      if (_isExpectActualArgAt(content, m.start)) return true;
      final v = _assignedVarEndingAt(content, m.start);
      if (v != null) sourceTextVars.add(v);
      continue;
    }

    // Not chained directly — a File object, dereferenced with
    // .readAsStringSync()/.readAsLinesSync() later (possibly under a
    // different variable name than the one seen here).
    final fileObjVar = _assignedVarEndingAt(content, m.start);
    if (fileObjVar != null) fileObjVars.add(fileObjVar);
  }

  // Vars whose RHS is (or embeds) a list literal of File(...) objects
  // referencing lib/, e.g. `final candidates = [File('lib/a.dart'), ...];`.
  final listOfFileObjVars = <String>{};
  assignments.forEach((name, rhsList) {
    if (rhsList.any((r) => r.contains('File(') && r.contains('lib/'))) {
      listOfFileObjVars.add(name);
    }
  });

  // A for-in loop variable bound directly to such a list (`for (final f in
  // candidates) { f.readAsStringSync() }`) is itself a File-object var...
  for (final m in _forIn.allMatches(content)) {
    if (listOfFileObjVars.contains(m.group(2))) fileObjVars.add(m.group(1)!);
  }
  // ...and so is a var derived from such a list via a selection method
  // referencing the list var by name (e.g. `final file =
  // candidates.firstWhere((f) => f.existsSync(), orElse: ...);`).
  assignments.forEach((name, rhsList) {
    for (final rhs in rhsList) {
      for (final lv in listOfFileObjVars) {
        if (RegExp(r'\b' + RegExp.escape(lv) + r'\b').hasMatch(rhs)) {
          fileObjVars.add(name);
        }
      }
    }
  });

  for (final fileObjVar in fileObjVars) {
    final derefPattern = RegExp(
      '\\b${RegExp.escape(fileObjVar)}\\s*\\.\\s*read(?:AsStringSync|AsLinesSync)\\s*\\(',
    );
    for (final dm in derefPattern.allMatches(content)) {
      if (_isExpectActualArgAt(content, dm.start)) return true;
      final v = _assignedVarEndingAt(content, dm.start);
      if (v != null) sourceTextVars.add(v);
    }
  }

  // Transitive closure: a variable derived from an existing source-text var
  // (its RHS textually references that var's name as a token) is treated
  // as a source-text var too — e.g. `matches = pattern.allMatches(source)`
  // derives from `source`, and would otherwise be missed because the
  // expect(...) call asserts on `matches`, not `source` itself. Bounded
  // iteration; a heuristic proxy for data-flow, not a real one.
  for (var round = 0; round < 6; round++) {
    final seeds = sourceTextVars.toList();
    var grew = false;
    assignments.forEach((name, rhsList) {
      if (sourceTextVars.contains(name)) return;
      for (final rhs in rhsList) {
        for (final sv in seeds) {
          if (RegExp(r'\b' + RegExp.escape(sv) + r'\b').hasMatch(rhs)) {
            sourceTextVars.add(name);
            grew = true;
            return;
          }
        }
      }
    });
    if (!grew) break;
  }

  if (sourceTextVars.isEmpty) return false;

  // Does any expect(...) call's argument list reference a (possibly
  // transitively-derived) source-text var?
  for (final m in RegExp(r'\bexpect\s*\(').allMatches(content)) {
    final openIdx = content.indexOf('(', m.start);
    final closeIdx = _matchingBracketEnd(content, openIdx);
    if (closeIdx == -1) continue;
    final args = content.substring(openIdx, closeIdx);
    for (final sv in sourceTextVars) {
      if (RegExp(r'\b' + RegExp.escape(sv) + r'\b').hasMatch(args)) {
        return true;
      }
    }
  }

  return false;
}

List<File> _testFiles() {
  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    stderr.writeln('ERROR: test/ not found — run from learning_tracker/.');
    exit(1);
  }
  return testDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.replaceAll(r'\', '/').endsWith('.dart'))
      .where((f) => !f.path.replaceAll(r'\', '/').startsWith('test/helpers/'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

List<String> _matchingFiles() {
  final matches = <String>[];
  for (final file in _testFiles()) {
    final path = file.path.replaceAll(r'\', '/');
    if (isSourceTextAssertionFile(file.readAsStringSync())) {
      matches.add(path);
    }
  }
  return matches;
}

int _readBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return 0;
  final dataLine = file.readAsLinesSync().firstWhere(
    (l) => l.trim().isNotEmpty && !l.trim().startsWith('#'),
    orElse: () => '0',
  );
  return int.tryParse(dataLine.trim()) ?? 0;
}

void main(List<String> args) {
  final report = args.contains('--report');
  final updateBaseline = args.contains('--update-baseline');

  final matches = _matchingFiles();
  final actual = matches.length;

  if (report) {
    for (final path in matches) {
      stdout.writeln(path);
    }
    stdout.writeln(
      '--- $actual file(s) read lib/ source text and assert on it',
    );
    return;
  }

  if (updateBaseline) {
    File(_baselinePath).writeAsStringSync(
      '# R7 source-text-assertion ratchet baseline — generated by\n'
      '# tool/check_r7_source_text_assertion_ratchet.dart --update-baseline.\n'
      '# Tracks the count of test/ files that read lib/ source text at\n'
      '# runtime (via test/helpers/lib_source.dart or File(...)\n'
      '# .readAsStringSync()/.readAsLinesSync()) and assert on the source\n'
      '# string instead of on observable behavior (TEA-009,\n'
      '# docs/test-artifacts/reassurance-plan.md A1.1). The number only\n'
      '# goes DOWN — lower it only by converting a file to a real\n'
      '# behavioral test (or deleting/relocating it), never by raising it\n'
      '# to paper over a NEW violation.\n'
      '$actual\n',
    );
    stdout.writeln('Baseline updated to $actual.');
    return;
  }

  final baseline = _readBaseline();
  if (actual > baseline) {
    stderr.writeln(
      'R7 source-text-assertion ratchet FAILED (TEA-009, '
      'docs/test-artifacts/reassurance-plan.md A1.1) — $actual test file(s) '
      'read lib/ source text at runtime (via test/helpers/lib_source.dart\'s '
      'readLibSource()/libFileExists(), or File(...).readAsStringSync()/'
      '.readAsLinesSync() on a lib/ path) and assert on the source string '
      'itself, up from the tracked baseline of $baseline. Such a test can '
      'never fail from a real runtime regression — it only proves the '
      'literal text exists somewhere in the file. Convert the assertion to '
      'exercise the real code and assert on observable behavior (pump the '
      'widget/provider, assert the effect), or move a genuine structural '
      'check into tool/ as a named meta-check instead. If you deliberately '
      'converted/removed source-text-assertion file(s) and lowered the '
      'count, re-run with --update-baseline to lock the win in.',
    );
    stderr.writeln('New/still-present matching file(s):');
    for (final path in matches) {
      stderr.writeln('  $path');
    }
    exit(1);
  }

  stdout.writeln(
    'R7 source-text-assertion ratchet passed — $actual test file(s) read '
    'lib/ source text and assert on it (tracked baseline: $baseline, '
    'docs/test-artifacts/reassurance-plan.md A1.1).',
  );
}
