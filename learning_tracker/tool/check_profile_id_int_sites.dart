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
/// ## NAMED-ENTRY RATCHET, keyed by `<pattern-id> <file>:<enclosing-symbol>`,
/// CARRYING AN OCCURRENCE COUNT
///
/// This is corrections 1-5 from the plan's reviewer round plus a P2-11
/// hardening pass, load-bearing — earlier drafts of this gate were killed
/// over exactly these points, and P2-11 closed a real fail-open a mid-phase
/// review found in the first shipped version:
///
/// 1. **Never line numbers.** A baseline keyed by line number breaks on the
///    next unrelated edit that shifts a line up or down. Every entry here is
///    `<pattern-id> <file>:<enclosing-symbol> xN` — the pattern id first
///    (patterns are independent violation TYPES, not interchangeable; a
///    function flagged by two different patterns is two different facts
///    about it, not one), then the nearest enclosing NAMED Dart
///    class-qualified method (`ClassName.methodName`, or bare `methodName`/
///    `<top-level>` when there is no enclosing class) or TS top-level
///    function/`export const ... = ` binding, resolved by
///    [_buildSymbolIndex] via a brace-depth scope stack — never a raw line
///    offset — and finally `N`, the OCCURRENCE COUNT (see point 5).
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
/// 3. **The OK line prints its scan set, its entry count, AND its raw site
///    count, distinctly.** A gate whose reported number depends on which
///    patterns it runs must publish those patterns in the same line that
///    reports the number, or "N sites, 0 new, 0 stale" is a claim about the
///    scanner, not about the code — see the OK-line format in [main]'s
///    normal-mode branch. Because one entry can now cover several raw
///    matching lines (point 5), "how many locations are tracked" (entries)
///    and "how many raw lines matched" (sites) are two different numbers
///    and this tool reports both, under those names, rather than letting
///    one silently stand in for the other (the exact confusion a mid-phase
///    review found: the first shipped version printed "N tracked site(s)"
///    when N was actually an entry count).
/// 4. **The baseline file REQUIRES a header sentinel**: `# format:
///    profile-id-int-sites v2` plus a `# pattern-hash: <hex>` line covering
///    the ordered pattern list, INCLUDING its matching logic, not just its
///    prose (see [_patternListHash] and point 6 below). A baseline file
///    that is missing, empty, or present-but-missing either sentinel line
///    EXITS 1 rather than being read as "zero tracked entries" — for a gate
///    whose clean state is a small, humanly-editable text file, "absent"
///    must never be silently indistinguishable from "verified empty." The
///    format bumped `v1` → `v2` at P2-11 specifically so an old-format
///    baseline (entries with no ` xN` suffix) is rejected outright as
///    missing-sentinel rather than silently misparsed as "0 occurrences
///    everywhere." De facto strengthening: the pattern-hash is also
///    VERIFIED against the scanner's live pattern list on every
///    non-`--update-baseline` run (see [main]) — a baseline written against
///    a different pattern set than the one currently running is exactly the
///    "narrowed scanner" failure mode point 6 exists to prevent, and
///    printing the hash alone without checking it would make that check
///    decorative rather than real.
/// 5. **Occurrence count is part of the ratchet identity, not just the
///    location — this is the P2-11 fix.** The first shipped version of this
///    gate deduped every matching raw line down to ONE entry per
///    `<pattern-id> <file>:<symbol>` location
///    (`seen.putIfAbsent(entry.key, () => entry)`), which meant N matching
///    lines inside one already-baselined symbol collapsed to the SAME single
///    entry regardless of N: going from 2 int-keyed sites to 3 inside an
///    already-baselined method printed no NEW line, and going from 3 to 1
///    printed no STALE line — the gate stayed green through both, on the
///    exact violation class Phase 3's ~96-file move will produce, which is
///    this gate's entire stated reason to exist. Concretely, pre-fix: all
///    three of `manage_tutors_screen.dart`'s `.id.toString()` calls at lines
///    293/298/312 sat inside the same `_ChildGrantsSection.build` method and
///    collapsed to one entry with no count attached at all — a fourth call
///    added anywhere in that method changed nothing the gate could see.
///    Post-fix, that location's entry is `dart-tutoring-id-tostring
///    lib/features/tutoring/presentation/screens/manage_tutors_screen.dart:
///    _ChildGrantsSection.build xN`: moving any of those call sites within
///    the method still changes no baseline line (point 1's guarantee is
///    unchanged), but ADDING or REMOVING an occurrence inside that same
///    method changes `N`, which is now a THIRD ratchet-failure kind
///    (CHANGED, alongside NEW and STALE) — the two-way ratchet in point 2
///    becomes three-way. A CHANGED location is reported distinctly from an
///    unrelated NEW+STALE pair precisely because it is the SAME location
///    with a different count, not a site that moved.
/// 6. **The pattern-hash covers the matching logic itself, not just
///    hand-written prose — this is the other half of the P2-11 fix.** The
///    first shipped version hashed only `<id>|<description>` — free-text
///    written by whoever authored the pattern — while the actual matching
///    behaviour lived in opaque `fileScope`/`lineTest` closures the hash
///    never touched: editing a regex or narrowing a file-scope exclusion
///    left the hash byte-identical, so the "narrowed scanner" failure mode
///    point 4 above claims this sentinel catches was, in fact, undetectable
///    by it. Fixed by removing the closures entirely: [_PatternDef] now
///    carries its scope (a [_ScopeKind] plus a directory or an exact file
///    list) and its match test (literal `needles` and/or a [RegExp]) as
///    plain DATA fields. [_PatternDef.matchSignature] is built directly from
///    those same fields — the ones [_PatternDef.fileScope] and
///    [_PatternDef.lineTest] actually run against, not a second,
///    independently-typed description of them — and [_patternListHash]
///    hashes it alongside the id and the free-text description. There is no
///    longer a code path that can change what a pattern matches without
///    also changing the hash.
///
/// ## The rule that keeps this gate honest across a commit
///
/// **The commit that changes a scan pattern (adds, removes, or edits a
/// [_ScopeKind]/directory/file-list/needle/regex in [_patterns]) may NOT
/// also change code that pattern covers.** A commit that narrows what the
/// scanner looks for and, in the same diff, deletes the code the
/// narrowed-away portion used to flag can make this gate report a fix that
/// never happened — the gate would go green because it stopped looking, not
/// because the site closed. Change the scanner in one commit (which will
/// change `--update-baseline`'s output, including the pattern-hash, and
/// must be reviewed as such); change the code the old scanner caught in a
/// separate commit, where a STALE-entry or CHANGED-count failure proves the
/// fix really happened.
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
/// ## Suspect-read hardening (P2-11)
///
/// Every line-read in this file — every scanned source file and the
/// baseline file itself — goes through [_readLinesVerified], the same F4
/// hardening `check_profile_path_keying.dart` (audit check 103) carries
/// (`docs/planning/firestore-cutover-log.md:849-856` records the lesson):
/// it throws [_SuspectRead] (never silently substituting empty/partial
/// content) when a file's on-disk length changes mid-read, or a nonzero-
/// length file decodes to zero lines. [main] aborts the ENTIRE run the
/// moment this is thrown, printing "PROFILE-ID-INT-SITES ABORTED (not a
/// real violation)" so a torn/concurrent read can never be mistaken for a
/// genuine NEW/STALE/CHANGED finding. This replaces the first shipped
/// version's bare `on FileSystemException { continue; }` around each read,
/// which silently dropped that file's contribution from the scan and let a
/// torn read silently reclassify a symbol's occurrence count as a code
/// change. A file genuinely deleted between directory listing and read (a
/// real `FileSystemException`, a different exception type from
/// [_SuspectRead]) is still skipped, not aborted — that is a legitimate
/// TOCTOU race, not a torn read.
///
/// Usage:
///   dart run tool/check_profile_id_int_sites.dart
///   dart run tool/check_profile_id_int_sites.dart --report
///   dart run tool/check_profile_id_int_sites.dart --update-baseline
///
/// Exit codes (ratchet mode):
///   0 — no NEW entry, no STALE baseline entry, and no baselined entry's
///       occurrence count CHANGED
///   1 — a NEW entry, a STALE baseline entry, a CHANGED occurrence count, a
///       missing/sentinel-less baseline, a malformed baseline line, a
///       pattern-hash mismatch, a missing hardcoded scan file (pattern 3's
///       three named files are asserted to exist; a silent rename there
///       would silently zero out that pattern), or a suspect (torn) read
///       detected mid-scan (printed as ABORTED, not FAILED — see the
///       "Suspect-read hardening" section above)
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

const _baselinePath = 'tool/profile_id_int_sites_baseline.txt';
const _formatSentinel = '# format: profile-id-int-sites v2';
const _hashPrefix = '# pattern-hash: ';

// ---------------------------------------------------------------------------
// Pattern definitions — this list IS the scan set printed in every mode.
// ---------------------------------------------------------------------------

const _tutorWriteServicePath =
    'lib/features/tutoring/data/services/tutor_write_service.dart';
const _firestoreGatewayPath = 'lib/core/sync/firestore_gateway.dart';
const _pushPipelinePath = 'lib/core/sync/outbox/push_pipeline.dart';

final _intProfileIdParamRe = RegExp(r'\bint\s+profileId\b');

/// How [_PatternDef.fileScope] enumerates candidate files. Kept as DATA
/// (never a closure) so [_PatternDef.matchSignature] — and therefore
/// [_patternListHash] — can see it; see the P2-11 doc section above.
enum _ScopeKind { tsUnderDir, dartUnderDir, exactFiles }

/// One tracked violation TYPE. Every field here is plain data, not a
/// closure: [fileScope] and [lineTest] are ordinary methods computed FROM
/// these fields, and [matchSignature] is built from the exact same fields —
/// there is no second, independently-maintained description of what this
/// pattern matches for the hash to drift away from (P2-11; see the library
/// doc comment's point 6).
///
/// [lineTest] runs against the RAW (unstripped) line text — deliberately
/// raw, not comment/string-stripped, because several patterns
/// (`typeof profileId !== "number"`, `.doc(String(profileId))`) match
/// through a string literal that stripping would blank out.
class _PatternDef {
  _PatternDef({
    required this.id,
    required this.description,
    required this.scopeKind,
    this.scopeDir,
    this.scopeFiles,
    this.needles = const [],
    this.regex,
  }) : assert(
         scopeKind == _ScopeKind.exactFiles
             ? (scopeFiles != null && scopeDir == null)
             : (scopeDir != null && scopeFiles == null),
         'exactFiles scope requires scopeFiles (and no scopeDir); '
         'tsUnderDir/dartUnderDir scope requires scopeDir (and no '
         'scopeFiles)',
       ),
       assert(
         needles.isNotEmpty || regex != null,
         'a pattern must test raw lines against at least one needle or '
         'regex',
       );

  final String id;
  final String description;
  final _ScopeKind scopeKind;

  /// Relative to `--root`, for [_ScopeKind.tsUnderDir]/
  /// [_ScopeKind.dartUnderDir] only.
  final String? scopeDir;

  /// Relative to `--root`, for [_ScopeKind.exactFiles] only.
  final List<String>? scopeFiles;

  /// Raw-line substring tests — a line matches if it contains ANY of these.
  final List<String> needles;

  /// Raw-line regex test, ORed with [needles] if both are present.
  final RegExp? regex;

  List<String> fileScope(String root) {
    switch (scopeKind) {
      case _ScopeKind.tsUnderDir:
        return _tsFilesUnder('$root/$scopeDir');
      case _ScopeKind.dartUnderDir:
        return _dartFilesUnder('$root/$scopeDir');
      case _ScopeKind.exactFiles:
        return [for (final f in scopeFiles!) '$root/$f'];
    }
  }

  bool lineTest(String rawLine) {
    if (needles.any(rawLine.contains)) return true;
    return regex != null && regex!.hasMatch(rawLine);
  }

  /// Canonical text this pattern actually tests — built from the SAME data
  /// [fileScope]/[lineTest] run against, never hand-typed prose that could
  /// drift from them. Feeds [_patternListHash]: editing a needle, a regex,
  /// or a scope directory/file list necessarily edits one of these fields,
  /// which necessarily changes this string, which necessarily changes the
  /// hash — there is no code path that can narrow what a pattern matches
  /// without moving the hash (P2-11; see the library doc comment's point 6).
  String get matchSignature =>
      'scope=${scopeKind.name}:${scopeDir ?? scopeFiles!.join(",")}'
      '|needles=${needles.join(",")}'
      '|regex=${regex?.pattern ?? ""}';
}

List<_PatternDef> _patterns() => [
  _PatternDef(
    id: 'cf-int-guard',
    description:
        'functions/src/**/*.ts (excl *.test.ts): typeof profileId !== '
        '"number" / Number.isInteger(profileId) runtime guard',
    scopeKind: _ScopeKind.tsUnderDir,
    scopeDir: 'functions/src',
    needles: const [
      'typeof profileId !== "number"',
      'Number.isInteger(profileId)',
    ],
  ),
  _PatternDef(
    id: 'cf-string-profileid-doc',
    description:
        'functions/src/**/*.ts (excl *.test.ts): .doc(String(profileId)) '
        'doc-id formula against learner_profiles',
    scopeKind: _ScopeKind.tsUnderDir,
    scopeDir: 'functions/src',
    needles: const ['.doc(String(profileId))'],
  ),
  _PatternDef(
    id: 'dart-int-profileid-param',
    description:
        '$_tutorWriteServicePath, $_firestoreGatewayPath, '
        '$_pushPipelinePath: int profileId parameter (interface/service '
        'level only — not all 179 occurrences under lib/core/sync/**, '
        'which dies wholesale in Phase 4)',
    scopeKind: _ScopeKind.exactFiles,
    scopeFiles: const [
      _tutorWriteServicePath,
      _firestoreGatewayPath,
      _pushPipelinePath,
    ],
    regex: _intProfileIdParamRe,
  ),
  _PatternDef(
    id: 'dart-tutoring-int-parse',
    description:
        'lib/features/tutoring/**/*.dart: int.tryParse (profile-id-as-int '
        'parsing)',
    scopeKind: _ScopeKind.dartUnderDir,
    scopeDir: 'lib/features/tutoring',
    needles: const ['int.tryParse'],
  ),
  _PatternDef(
    id: 'dart-tutoring-id-tostring',
    description:
        'lib/features/tutoring/**/*.dart: .id.toString() (int profile id '
        'stringified across a boundary)',
    scopeKind: _ScopeKind.dartUnderDir,
    scopeDir: 'lib/features/tutoring',
    needles: const ['.id.toString()'],
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
// Suspect-read hardening (P2-11) — mirrors
// check_profile_path_keying.dart's _readLinesVerified/_SuspectRead
// (audit check 103's F4 fix) exactly, so every line-read in THIS file is
// also torn-read-safe. Deliberately NOT caught by any scanning helper
// below — it propagates to `main`'s top-level handler and aborts the
// whole run rather than silently scanning corrupted content.
// ---------------------------------------------------------------------------

/// Thrown by [_readLinesVerified] when a file read looks TORN rather than
/// genuinely absent/deleted. See that function's doc comment.
class _SuspectRead implements Exception {
  _SuspectRead(this.path, this.reason);
  final String path;
  final String reason;

  @override
  String toString() => 'SUSPECT READ: $path — $reason';
}

/// Every line-read in this file goes through this function rather than a
/// bare `file.readAsLinesSync()`. Two cheap, no-false-positive-on-a-
/// quiescent-tree signals are checked, identical to check 103's own F4
/// hardening:
///   1. The file's on-disk length differs between immediately before and
///      immediately after the read — another process wrote to it inside
///      our own read window.
///   2. The file is non-empty on disk but decoded to ZERO lines — no
///      genuinely non-empty source/baseline file in this repo should ever
///      decode to nothing; that combination is truncation, not content.
/// Either signal throws [_SuspectRead], which aborts the whole run rather
/// than silently treating truncated content as "this file has no
/// int-keyed sites" (which could just as easily HIDE a real NEW site as
/// fabricate a phantom CHANGED one, if the truncation happens to land
/// mid-token). A genuinely missing/deleted file raises a real
/// `FileSystemException` instead (a different exception type), which
/// callers below catch and treat as TOCTOU-safe skip, not an abort.
List<String> _readLinesVerified(File file) {
  final lengthBefore = file.lengthSync();
  final lines = file.readAsLinesSync();
  final lengthAfter = file.lengthSync();
  if (lengthBefore != lengthAfter) {
    throw _SuspectRead(
      file.path,
      'on-disk length changed during read ($lengthBefore -> $lengthAfter '
      'bytes) — another process wrote to this file while this checker was '
      'reading it',
    );
  }
  if (lengthBefore > 0 && lines.isEmpty) {
    throw _SuspectRead(
      file.path,
      'file is $lengthBefore byte(s) on disk but decoded to ZERO lines — a '
      'torn/truncated read, not a genuinely empty file',
    );
  }
  return lines;
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

/// One tracked ratchet entry: a `<pattern-id> <file>:<enclosing-symbol>`
/// LOCATION, plus [count] — how many raw lines under that pattern matched
/// inside that one location (P2-11). [count] is part of what gets
/// baselined and compared: a location whose count changes is a CHANGED
/// violation, not a silently-absorbed no-op (the fail-open this class
/// fixes — see the library doc comment's point 5).
class _Entry implements Comparable<_Entry> {
  _Entry(this.patternId, this.file, this.symbol, this.count, this.lines);
  final String patternId;
  final String file;
  final String symbol;
  final int count;

  /// Every matching raw line number that fed [count], for `--report` only.
  /// Never used as part of the ratchet identity — lines move.
  final List<int> lines;

  /// The LOCATION this entry identifies — pattern + file + symbol. Never
  /// includes [count]: this is what a NEW/STALE/CHANGED comparison keys
  /// off of, so a count change at the SAME location is recognised as one
  /// CHANGED entry, not an unrelated NEW-here/STALE-there pair.
  String get locationKey => '$patternId $file:$symbol';

  /// The full baseline-file line: location plus its occurrence count.
  String get baselineLine => '$locationKey x$count';

  @override
  int compareTo(_Entry other) => locationKey.compareTo(other.locationKey);

  @override
  String toString() => baselineLine;
}

Map<String, List<_Entry>> _scan(String root) {
  final byPattern = <String, List<_Entry>>{};
  for (final pattern in _patterns()) {
    // locationKey -> accumulated count + example line numbers. Replaces the
    // pre-P2-11 `seen.putIfAbsent(entry.key, () => entry)` dedup, which
    // discarded every match after the first inside a given location instead
    // of counting them — the fail-open this class exists to close.
    final counts = <String, int>{};
    final linesByLocation = <String, List<int>>{};
    final fileByLocation = <String, String>{};
    final symbolByLocation = <String, String>{};

    for (final path in pattern.fileScope(root)) {
      final file = File(path);
      if (!file.existsSync()) continue;
      List<String> rawLines;
      try {
        rawLines = _readLinesVerified(file);
      } on FileSystemException {
        // TOCTOU-safe: the file was listed, then deleted/moved before we
        // could read it. A real FileSystemException, not a _SuspectRead —
        // skipping is correct, a file that no longer exists cannot
        // contribute a site. A torn/truncated read is a DIFFERENT
        // exception ([_SuspectRead]) and is deliberately not caught here —
        // it propagates to `main` and aborts the whole run instead.
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
        final loc = '${pattern.id} $cleanPath:$symbol';
        counts[loc] = (counts[loc] ?? 0) + 1;
        (linesByLocation[loc] ??= []).add(lineNo);
        fileByLocation[loc] = cleanPath;
        symbolByLocation[loc] = symbol;
      }
    }

    final entries =
        counts.keys
            .map(
              (loc) => _Entry(
                pattern.id,
                fileByLocation[loc]!,
                symbolByLocation[loc]!,
                counts[loc]!,
                linesByLocation[loc]!,
              ),
            )
            .toList()
          ..sort();
    byPattern[pattern.id] = entries;
  }
  return byPattern;
}

// ---------------------------------------------------------------------------
// Baseline I/O.
// ---------------------------------------------------------------------------

String _patternListHash() {
  final descriptor = _patterns()
      .map((p) => '${p.id}|${p.description}|${p.matchSignature}')
      .join('\n');
  return sha256.convert(utf8.encode(descriptor)).toString();
}

/// One parsed baseline-file line: the location it names, and the
/// occurrence count it was baselined at.
class _ParsedBaselineLine {
  _ParsedBaselineLine(this.locationKey, this.count);
  final String locationKey;
  final int count;
}

final _baselineLineRe = RegExp(r'^(.*) x(\d+)$');

/// Parses one non-comment baseline line (`<pattern-id> <file>:<symbol>
/// xN`). Returns `null` for anything that doesn't match that shape —
/// callers must treat that as a hard baseline-format failure (a hand-edit
/// gone wrong, or a stale pre-P2-11 `v1` line with no occurrence count),
/// never as "0 occurrences" or a silently-skipped line.
_ParsedBaselineLine? _parseBaselineLine(String line) {
  final m = _baselineLineRe.firstMatch(line);
  if (m == null) return null;
  return _ParsedBaselineLine(m.group(1)!, int.parse(m.group(2)!));
}

class _Baseline {
  _Baseline({required this.byLocation, required this.hash});

  /// locationKey -> its baselined entry (location + occurrence count).
  final Map<String, _ParsedBaselineLine> byLocation;
  final String? hash;
}

/// Reads and validates the baseline file's required sentinel header
/// (design correction 3) and parses every entry line into its location and
/// occurrence count (P2-11). Returns `null` — never an empty-but-valid
/// baseline — when the file is missing or missing either sentinel line;
/// callers must treat `null` as a hard failure, not as "zero tracked
/// entries." A torn/truncated read of an EXISTING baseline file throws
/// [_SuspectRead] (via [_readLinesVerified]), deliberately NOT caught
/// here — it propagates to `main` and aborts the run.
_Baseline? _readBaseline(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final List<String> lines;
  try {
    lines = _readLinesVerified(file);
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

  final byLocation = <String, _ParsedBaselineLine>{};
  for (final raw in lines) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parsed = _parseBaselineLine(trimmed);
    if (parsed == null) {
      stderr.writeln(
        'PROFILE-ID-INT-SITES FAILED: baseline line does not match the '
        'required "<pattern-id> <file>:<symbol> xN" format ($path expects '
        'every entry to carry its occurrence count under $_formatSentinel): '
        '"$trimmed". Regenerate with --update-baseline — this is either a '
        'hand-edit gone wrong or a stale pre-v2 line with no count.',
      );
      exit(1);
    }
    byLocation[parsed.locationKey] = parsed;
  }
  return _Baseline(byLocation: byLocation, hash: hash);
}

void _writeBaseline(String path, List<_Entry> sortedEntries) {
  final buffer = StringBuffer()
    ..writeln(_formatSentinel)
    ..writeln('$_hashPrefix${_patternListHash()}')
    ..writeln(
      '# generated by tool/check_profile_id_int_sites.dart '
      '--update-baseline.',
    )
    ..writeln(
      '# Each line is one tracked entry: <pattern-id> <file>:'
      '<enclosing-symbol> xN — N is the occurrence count (how many',
    )
    ..writeln('# matching raw lines collapsed into this one location). Never a')
    ..writeln('# line number (lines move).')
    ..writeln('# A new entry NOT listed here fails `make audit`/`make ci`.')
    ..writeln('# A listed entry NO LONGER present in the scan ALSO fails —')
    ..writeln('# a fix must remove its line here in the same commit.')
    ..writeln('# A listed entry whose occurrence count N no longer matches the')
    ..writeln(
      '# current scan ALSO fails (CHANGED) — an int-keyed site added or',
    )
    ..writeln('# removed INSIDE an already-baselined symbol is not silently')
    ..writeln('# absorbed.')
    ..writeln('# Widening this file (adding a NEW entry, or raising an')
    ..writeln('# existing entry\'s N, without a matching code fix elsewhere)')
    ..writeln('# requires the same sign-off any other ratchet widening')
    ..writeln('# requires.')
    ..writeln('# docs/planning/firestore-phase2-plan.md §4 P2-1 / §7 R2, R12.');
  for (final e in sortedEntries) {
    buffer.writeln(e.baselineLine);
  }
  File(path).writeAsStringSync(buffer.toString());
}

// ---------------------------------------------------------------------------
// main.
// ---------------------------------------------------------------------------

/// The ENTIRE run is wrapped here so a [_SuspectRead] thrown anywhere
/// (baseline file, any scanned source file) aborts loudly instead of
/// letting [_run] finish on corrupted content — mirrors
/// `check_profile_path_keying.dart`'s own top-level handler exactly
/// (audit check 103's F4 fix). Deliberately NOT "exit code 1 == a real
/// violation": the message says ABORTED, not FAILED, so a human or CI log
/// reader re-runs rather than treating it as a fabricated production
/// regression.
void main(List<String> args) {
  try {
    _run(args);
  } on _SuspectRead catch (e) {
    stderr.writeln('PROFILE-ID-INT-SITES ABORTED (not a real violation): $e');
    stderr.writeln(
      'This is F4-style hardening (same fix check 103 already carries): a '
      'torn/truncated read was detected mid-scan (almost certainly a '
      'concurrent writer to the checkout this checker is scanning, not a '
      'real NEW/STALE/CHANGED profile-identity site). Re-run once the tree '
      'is quiescent — do NOT interpret this as a PROFILE-ID-INT-SITES '
      'violation.',
    );
    exit(1);
  }
}

void _run(List<String> args) {
  final root = _flagValue(args, '--root', '.');
  final report = args.contains('--report');
  final updateBaseline = args.contains('--update-baseline');
  final baselinePath = _flagValue(args, '--baseline', _baselinePath);

  _assertHardcodedScanFilesExist(root);

  final byPattern = _scan(root);
  final allEntries = <_Entry>[for (final list in byPattern.values) ...list]
    ..sort();
  final entryCount = allEntries.length;
  final siteCount = allEntries.fold<int>(0, (sum, e) => sum + e.count);
  final patternIds = _patterns().map((p) => p.id).toList();
  final scanSetDescription =
      '${patternIds.length} pattern(s) '
      '[${patternIds.join(', ')}]';

  if (report) {
    for (final pattern in _patterns()) {
      final entries = byPattern[pattern.id]!;
      final patternSites = entries.fold<int>(0, (sum, e) => sum + e.count);
      stdout.writeln(
        '--- ${pattern.id} (${entries.length} '
        'entr${entries.length == 1 ? 'y' : 'ies'}, $patternSites '
        'site(s)) ---',
      );
      stdout.writeln('    ${pattern.description}');
      for (final e in entries) {
        stdout.writeln(
          '    ${e.file}:${e.symbol} x${e.count} '
          '(lines ${e.lines.join(",")})',
        );
      }
    }
    stdout.writeln();
    stdout.writeln(
      'TOTAL: $entryCount tracked entr${entryCount == 1 ? 'y' : 'ies'} '
      'covering $siteCount site(s) across $scanSetDescription',
    );
    stdout.writeln('pattern-hash: ${_patternListHash()}');
    return;
  }

  if (updateBaseline) {
    _writeBaseline(baselinePath, allEntries);
    stdout.writeln(
      'Baseline updated: $entryCount entr${entryCount == 1 ? 'y' : 'ies'} '
      'covering $siteCount site(s) recorded in $baselinePath across '
      '$scanSetDescription.',
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
      'list (or matching logic — the hash now covers scope/needles/regex, '
      'not just id/description) than the one this run just scanned with '
      '(baseline: ${baseline.hash}, current: $currentHash). Per this '
      'tool\'s doc comment, a commit that changes a scan pattern must not '
      'also change code that pattern covers — re-run with '
      '--update-baseline to record the new pattern list\'s baseline as its '
      'own reviewed step, in a commit that changes only the scanner.',
    );
    exit(1);
  }

  final currentByLocation = <String, _Entry>{
    for (final e in allEntries) e.locationKey: e,
  };
  final currentLocations = currentByLocation.keys.toSet();
  final baselineLocations = baseline.byLocation.keys.toSet();

  final newLocations = currentLocations.difference(baselineLocations).toList()
    ..sort();
  final staleLocations = baselineLocations.difference(currentLocations).toList()
    ..sort();
  final changedLocations =
      currentLocations.intersection(baselineLocations).where((loc) {
        return currentByLocation[loc]!.count != baseline.byLocation[loc]!.count;
      }).toList()..sort();

  if (newLocations.isNotEmpty ||
      staleLocations.isNotEmpty ||
      changedLocations.isNotEmpty) {
    if (newLocations.isNotEmpty) {
      stderr.writeln(
        'PROFILE-ID-INT-SITES FAILED — ${newLocations.length} NEW '
        'int-keyed profile-identity entr'
        '${newLocations.length == 1 ? 'y' : 'ies'} not in the tracked '
        'baseline ($baselinePath):',
      );
      for (final loc in newLocations) {
        stderr.writeln('  NEW: ${currentByLocation[loc]!.baselineLine}');
      }
    }
    if (staleLocations.isNotEmpty) {
      stderr.writeln(
        '${staleLocations.length} baseline entr'
        '${staleLocations.length == 1 ? 'y is' : 'ies are'} STALE (present '
        'in $baselinePath, absent from the current scan) — a fix must '
        'remove its baseline line in the same commit that lands it:',
      );
      for (final loc in staleLocations) {
        final b = baseline.byLocation[loc]!;
        stderr.writeln('  STALE: $loc x${b.count}');
      }
    }
    if (changedLocations.isNotEmpty) {
      stderr.writeln(
        '${changedLocations.length} baseline entr'
        '${changedLocations.length == 1 ? 'y has' : 'ies have'} a CHANGED '
        'occurrence count — an int-keyed site was added or removed INSIDE '
        'an already-baselined symbol (this is what the pre-P2-11 dedup '
        'silently absorbed as "0 new, 0 stale"; it now fails here instead):',
      );
      for (final loc in changedLocations) {
        final before = baseline.byLocation[loc]!.count;
        final after = currentByLocation[loc]!.count;
        stderr.writeln('  CHANGED: $loc baseline x$before -> current x$after');
      }
    }
    stderr.writeln(
      '\nIf a NEW or CHANGED entry is genuine and reviewed, widen the '
      'ratchet with `dart run tool/check_profile_id_int_sites.dart '
      '--update-baseline` (team sign-off required, same as any other '
      'ratchet widening) — never to make a real regression disappear. If a '
      'STALE or a downward CHANGED entry is a real fix, the same command '
      'locks the win in — never left dangling so a later regression could '
      'silently re-add the same site under a count that happens to net out '
      'even.',
    );
    exit(1);
  }

  stdout.writeln(
    'PROFILE-ID-INT-SITES OK: $entryCount tracked entr'
    '${entryCount == 1 ? 'y' : 'ies'} covering $siteCount site(s) across '
    '$scanSetDescription; 0 new, 0 stale, 0 changed.',
  );
}

String _flagValue(List<String> args, String flag, String fallback) {
  final i = args.indexOf(flag);
  return (i != -1 && i + 1 < args.length) ? args[i + 1] : fallback;
}
