/// PROFILE-ID-INT-SITES — audit check 104. Tracks every site this repo
/// knows about today where a profile identity is int-typed, int-parsed, or
/// otherwise treated as the Drift autoincrement value rather than the
/// Firestore ULID, in the specific file scopes Phase 3's ~96-file identity
/// move will have to touch. It exists because `check_profile_path_keying.dart`
/// (audit check 103) is structurally blind to this class of site: 103
/// classifies writers by FILE LOCATION (`lib/core/sync/**`,
/// `functions/src/**`) and by COLLECTION, never by the shape of an identity
/// value — it cannot see `learner_profiles` itself (only that collection's
/// CHILDREN, per its `match /learner_profiles/{profileId} {` anchor), it
/// cannot see `tutor_active_access`, and it has no concept of "this
/// parameter is declared `int`." Building this gate now, on a quiet tree
/// (`docs/planning/firestore-phase2-plan.md` §4 P2-1), is Phase 1's own
/// precedent applied again: a boundary gets a gate BEFORE it is crossed.
///
/// ## The five tracked patterns (this IS the scan set — see [_patterns])
///
/// - **cf-int-guard** — `functions/src/**/*.ts` (excl. `*.test.ts`): a line
///   containing `typeof profileId !== "number"` or `Number.isInteger(
///   profileId)` — the Cloud-Functions-side runtime guard that asserts the
///   caller sent an int.
/// - **cf-string-profileid-doc** — same file scope: a line containing
///   `.doc(String(profileId))` — the CF-side doc-id formula that stringifies
///   the int to address `learner_profiles/{profileId}`.
/// - **dart-int-profileid-param** — exactly three files: `lib/features/
///   tutoring/data/services/tutor_write_service.dart`, `lib/core/sync/
///   firestore_gateway.dart`, `lib/core/sync/outbox/push_pipeline.dart`: a
///   line matching `\bint\s+profileId\b` (covers both `required int
///   profileId,` and a bare positional `int profileId)`). Deliberately NOT
///   all `lib/core/sync/**` — that tree holds 179 raw `int profileId`
///   occurrences across many implementation files that die wholesale when
///   the old sync engine is deleted in Phase 4; scanning three named
///   INTERFACE/service files (not their `_impl` siblings) is the seam
///   Phase 3 actually edits, not a proxy for the whole condemned tree.
/// - **dart-tutoring-int-parse** — every `*.dart` under `lib/features/
///   tutoring/**`: a line containing `int.tryParse`. Deliberately widened
///   past the narrower "just the router" pattern an earlier draft used, so
///   it also catches `invite_tutor_screen.dart`'s
///   `int.tryParse(widget.childProfileId)` — a real P2/P3 edit site the
///   narrower pattern missed.
/// - **dart-tutoring-id-tostring** — every `*.dart` under `lib/features/
///   tutoring/**`: a line containing `.id.toString()` — a profile's int id
///   being stringified to pass across a boundary that Phase 3 will make
///   ULID-native.
///
/// ## NAMED-ENTRY RATCHET, keyed by `<pattern-id> <file>:<enclosing-symbol>`
///
/// This is corrections 1-4 from the plan's reviewer round, load-bearing —
/// earlier drafts of this gate were killed over exactly these points:
///
/// 1. **Never line numbers.** A baseline keyed by line number breaks on the
///    next unrelated edit that shifts a line up or down. Every entry here is
///    `<pattern-id> <file>:<enclosing-symbol>` — the pattern id first
///    (patterns are independent violation TYPES, not interchangeable; a
///    function flagged by two different patterns is two different facts
///    about it, not one), then the nearest enclosing NAMED Dart
///    class-qualified method (`ClassName.methodName`, or bare `methodName`/
///    `<top-level>` when there is no enclosing class) or TS top-level
///    function/`export const ... = ` binding, resolved by
///    [_buildSymbolIndex] via a brace-depth scope stack — never a raw line
///    offset. Two different matching LINES that fall inside the same
///    enclosing symbol under the same pattern collapse to ONE entry: the
///    unit this ratchet tracks is "this function still has this kind of
///    int-profileId site," not "this exact character offset." Concretely:
///    all three of `manage_tutors_screen.dart`'s `.id.toString()` calls at
///    lines 293/298/312 sit inside the same `_ChildGrantsSection.build`
///    method and produce exactly one entry, not three — moving any of those
///    call sites within that method changes no baseline line.
/// 2. **A new entry fails (exit 1). A baseline entry absent from the current
///    scan ALSO fails (exit 1).** There is no "must shrink to empty"
///    requirement anywhere in this file, and there must never be one added:
///    `lib/core/sync/firestore_gateway.dart` and `outbox/push_pipeline.dart`
///    alone contribute dozens of legitimate, currently-correct interface
///    sites (see pattern 3 above), and the old sync engine holds 179 more
///    outside this gate's scope entirely — an "eventually empty" gate over
///    that population is not a proving criterion, it is a lie waiting to be
///    told. What IS required: a fix that removes a violation must remove
///    that violation's baseline line in the SAME commit (STALE, not just
///    "no longer new"), which is what makes a real fix and a widened
///    scanner distinguishable from each other in review.
/// 3. **The OK line prints its scan set.** A gate whose reported number
///    depends on which patterns it runs must publish those patterns in the
///    same line that reports the number, or "N sites, 0 new, 0 stale" is a
///    claim about the scanner, not about the code — see the OK-line format
///    in [main]'s normal-mode branch.
/// 4. **The baseline file REQUIRES a header sentinel**: `# format:
///    profile-id-int-sites v1` plus a `# pattern-hash: <hex>` line covering
///    the ordered pattern-id list (see [_patternListHash]). A baseline file
///    that is missing, empty, or present-but-missing either sentinel line
///    EXITS 1 rather than being read as "zero tracked entries" — for a gate
///    whose clean state is a small, humanly-editable text file, "absent"
///    must never be silently indistinguishable from "verified empty."
///    de facto strengthening: the pattern-hash is also VERIFIED against the
///    scanner's live pattern list on every non-`--update-baseline` run
///    (see [main]) — a baseline written against a different pattern set
///    than the one currently running is exactly the "narrowed scanner"
///    failure mode point 4 of the load-bearing corrections below exists to
///    prevent, and printing the hash alone without checking it would make
///    that check decorative rather than real.
///
/// ## The rule that keeps this gate honest across a commit
///
/// **The commit that changes a scan pattern (adds, removes, or edits a
/// regex/file-scope in [_patterns]) may NOT also change code that pattern
/// covers.** A commit that narrows what the scanner looks for and, in the
/// same diff, deletes the code the narrowed-away portion used to flag can
/// make this gate report a fix that never happened — the gate would go
/// green because it stopped looking, not because the site closed. Change
/// the scanner in one commit (which will change `--update-baseline`'s
/// output and must be reviewed as such); change the code the old scanner
/// caught in a separate commit, where a STALE-entry failure proves the fix
/// really happened.
///
/// ## What this gate deliberately does NOT do
///
/// It does not attempt liveness/reachability filtering the way check 103
/// does — every textual match in scope is tracked, full stop. It does not
/// scan all of `lib/core/sync/**` (179 raw `int profileId` occurrences) —
/// that tree is condemned wholesale in Phase 4 and tracking it site-by-site
/// here would be noise, not signal (see pattern 3's doc above). It is not a
/// full Dart/TypeScript parser: [_buildSymbolIndex]'s brace-depth scope
/// stack is a heuristic, same class of tool as
/// `check_profile_path_keying.dart`'s own admittedly-not-a-full-parser rules
/// walker — known blind spots: multi-line string literals containing
/// unbalanced `{`/`}`, and any construct this file's regexes don't
/// recognise as a class/function opener (e.g. `typedef` function types,
/// top-level `final` closures) will misattribute the enclosing symbol
/// rather than crash; a misattribution still produces a STABLE, non-line-
/// number key, which is what point 1 above requires, even if the printed
/// name is not the one a human would pick.
///
/// Usage:
///   dart run tool/check_profile_id_int_sites.dart
///   dart run tool/check_profile_id_int_sites.dart --report
///   dart run tool/check_profile_id_int_sites.dart --update-baseline
///
/// Exit codes (ratchet mode):
///   0 — no NEW entry and no STALE baseline entry
///   1 — a NEW entry, a STALE baseline entry, a missing/sentinel-less
///       baseline, a pattern-hash mismatch, or a missing hardcoded scan
///       file (pattern 3's three named files are asserted to exist; a
///       silent rename there would silently zero out that pattern)
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

const _baselinePath = 'tool/profile_id_int_sites_baseline.txt';
const _formatSentinel = '# format: profile-id-int-sites v1';
const _hashPrefix = '# pattern-hash: ';

// ---------------------------------------------------------------------------
// Pattern definitions — this list IS the scan set printed in every mode.
// ---------------------------------------------------------------------------

/// One tracked violation TYPE. [fileScope] enumerates candidate files given
/// the `--root`; [lineTest] runs against the RAW (unstripped) line text —
/// deliberately raw, not comment/string-stripped, because several patterns
/// (`typeof profileId !== "number"`, `.doc(String(profileId))`) match
/// through a string literal that stripping would blank out.
class _PatternDef {
  const _PatternDef({
    required this.id,
    required this.description,
    required this.fileScope,
    required this.lineTest,
  });

  final String id;
  final String description;
  final List<String> Function(String root) fileScope;
  final bool Function(String rawLine) lineTest;
}

const _tutorWriteServicePath =
    'lib/features/tutoring/data/services/tutor_write_service.dart';
const _firestoreGatewayPath = 'lib/core/sync/firestore_gateway.dart';
const _pushPipelinePath = 'lib/core/sync/outbox/push_pipeline.dart';

final _intProfileIdParamRe = RegExp(r'\bint\s+profileId\b');

List<_PatternDef> _patterns() => [
  _PatternDef(
    id: 'cf-int-guard',
    description:
        'functions/src/**/*.ts (excl *.test.ts): typeof profileId !== '
        '"number" / Number.isInteger(profileId) runtime guard',
    fileScope: (root) => _tsFilesUnder('$root/functions/src'),
    lineTest: (l) =>
        l.contains('typeof profileId !== "number"') ||
        l.contains('Number.isInteger(profileId)'),
  ),
  _PatternDef(
    id: 'cf-string-profileid-doc',
    description:
        'functions/src/**/*.ts (excl *.test.ts): .doc(String(profileId)) '
        'doc-id formula against learner_profiles',
    fileScope: (root) => _tsFilesUnder('$root/functions/src'),
    lineTest: (l) => l.contains('.doc(String(profileId))'),
  ),
  _PatternDef(
    id: 'dart-int-profileid-param',
    description:
        '$_tutorWriteServicePath, $_firestoreGatewayPath, '
        '$_pushPipelinePath: int profileId parameter (interface/service '
        'level only — not all 179 occurrences under lib/core/sync/**, '
        'which dies wholesale in Phase 4)',
    fileScope: (root) => [
      '$root/$_tutorWriteServicePath',
      '$root/$_firestoreGatewayPath',
      '$root/$_pushPipelinePath',
    ],
    lineTest: (l) => _intProfileIdParamRe.hasMatch(l),
  ),
  _PatternDef(
    id: 'dart-tutoring-int-parse',
    description:
        'lib/features/tutoring/**/*.dart: int.tryParse (profile-id-as-int '
        'parsing)',
    fileScope: (root) => _dartFilesUnder('$root/lib/features/tutoring'),
    lineTest: (l) => l.contains('int.tryParse'),
  ),
  _PatternDef(
    id: 'dart-tutoring-id-tostring',
    description:
        'lib/features/tutoring/**/*.dart: .id.toString() (int profile id '
        'stringified across a boundary)',
    fileScope: (root) => _dartFilesUnder('$root/lib/features/tutoring'),
    lineTest: (l) => l.contains('.id.toString()'),
  ),
];

// ---------------------------------------------------------------------------
// File enumeration.
// ---------------------------------------------------------------------------

String _cleanPath(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.startsWith('./') ? normalized.substring(2) : normalized;
}

List<String> _dartFilesUnder(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => _cleanPath(f.path))
      .where(
        (p) =>
            p.endsWith('.dart') &&
            !p.endsWith('.g.dart') &&
            !p.endsWith('.freezed.dart'),
      )
      .toList()
    ..sort();
}

List<String> _tsFilesUnder(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => _cleanPath(f.path))
      .where((p) => p.endsWith('.ts') && !p.endsWith('.test.ts'))
      .toList()
    ..sort();
}

/// Pattern 3's three files are named explicitly, not directory-scanned. A
/// silent rename of any of them would silently zero out that pattern's
/// contribution rather than failing loudly — so their existence is
/// asserted up front, same spirit as check 103's step-0 registry
/// self-check.
void _assertHardcodedScanFilesExist(String root) {
  for (final rel in [
    _tutorWriteServicePath,
    _firestoreGatewayPath,
    _pushPipelinePath,
  ]) {
    if (!File('$root/$rel').existsSync()) {
      stderr.writeln(
        'PROFILE-ID-INT-SITES ABORTED: hardcoded scan file missing: $rel. '
        'This file is one of three named paths the dart-int-profileid-param '
        'pattern scans explicitly (see the tool\'s doc comment) — a rename '
        'or deletion here must update _patterns() in the same commit, not '
        'silently drop this pattern\'s coverage.',
      );
      exit(1);
    }
  }
}

// ---------------------------------------------------------------------------
// Comment/string stripping (structural analysis only — never used for
// pattern matching, which runs against raw lines; see [_PatternDef]'s doc).
// ---------------------------------------------------------------------------

(String code, bool blockCommentOpen) _stripCodeLine(
  String line,
  bool blockCommentOpen,
) {
  final buffer = StringBuffer();
  final len = line.length;
  var i = 0;
  var inBlock = blockCommentOpen;
  while (i < len) {
    if (inBlock) {
      final end = line.indexOf('*/', i);
      if (end == -1) return (buffer.toString(), true);
      buffer.write(' ');
      i = end + 2;
      inBlock = false;
      continue;
    }
    final ch = line[i];
    if (ch == '/' && i + 1 < len && line[i + 1] == '/') break;
    if (ch == '/' && i + 1 < len && line[i + 1] == '*') {
      inBlock = true;
      i += 2;
      continue;
    }
    if (ch == "'" || ch == '"') {
      final quote = ch;
      buffer.write(' ');
      i++;
      while (i < len) {
        if (line[i] == r'\' && i + 1 < len) {
          i += 2;
          continue;
        }
        if (line[i] == quote) {
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    buffer.write(ch);
    i++;
  }
  return (buffer.toString(), inBlock);
}

List<String> _stripFile(List<String> lines) {
  final out = <String>[];
  var inBlock = false;
  for (final line in lines) {
    final (code, stillOpen) = _stripCodeLine(line, inBlock);
    out.add(code);
    inBlock = stillOpen;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Enclosing-symbol resolution: a brace-depth scope stack over STRIPPED
// lines. Not a full parser — see the library doc comment's "known blind
// spots" paragraph.
// ---------------------------------------------------------------------------

final _dartClassRe = RegExp(
  r'^(?:(?:abstract|base|interface|final|sealed|mixin)\s+)*class\s+(\w+)',
);
// The generic-argument character class includes `?` — a nullable inner
// type (`Future<Map<String, dynamic>?>`) is common enough in this codebase
// that omitting it silently fails the whole alternative (regex engines
// don't "partially" match a character class), which silently drops the
// enclosing-function frame for that declaration entirely rather than
// producing a slightly-wrong name — caught by the deliberate red-demo this
// tool's own doc comment requires before every commit that touches a
// pattern (see docs/planning/firestore-phase2-plan.md §4 P2-1).
final _dartFuncRe = RegExp(
  r'^\s*(?:@override\s+)?(?:static\s+)?'
  r'(?:Future<[\w\s,<>?\[\]]*>|Stream<[\w\s,<>?\[\]]*>|List<[\w\s,<>?\[\]]*>|'
  r'Map<[\w\s,<>?\[\]]*>|Set<[\w\s,<>?\[\]]*>|void|int|double|bool|num|'
  r'dynamic|String|Widget|[A-Z]\w*(?:<[\w\s,<>?\[\]]*>)?)\s+'
  r'(_?[a-zA-Z]\w*)\s*\(',
);
final _tsConstFuncRe = RegExp(r'^export\s+const\s+(\w+)\s*=');
final _tsFunctionDeclRe = RegExp(
  r'^(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*\(',
);

class _Frame {
  _Frame(this.kind, this.name, this.targetDepth);
  final String kind; // 'class' | 'function'
  final String name;
  final int targetDepth;

  /// Becomes `true` the first time [targetDepth] is exceeded — i.e. the
  /// first time this frame's OWN body brace (not just a same-line named-
  /// parameter-block brace that happens to net to the same depth) has
  /// genuinely opened. See [_buildSymbolIndex]'s doc comment for why this
  /// exists: without it, a multi-line signature whose declaration line has
  /// zero net brace delta (`async function verifyTutorGrant(` — the `{`
  /// arrives several lines later) or that ends in a bare `;` with no body
  /// at all (`Future<void> deleteLearnerProfile(int profileId);`) gets
  /// pushed and then immediately popped on the SAME line, because
  /// `depth == targetDepth` is trivially true right after the push.
  bool opened = false;
}

/// Maps 1-based line number -> enclosing symbol string, for one file, via a
/// brace-depth scope stack over [strippedLines].
///
/// A frame is pushed the moment a class/function declaration is recognised
/// (`targetDepth` = the depth BEFORE this line's own braces apply) and is
/// popped once depth genuinely returns to `targetDepth` AFTER having first
/// exceeded it ([_Frame.opened]) — see that field's doc for why a bare
/// `depth <= targetDepth` check on its own is wrong. A frame that never
/// opens a body at all (an abstract/interface method signature terminated
/// by `;`) is popped as soon as a `;` is seen while it is still unopened —
/// Dart/TS class declarations never legitimately end this way, so the same
/// rule applied to a still-unopened CLASS frame is a no-op, not a risk.
Map<int, String> _buildSymbolIndex(List<String> strippedLines, bool isDart) {
  final stack = <_Frame>[];
  var depth = 0;
  final result = <int, String>{};

  String currentSymbol() {
    String? cls;
    String? fn;
    for (final f in stack) {
      if (f.kind == 'class') cls = f.name;
      if (f.kind == 'function') fn = f.name;
    }
    if (cls != null && fn != null) return '$cls.$fn';
    if (fn != null) return fn;
    if (cls != null) return cls;
    return '<top-level>';
  }

  for (var i = 0; i < strippedLines.length; i++) {
    final line = strippedLines[i];

    // Push any class/function frame this line OPENS before recording this
    // line's own symbol — deliberately, so a single-line declaration whose
    // parameter list (and thus a pattern match) sits on the SAME line as
    // its own name (`Future<void> deleteLearnerProfile(int profileId);`)
    // is attributed to itself, not to its enclosing parent. A multi-line
    // signature is unaffected: the parameter lines that follow the
    // declaration line already see this frame via the normal stack lookup
    // on their own iteration.
    if (isDart) {
      final classM = _dartClassRe.firstMatch(line);
      if (classM != null) {
        stack.add(_Frame('class', classM.group(1)!, depth));
      } else {
        final fnM = _dartFuncRe.firstMatch(line);
        if (fnM != null) stack.add(_Frame('function', fnM.group(1)!, depth));
      }
    } else {
      final constM = _tsConstFuncRe.firstMatch(line);
      final fnM = _tsFunctionDeclRe.firstMatch(line);
      if (constM != null) {
        stack.add(_Frame('function', constM.group(1)!, depth));
      } else if (fnM != null) {
        stack.add(_Frame('function', fnM.group(1)!, depth));
      }
    }

    result[i + 1] = currentSymbol();

    var delta = 0;
    for (var j = 0; j < line.length; j++) {
      if (line[j] == '{') delta++;
      if (line[j] == '}') delta--;
    }
    depth += delta;

    if (stack.isNotEmpty && !stack.last.opened) {
      if (depth > stack.last.targetDepth) {
        stack.last.opened = true;
      } else if (line.contains(';')) {
        // A still-unopened frame whose declaration line (possibly the
        // last of several) ends in `;` never had a body — pop it now
        // rather than waiting for a depth-drop that will never come.
        stack.removeLast();
      }
    }

    while (stack.isNotEmpty &&
        stack.last.opened &&
        depth <= stack.last.targetDepth) {
      stack.removeLast();
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Scanning.
// ---------------------------------------------------------------------------

class _Entry implements Comparable<_Entry> {
  _Entry(this.patternId, this.file, this.symbol, this.exampleLine);
  final String patternId;
  final String file;
  final String symbol;
  final int exampleLine; // first matching raw line, for --report only

  String get key => '$patternId $file:$symbol';

  @override
  int compareTo(_Entry other) => key.compareTo(other.key);

  @override
  String toString() => key;
}

Map<String, List<_Entry>> _scan(String root) {
  final byPattern = <String, List<_Entry>>{};
  for (final pattern in _patterns()) {
    final seen = <String, _Entry>{};
    for (final path in pattern.fileScope(root)) {
      final file = File(path);
      if (!file.existsSync()) continue;
      List<String> rawLines;
      try {
        rawLines = file.readAsLinesSync();
      } on FileSystemException {
        continue;
      }
      final cleanPath = _cleanPath(path).replaceFirst('$root/', '');
      final stripped = _stripFile(rawLines);
      final symbolIndex = _buildSymbolIndex(
        stripped,
        cleanPath.endsWith('.dart'),
      );
      for (var i = 0; i < rawLines.length; i++) {
        if (!pattern.lineTest(rawLines[i])) continue;
        final lineNo = i + 1;
        final symbol = symbolIndex[lineNo] ?? '<top-level>';
        final entry = _Entry(pattern.id, cleanPath, symbol, lineNo);
        seen.putIfAbsent(entry.key, () => entry);
      }
    }
    byPattern[pattern.id] = seen.values.toList()..sort();
  }
  return byPattern;
}

// ---------------------------------------------------------------------------
// Baseline I/O.
// ---------------------------------------------------------------------------

String _patternListHash() {
  final descriptor = _patterns()
      .map((p) => '${p.id}|${p.description}')
      .join('\n');
  return sha256.convert(utf8.encode(descriptor)).toString();
}

class _Baseline {
  _Baseline({required this.entries, required this.hash});
  final Set<String> entries;
  final String? hash;
}

/// Reads and validates the baseline file's required sentinel header
/// (design correction 3). Returns `null` — never an empty-but-valid
/// baseline — when the file is missing, unreadable, or missing either
/// sentinel line; callers must treat `null` as a hard failure, not as
/// "zero tracked entries."
_Baseline? _readBaseline(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final List<String> lines;
  try {
    lines = file.readAsLinesSync();
  } on FileSystemException {
    return null;
  }
  final hasFormatSentinel = lines.any((l) => l.trim() == _formatSentinel);
  String? hashLine;
  for (final l in lines) {
    final trimmed = l.trim();
    if (trimmed.startsWith(_hashPrefix)) {
      hashLine = trimmed;
      break;
    }
  }
  if (!hasFormatSentinel || hashLine == null) return null;
  final hash = hashLine.substring(_hashPrefix.length).trim();
  final entries = lines
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
  return _Baseline(entries: entries, hash: hash);
}

void _writeBaseline(String path, List<String> sortedEntries) {
  final buffer = StringBuffer()
    ..writeln(_formatSentinel)
    ..writeln('$_hashPrefix${_patternListHash()}')
    ..writeln(
      '# generated by tool/check_profile_id_int_sites.dart '
      '--update-baseline.',
    )
    ..writeln(
      '# Each line is one tracked entry: <pattern-id> <file>:'
      '<enclosing-symbol> — never a line number (lines move).',
    )
    ..writeln('# A new entry NOT listed here fails `make audit`/`make ci`.')
    ..writeln('# A listed entry NO LONGER present in the scan ALSO fails —')
    ..writeln('# a fix must remove its line here in the same commit.')
    ..writeln('# Widening this file (adding a NEW entry without a matching')
    ..writeln('# code fix elsewhere) requires the same sign-off any other')
    ..writeln('# ratchet widening requires.')
    ..writeln('# docs/planning/firestore-phase2-plan.md §4 P2-1 / §7 R2, R12.');
  for (final e in sortedEntries) {
    buffer.writeln(e);
  }
  File(path).writeAsStringSync(buffer.toString());
}

// ---------------------------------------------------------------------------
// main.
// ---------------------------------------------------------------------------

void main(List<String> args) {
  final root = _flagValue(args, '--root', '.');
  final report = args.contains('--report');
  final updateBaseline = args.contains('--update-baseline');
  final baselinePath = _flagValue(args, '--baseline', _baselinePath);

  _assertHardcodedScanFilesExist(root);

  final byPattern = _scan(root);
  final allEntries = <_Entry>[for (final list in byPattern.values) ...list]
    ..sort();
  final allKeys = allEntries.map((e) => e.key).toSet();
  final patternIds = _patterns().map((p) => p.id).toList();
  final scanSetDescription =
      '${patternIds.length} pattern(s) '
      '[${patternIds.join(', ')}]';

  if (report) {
    for (final pattern in _patterns()) {
      final entries = byPattern[pattern.id]!;
      stdout.writeln('--- ${pattern.id} (${entries.length}) ---');
      stdout.writeln('    ${pattern.description}');
      for (final e in entries) {
        stdout.writeln('    ${e.file}:${e.exampleLine} [${e.symbol}]');
      }
    }
    stdout.writeln();
    stdout.writeln(
      'TOTAL: ${allEntries.length} tracked site(s) across $scanSetDescription',
    );
    stdout.writeln('pattern-hash: ${_patternListHash()}');
    return;
  }

  if (updateBaseline) {
    final sorted = allKeys.toList()..sort();
    _writeBaseline(baselinePath, sorted);
    stdout.writeln(
      'Baseline updated: ${sorted.length} entr${sorted.length == 1 ? 'y' : 'ies'} '
      'recorded in $baselinePath across $scanSetDescription.',
    );
    return;
  }

  final baseline = _readBaseline(baselinePath);
  if (baseline == null) {
    stderr.writeln(
      'PROFILE-ID-INT-SITES FAILED: baseline file $baselinePath is '
      'missing, unreadable, or missing its required header sentinel '
      '($_formatSentinel plus a $_hashPrefix<hex> line). A gate whose clean '
      'state is a small text file must never treat "absent" as "verified '
      'empty" — run `dart run tool/check_profile_id_int_sites.dart '
      '--update-baseline` to (re)generate it, with the same sign-off any '
      'other ratchet widening requires.',
    );
    exit(1);
  }

  final currentHash = _patternListHash();
  if (baseline.hash != currentHash) {
    stderr.writeln(
      'PROFILE-ID-INT-SITES FAILED: baseline pattern-hash mismatch. The '
      'baseline at $baselinePath was written against a different pattern '
      'list than the one this run just scanned with (baseline: '
      '${baseline.hash}, current: $currentHash). Per this tool\'s doc '
      'comment, a commit that changes a scan pattern must not also change '
      'code that pattern covers — re-run with --update-baseline to record '
      'the new pattern list\'s baseline as its own reviewed step, in a '
      'commit that changes only the scanner.',
    );
    exit(1);
  }

  final newEntries = allKeys.difference(baseline.entries).toList()..sort();
  final staleEntries = baseline.entries.difference(allKeys).toList()..sort();

  if (newEntries.isNotEmpty || staleEntries.isNotEmpty) {
    if (newEntries.isNotEmpty) {
      stderr.writeln(
        'PROFILE-ID-INT-SITES FAILED — ${newEntries.length} NEW int-keyed '
        'profile-identity site(s) not in the tracked baseline '
        '($baselinePath):',
      );
      for (final k in newEntries) {
        stderr.writeln('  NEW: $k');
      }
    }
    if (staleEntries.isNotEmpty) {
      stderr.writeln(
        '${newEntries.isEmpty ? 'PROFILE-ID-INT-SITES FAILED — ' : ''}'
        '${staleEntries.length} baseline entr'
        '${staleEntries.length == 1 ? 'y is' : 'ies are'} STALE (present in '
        '$baselinePath, absent from the current scan) — a fix must remove '
        'its baseline line in the same commit that lands it:',
      );
      for (final k in staleEntries) {
        stderr.writeln('  STALE: $k');
      }
    }
    stderr.writeln(
      '\nIf a NEW entry is genuine and reviewed, widen the ratchet with '
      '`dart run tool/check_profile_id_int_sites.dart --update-baseline` '
      '(team sign-off required, same as any other ratchet widening) — '
      'never to make a real regression disappear. If a STALE entry is a '
      'real fix, the same command locks the win in — never left dangling '
      'so a later regression could silently re-add the same site under a '
      'different one that happens to net out even.',
    );
    exit(1);
  }

  stdout.writeln(
    'PROFILE-ID-INT-SITES OK: ${allEntries.length} tracked site(s) across '
    '$scanSetDescription; 0 new, 0 stale.',
  );
}

String _flagValue(List<String> args, String flag, String fallback) {
  final i = args.indexOf(flag);
  return (i != -1 && i + 1 < args.length) ? args[i + 1] : fallback;
}
