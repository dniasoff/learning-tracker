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
///      - a `File(...)` construction (or, per mechanism 3 below, a call to
///        ANY locally-defined function/getter that itself constructs one)
///        referencing a `lib/` path — a literal `lib/`-prefixed argument,
///        or a bare-identifier argument that traces (via a direct
///        assignment, or a `for`-loop binding to a list variable) to a
///        `lib/` string literal elsewhere in the file (e.g. a `const
///        pathsToCheck = ['lib/a.dart', ...]` list feeding a `for`-loop
///        variable used as `File(relPath)`) — this trace is a SCOPED
///        lookup (AX-R7-1, see mechanism 2's qualifying-arg check below),
///        not "does a `lib/` literal exist ANYWHERE in the file", or a
///        `for (final f in someListOfFileObjects)` loop over a list
///        literal of `File(...)`s — chained (directly, or via an
///        intermediate variable) to `.readAsStringSync(`/`.readAsLinesSync(`;
///      and
///   2. asserts on that source text — an `expect(...)` call that references
///      the read expression itself (inline), a variable assigned from one,
///      or a variable (or, per mechanism 3, a locally-defined function or
///      getter's NAME) transitively derived from one (e.g. a regex-match
///      list computed from the source string, or a helper function that
///      returns it).
///
/// Mechanism 3 — indirection through a helper function/getter/variable
/// (AX-R7-1, adversarial review of this checker's first cut): reading the
/// source text and asserting on it need not happen in the same expression,
/// or even the same lexical scope, to count. Three concrete shapes are
/// covered:
///   - `name(args) => File(<lib/ ref>).readAsStringSync();` (an arrow
///     function/getter) or a block-bodied equivalent ending in
///     `return <expr containing the read>;` — the call/getter's NAME is
///     treated as if it were a variable holding the read result, via
///     [_fnValueSpans]' `return`/`=>` span extraction feeding the same
///     variable-derivation machinery mechanism 2 already used for plain
///     variables.
///   - a wrapper that returns the `File` object itself (not the text),
///     e.g. `File _source(String rel) => File(rel);`, called+chained at
///     the use site as `_source('lib/a.dart').readAsStringSync()` — caught
///     without tracing into the wrapper's definition at all, because
///     [_callOpener] (broadened from strictly `File(` to any call-like
///     `name(`) matches the CALL SITE, whose own argument is the literal
///     `lib/` reference and whose result is chained directly.
///   - a value that flows through a named function's `return` before
///     reaching `expect(...)`, e.g. `guardsForRoute()` computing a regex
///     match over an already-tainted `routerSource` variable and
///     `return`ing the derived list — the function's return expression is
///     merged into the same assignment map mechanism 2's transitive
///     closure already walks, so the function's NAME (and, in turn, a
///     variable assigned from calling it) joins the taint set exactly like
///     any other derived variable would.
///
/// This is a text-based heuristic — bracket-balance scanning plus a
/// bounded backward-context / variable-derivation trace, the same rigor
/// level as `tool/check_inmemory_db_close.dart`'s scope tracking — not a
/// full Dart parse; it will not perfectly reconstruct every alias chain,
/// and (being name-based, not scope-based) it can in principle conflate
/// two same-named variables (or functions) in unrelated parts of one file.
/// It deliberately does NOT flag `Directory('lib/...')` tree-walking audits
/// (e.g. the `*_no_color_literals_test.dart` files, or a story test that
/// walks every `.dart` file under a subtree): those derive each per-file
/// path at runtime from directory traversal, so no `lib/`-referencing
/// `File(...)` call exists in the test source itself for this checker's
/// bracket scan to find — a different, more defensible "repo-wide static
/// audit embedded as a test" category (that pattern already has its own
/// dedicated tool/ checkers, e.g. `check_hardcoded_presentation_text.dart`),
/// out of this finding's scope.
///
/// This is a RATCHET, not a full-repo hard-fail — the same shape as
/// `tool/check_sm7_learning_program_singleton.dart` (AUD-scheduler-23) and
/// `tool/check_tq3_pump_app_migration.dart` (AUD-t-profiles-02): the
/// pre-existing backlog of files exhibiting this pattern is tracked as a
/// baseline COUNT in [_baselinePath] — this checker's OWN current count
/// (generated via `--update-baseline`, see [_baselinePath] for the current
/// pinned number) is the pinned baseline, the same convention SM-7/TQ-3
/// use. It is lower than the campaign's headline "67" figure
/// (`docs/test-artifacts/reassurance-plan.md` A1.1 /
/// `docs/test-artifacts/framework-validation-report.md`) by design, not by
/// accident: that figure's methodology sweeps in the `Directory('lib/...')`
/// tree-walking repo-wide audits this checker deliberately excludes (see
/// above), and this checker's alias-tracing — while mechanism 3 now follows
/// a value through a named helper function/getter's `return`/`=>` — still
/// has a bounded reach (a `return`'s enclosing function is resolved by
/// walking outward past non-function blocks to the nearest brace whose
/// header looks like a function/getter signature; a bare-identifier
/// `File(...)` argument is traced to a `lib/` reference only via a direct
/// assignment or `for`-loop-over-list binding in the SAME file, never via
/// arbitrary parameter-to-call-site-argument binding across an unrelated
/// function's calls) — both documented, deliberate scope calls, not bugs.
/// The gate fails only on a NEW file introducing the
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

/// Matches call-like `name(` openers — broadened from strictly `File(` (its
/// original form) so a call to a locally-defined wrapper function/getter
/// that itself constructs a `lib/`-referencing `File` is caught the same
/// way a direct `File(...)` call is: by the CALL SITE's own argument and
/// immediate `.readAsStringSync()`/`.readAsLinesSync()` chaining, with no
/// need to trace into the wrapper's definition (mechanism 3, AX-R7-1). A
/// handful of control-flow keywords are excluded — they're never real
/// calls, and would otherwise waste a bracket-scan on every `if (`/`for (`.
final _callOpener = RegExp(
  r'\b(?!if\b|for\b|while\b|switch\b|catch\b|return\b)[A-Za-z_]\w*\s*\(',
);
final _readChainImmediate = RegExp(
  r'^\s*\.\s*read(?:AsStringSync|AsLinesSync)\s*\(',
);

/// A `name = <rhs>` assignment ending at the match position — the trailing
/// `(?:[A-Za-z_]\w*\.)*` allows an intervening namespaced-import qualifier
/// between the `=` and the reference the assignment is feeding (e.g.
/// `final f = dart_io.File(` when `dart:io` is imported `as dart_io`),
/// which a bare `(\w+)\s*=\s*$` would otherwise miss (AX-R7-1: this exact
/// shape hid a real R7 violation, `edit_track_screen_l1_test.dart`, from
/// detection).
final _assignedVarBefore = RegExp(r'(\w+)\s*=(?!=)\s*(?:[A-Za-z_]\w*\.)*$');
final _precededByExpectOpen = RegExp(r'expect\(\s*$');
final _bareIdentifier = RegExp(r'^\w+$');
final _libLiteralAnywhere = RegExp(r'''['"](?:\.\./|learning_tracker/)?lib/''');
final _forIn = RegExp(
  r'for\s*\(\s*(?:final\s+)?(?:\w+\s+)?(\w+)\s+in\s+(\w+)\s*\)',
);

/// A function/getter signature ending at the match position: either
/// `get name` (getter, no parameter list) or `name(params)` (regular
/// function/method, optionally `async`) — used by [_enclosingFunctionName]
/// to recognize the header immediately preceding a `{` it has walked
/// backward to.
final _functionSignatureEnd = RegExp(
  r'\bget\s+([A-Za-z_]\w*)\s*$|\b([A-Za-z_]\w*)\s*\([^()]*\)\s*(?:async\s*)?$',
);

/// A `return <expr>` keyword — `(?!;)` excludes a bare `return;`, which has
/// no expression to trace.
final _returnKeyword = RegExp(r'\breturn\s+(?!;)');

/// An arrow function/getter definition: `get name => <expr>` or
/// `name(params) => <expr>` (optionally `async`) — the arrow-bodied
/// counterpart of a block function's `return <expr>;`.
final _arrowFunctionOrGetter = RegExp(
  r'\bget\s+([A-Za-z_]\w*)\s*=>\s*'
  r'|\b([A-Za-z_]\w*)\s*\([^()]*\)\s*(?:async\s*)?=>\s*',
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

/// Returns the index of the nearest `{` that opens the block enclosing
/// [index] — scanning backward and tracking brace depth so an already-
/// closed nested `{...}` pair encountered along the way is skipped rather
/// than mistaken for the enclosing one — or null if [index] isn't nested
/// inside any `{...}` block.
int? _nearestUnmatchedOpenBrace(String content, int index) {
  var depth = 0;
  for (var i = index - 1; i >= 0; i--) {
    final ch = content[i];
    if (ch == '}') {
      depth++;
    } else if (ch == '{') {
      if (depth == 0) return i;
      depth--;
    }
  }
  return null;
}

/// Returns the name of the function/method/getter whose BLOCK BODY
/// (`{ ... }` form) encloses [index] — walking outward past non-function
/// blocks (`try`, `if`, `for`, a callback closure's own anonymous `{ }`,
/// ...) until a brace whose header actually looks like a function/getter
/// signature is found (per [_functionSignatureEnd]), or null if none is
/// found. Used to attribute a `return <expr>;` statement to its defining
/// function (mechanism 3, AX-R7-1) — e.g. a `return` nested inside a
/// `try { }` is still attributed to the function wrapping that `try`, not
/// left unresolved just because the `try`'s own `{` isn't a signature.
String? _enclosingFunctionName(String content, int index) {
  var pos = index;
  while (true) {
    final open = _nearestUnmatchedOpenBrace(content, pos);
    if (open == null) return null;
    final start = (open - 200).clamp(0, content.length);
    final m = _functionSignatureEnd.firstMatch(content.substring(start, open));
    if (m != null) return m.group(1) ?? m.group(2);
    pos = open;
  }
}

/// A value "escaping" a function/getter definition — either a
/// `return <expr>;` inside a block body, or the `<expr>` of an arrow
/// (`=>`) body — paired with the defining/enclosing function's name.
/// [start, end) bounds the expression text. See mechanism 3, AX-R7-1.
class _FnValueSpan {
  _FnValueSpan(this.start, this.end, this.fnName);
  final int start;
  final int end;
  final String? fnName;
}

/// Every `return <expr>;` and `name(...) => <expr>;` / `get name => <expr>;`
/// span in [content].
List<_FnValueSpan> _fnValueSpans(String content) {
  final spans = <_FnValueSpan>[];
  for (final m in _returnKeyword.allMatches(content)) {
    final end = _statementEnd(content, m.end);
    spans.add(
      _FnValueSpan(m.end, end, _enclosingFunctionName(content, m.start)),
    );
  }
  for (final m in _arrowFunctionOrGetter.allMatches(content)) {
    final end = _statementEnd(content, m.end);
    spans.add(_FnValueSpan(m.end, end, m.group(1) ?? m.group(2)));
  }
  return spans;
}

/// The name of the function/getter whose `return`/`=>` span contains
/// [index], if any.
String? _spanFunctionNameAt(List<_FnValueSpan> spans, int index) {
  for (final s in spans) {
    if (index >= s.start && index < s.end && s.fnName != null) {
      return s.fnName;
    }
  }
  return null;
}

/// True when the bare identifier [varName] — a `File(varName)` argument —
/// traces, via a direct assignment or a `for (final varName in listVar)`
/// binding, to a `lib/`-referencing string literal elsewhere in [content].
/// Replaces a cruder "does a `lib/` literal exist ANYWHERE in the file"
/// check, which previously false-flagged an unrelated (e.g. temp-file)
/// `File(bareVar)` read merely because some UNCONNECTED `lib/` string
/// happened to appear elsewhere in the same test file (AX-R7-2).
bool _bareArgTracesToLibLiteral(
  String varName,
  Map<String, List<String>> assignments,
  String content,
) {
  final direct = assignments[varName];
  if (direct != null && direct.any((r) => _libLiteralAnywhere.hasMatch(r))) {
    return true;
  }
  for (final m in _forIn.allMatches(content)) {
    if (m.group(1) != varName) continue;
    final listRhs = assignments[m.group(2)];
    if (listRhs != null &&
        listRhs.any((r) => _libLiteralAnywhere.hasMatch(r))) {
      return true;
    }
  }
  return false;
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

  // Mechanism 2: File(<lib/ reference>) — or, per mechanism 3, a call to
  // any locally-defined function/getter that itself constructs one —
  // chained to .readAsStringSync()/.readAsLinesSync(), the result flowing
  // (directly, via a variable, via a for-in loop binding, or via a named
  // function/getter's return value) into an expect(...) call.
  final assignments = _assignments(content);

  // Mechanism 3 (AX-R7-1): fold every `return <expr>;` / `name(...) =>
  // <expr>;` span into the SAME assignment map as a pseudo
  // `fnName = <expr>` entry, so the transitive closure below (which just
  // walks `assignments` looking for RHS text that references an existing
  // taint seed) picks up a function whose return value is itself derived
  // from an already-tainted variable — e.g. a helper that regex-matches
  // over an already-read source string and returns the match list.
  final spans = _fnValueSpans(content);
  for (final s in spans) {
    if (s.fnName == null) continue;
    assignments
        .putIfAbsent(s.fnName!, () => [])
        .add(content.substring(s.start, s.end));
  }

  final fileObjVars = <String>{};
  final sourceTextVars = <String>{};

  for (final m in _callOpener.allMatches(content)) {
    final openIdx = content.indexOf('(', m.start);
    final closeIdx = _matchingBracketEnd(content, openIdx);
    if (closeIdx == -1) continue;
    final arg = content.substring(openIdx + 1, closeIdx - 1);

    // Qualifies when the call's argument itself names a lib/ path, or
    // (when it's a bare variable — e.g. a for-loop path variable) that
    // variable traces — via a direct assignment or for-loop-over-list
    // binding, SCOPED to this file, not "a lib/ literal exists somewhere
    // in the file" (AX-R7-2) — to a lib/-prefixed string literal.
    final qualifies =
        arg.contains('lib/') ||
        (_bareIdentifier.hasMatch(arg.trim()) &&
            _bareArgTracesToLibLiteral(arg.trim(), assignments, content));
    if (!qualifies) continue;

    final chained = _readChainImmediate.hasMatch(content.substring(closeIdx));
    if (chained) {
      // <call>('...lib/...').readAsStringSync()/.readAsLinesSync() chained
      // directly onto the call — the assigned/expect-embedded/returned
      // value IS the source text itself.
      if (_isExpectActualArgAt(content, m.start)) return true;
      final v = _assignedVarEndingAt(content, m.start);
      if (v != null) sourceTextVars.add(v);
      final fn = _spanFunctionNameAt(spans, m.start);
      if (fn != null) sourceTextVars.add(fn);
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
      // The deref itself is the returned/yielded value (e.g. a ternary
      // inside a `return`, so no direct `x = ...` assignment exists to
      // catch above) — attribute it to the enclosing function/getter.
      final fn = _spanFunctionNameAt(spans, dm.start);
      if (fn != null) sourceTextVars.add(fn);
    }
  }

  // Transitive closure: a variable (or, per mechanism 3, a function/getter
  // name) derived from an existing source-text var (its RHS textually
  // references that var's/function's name as a token) is treated as a
  // source-text var too — e.g. `matches = pattern.allMatches(source)`
  // derives from `source`, and would otherwise be missed because the
  // expect(...) call asserts on `matches`, not `source` itself; likewise
  // `guards = guardsForRoute()` derives from `guardsForRoute`, whose own
  // `return` (folded into `assignments` above) derives from `source`.
  // Bounded iteration; a heuristic proxy for data-flow, not a real one.
  for (var round = 0; round < 10; round++) {
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
