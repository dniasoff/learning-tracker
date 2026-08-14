/// Profile-scoped-collection keying-split gate (`docs/firestore-rewrite-map.md`
/// item 10 — "the test suite cannot catch a writer/reader path disagreement,
/// by construction, not by oversight").
///
/// The old sync engine (`lib/core/sync/**`) and Cloud Functions
/// (`functions/src/**`) write `users/{uid}/learner_profiles/{INT}/...` —
/// `FirestoreGatewayImpl._learnerProfileDoc(int profileId)` builds that path
/// via `.doc(profileId.toString())`. Every new Firestore repository under
/// `lib/data/repositories/` reads `users/{uid}/learner_profiles/{ULID}/...`
/// — a String doc-id resolved from `activeProfileDocIdProvider`. These are
/// disjoint document trees: a feature flipped from the old path to the new
/// one reads a tree that nothing writes.
///
/// This is exactly the defect class that produced the bookmarks/
/// learning-order regression on 2026-08-03: taking bookmarks end-to-end
/// silently broke track-creation's initial-bookmark write (wrote INT,
/// read ULID, "no bookmark" overwrote the learner's position) and the
/// custom learning-order branch (queried a collection nothing wrote,
/// silently ignoring a saved custom order) — six regressions in four
/// features nobody was touching, with 144 tests green throughout, because
/// `fake_cloud_firestore` cannot evaluate `resource.data`/`request.resource`
/// and every test seeds its fixture into whichever path the test itself
/// picked, so a writer/reader disagreement is invisible to green tests.
/// This checker is the thing item 10 says test suites structurally cannot
/// be: it traces the real writer/reader graph instead of running fixtures
/// through it.
///
/// ## RATCHET, not a hard gate
///
/// Two collections (`bookmarks`, `learning_order`) are ALREADY known-split
/// in production today — that is the tracked, reviewed backlog this
/// checker inherits, not a new failure it invents. Growth above the
/// tracked baseline ([_baselinePath]) fails the gate; the existing two do
/// not (see [_kCollections]'s docs for how they were verified, and the
/// WATCHLIST section below for collections one wiring change away from
/// joining them).
///
/// The baseline also records eight collections whose Cloud Functions touches
/// are correctly keyed by the profile ULID, but which appear in the
/// conservative INT-B bucket because every deployed `functions/src/**` touch
/// is scanned unconditionally. Those entries are not production splits; they
/// are reviewed exceptions for that bucket definition.
///
/// ## Step 0: the collection registry is self-validated every run
///
/// A prior phase's coordinator handoff claimed "24 collections" when the
/// true count was 14 (24 call sites of one helper, not 24 collections) —
/// a stale number silently propagated. To make that class of drift
/// impossible here, [_kCollections] (this file's hardcoded list) is
/// cross-checked against `firestore.rules` itself on EVERY invocation,
/// including `--report`: this file finds `match /learner_profiles/{profileId}
/// {` and walks its direct (and one-deeper) child `match /<name>/{...}`
/// blocks via a brace-depth counter (not a full parser), and asserts that
/// set is EXACTLY [_kCollections]. A "14 vs 17" (or any other) drift
/// between the rules file and this checker's list can never again pass
/// silently — it hard-fails step 0 before any bucket-scanning runs.
///
/// ## The three touch-buckets
///
/// - **INT-A** (unconditional): every `.dart` file under `lib/core/sync/**`
///   — the condemned old sync engine, deleted wholesale in a later phase.
///   A literal collection-name touch here marks the collection INT with NO
///   liveness filtering: treating the whole tree as one atomic
///   INT-contributing unit means its eventual deletion can only ever
///   REMOVE touches, so the derived split-set is structurally
///   monotonic-shrinking on that deletion with zero special-case code.
/// - **INT-B** (unconditional): every `.ts` file under `functions/src/**`
///   (excluding `*.test.ts`) — every function there is barrel-exported from
///   `functions/src/index.ts` and therefore DEPLOYED and externally
///   callable regardless of whether the Flutter client currently invokes
///   it. Cloud Functions liveness is "is it deployed", deliberately more
///   conservative than the ULID bucket below.
/// - **ULID-C** (liveness-filtered): every `.dart` file under
///   `lib/data/repositories/**` OR `lib/features/**/data/repositories/**` —
///   the latter is the sanctioned migration seam (audit check 102 permits
///   `lib/features/**/data/repositories/` to import the data ring); no
///   `firestore_`-prefixed-filename requirement (see F1 below — the
///   feature-level Adapter files are NOT filename-consistent at all). A
///   literal touch in file F contributes to the collection's ULID set ONLY
///   IF F is "reachable" per the algorithm below — a raw touch alone is NOT
///   sufficient (verified: most `firestore_*.dart` adapters are dead code
///   today, wired to nothing outside their own repository directory;
///   treating raw touches as live would balloon the baseline into noise the
///   gate could never distinguish a real future regression against — the
///   definition of theatre).
///
/// ### The reachability algorithm
///
/// For a raw repository file F: find F's own primary class (`class
/// Firestore\w+`, including any Dart 3 class-modifier prefix — see
/// [_classFirestoreRe]'s own doc comment for F3), then:
///   1. HOP 1B — grep all of `lib/**` (excluding F and
///      `repository_providers.dart`) for a DIRECT construction of F's
///      primary class (`<PrimaryClass>(`). If any hit lands outside
///      `/data/repositories/` → LIVE, independent of any provider wiring.
///      (F2: closes the gap where a class is `new`'d straight inside a
///      presentation widget, bypassing the provider layer entirely — the
///      pre-fix checker could only ever find a reference to the provider
///      IDENTIFIER, never a class built without one.)
///   2. Find the provider identifier P in `lib/data/firestore/
///      repository_providers.dart` whose body does `return <F's class>(`.
///      No such wiring → DEAD (HOP 1B already ran; nothing left to try).
///   3. HOP 1 — grep all of `lib/**` (excluding F, excluding
///      `repository_providers.dart`, excluding `test/`) for P. If any
///      referencing file does NOT contain `/data/repositories/` → LIVE.
///   4. HOP 2 — for each HOP-1 referencing file that DOES still sit inside
///      `/data/repositories/` (an Adapter class, typically), extract every
///      `Firestore\w+`-named class it declares and grep all of `lib/**`
///      for `<ClassName>(`. If any hit lands outside `/data/repositories/`
///      → LIVE.
///   5. Otherwise → DEAD; F's touches do not enter the liveness-filtered
///      ULID-C bucket (they still count toward the WATCHLIST below).
///
/// **Deviation from a fully-generic HOP-2 class extraction, verified by
/// direct reproduction:** a fully-generic `class (\w+)` extraction over the
/// HOP-1 file (rather than restricted to `Firestore\w+`-named classes) was
/// tried first and produces FALSE LIVE results for `completions` and
/// `stage_definitions` — both `lib/features/learning/data/repositories/
/// completion_repository_impl.dart` and `lib/features/tracks/stages/data/
/// repositories/stage_definition_repository_impl.dart` declare an
/// unrelated Drift-backed `*RepositoryImpl` class (`CompletionRepositoryImpl`,
/// `StageDefinitionRepositoryImpl`) IN THE SAME FILE as the Firestore
/// adapter, and that Drift class — nothing to do with Firestore — is
/// genuinely constructed from a presentation-layer provider. A fully-generic
/// HOP 2 conflates that coincidence with the Firestore adapter's own
/// reachability. Restricting HOP-2 extraction to `Firestore\w+`-prefixed
/// classes (the same naming convention step 1 already relies on for F's own
/// primary class) removes the false positive and reproduces the
/// independently-verified ground truth: `bookmarks` LIVE, `learning_order`
/// LIVE, `completions` DEAD, `stage_definitions` DEAD.
///
/// ## Known blind spots (deliberately undetected — read before trusting a
/// ## silent/DEAD/DORMANT verdict)
///
/// This is a regex-based text scanner, not a compiler or a points-to
/// analysis. It will NEVER see:
///   - **Indirect construction.** HOP 1B only matches the literal token
///     `<PrimaryClass>(`. A class reached through an intermediate factory
///     function, a DI/service-locator lookup (`GetIt.I<FirestoreFoo>()`), a
///     torn-off constructor reference (`FirestoreFoo.new` passed as a
///     value), reflection, or any indirection where that literal token
///     never appears in the referencing file's source text stays invisible
///     — reported DEAD/DORMANT even if it is genuinely wired in production.
///     (F2 closed the SPECIFIC reproduced gap — a bare, no-provider direct
///     construction — not every conceivable indirection; a fully general
///     points-to analysis is out of reach for a tool like this.)
///   - **Non-`Firestore*`-named classes.** A collection touched only from a
///     class that isn't literally named `Firestore...` (any casing/prefix
///     variant) is invisible to primary-class detection and to HOP 2's
///     adapter-class extraction.
///   - **String construction.** `'${prefix}collection_name'`, a name built
///     from a constant map, or any non-literal string never matches the
///     quoted-literal touch scanner.
///   - **Multi-line/triple-quoted string literals, for the F5 reachability
///     stripper only.** [_stripCodeLine] scans each line independently for
///     balanced single/double quotes; a Dart triple-quoted string
///     (`'''...'''`/`"""..."""`) spanning multiple lines is not tracked as
///     one unit the way a `/* */` block comment is, so a later line of such
///     a string could still be matched as if it were code. This is not
///     hypothetical — `lib/core/database/daos/completion_dao.dart` and
///     `lib/features/sacred_time/data/services/cities_repository.dart` both
///     contain genuine multi-line triple-quoted strings today — but
///     verified neither contains any Firestore-provider-identifier or
///     `Firestore*(`-construction text inside the affected span, so this
///     gap changes no verdict on the current tree. A raw string (`r'...'`)
///     is also still treated as backslash-escaping internally (real Dart
///     raw strings do not escape) — this can only ever UNDER-strip (leave a
///     little more raw-string content visible than it should), never
///     OVER-strip into real code, so it cannot manufacture a false LIVE
///     verdict — at worst it reproduces the pre-F5 behavior for that one
///     narrow construct.
///   - **Non-Dart-3-modifier class syntax this file doesn't enumerate.**
///     [_classFirestoreRe] accepts a FIXED keyword set (`abstract`, `base`,
///     `interface`, `final`, `sealed`, `mixin`); a future Dart class-
///     declaration form outside that set would again go undetected — the
///     same class of gap F3 just closed, left open by construction rather
///     than by oversight this time, because the keyword set is documented
///     here instead of silently assumed complete.
/// None of this makes the checker useless — every WATCHLIST line names
/// exactly which of these gaps applies to a given DORMANT file (see that
/// line's own text), so the blind spot is visible even when the underlying
/// code isn't.
///
/// ## Torn-read hardening (F4)
///
/// One run of this checker (pre-fix) reported `completions` as a brand-new
/// live split; 40+ subsequent runs on an unchanged tree were clean, and a
/// full read of this file found no randomness, unordered-iteration-
/// affecting-a-decision, or threading — the leading hypothesis is a torn
/// read against a file another process was mid-write on. Every file read in
/// this script goes through [_readLinesVerified], which throws
/// [_SuspectRead] (never silently substituting empty/partial content) when
/// a file's on-disk length changes mid-read, or a nonzero-length file
/// decodes to zero lines. `main` aborts the ENTIRE run — regardless of
/// `--report`/`--update-baseline` — the moment this is thrown, printing
/// "PROFILE-KEY-SPLIT ABORTED (not a real violation)" so it can never be
/// mistaken for a genuine keying-split finding.
///
/// ## Mandatory WATCHLIST (informational, every run, never affects exit code)
///
/// For every collection with a live INT writer (bucket: sync-engine or
/// cloud-functions) opposite a raw-but-DEAD ULID-C touch, this checker
/// prints a WATCHLIST line naming the dormant file/class and BOTH ways it
/// could flip live (provider wiring, or direct construction per HOP 1B) —
/// see the "Known blind spots" section above for what neither of those
/// covers. Never a silent blind spot, but also never inflated into the
/// pass/fail baseline as theatre.
///
/// Usage:
///   dart run tool/check_profile_path_keying.dart                  # ratchet check
///   dart run tool/check_profile_path_keying.dart --report          # full dump, always exits 0
///   dart run tool/check_profile_path_keying.dart --update-baseline # widen baseline to currentSplits
///   dart run tool/check_profile_path_keying.dart --root <path> --baseline <path> --collections <path>
///     # test-only: point at a fixture root/baseline, and/or override the
///     # collection registry (skips the firestore.rules step-0 cross-check
///     # entirely — see `--collections`'s own note below)
///
/// Exit codes:
///   0 — step 0 passed AND currentSplits ⊆ baseline (or `--collections` test
///       mode, which skips step 0 by design)
///   1 — step 0 registry self-check mismatch, OR newViolations nonempty, OR
///       a torn read was detected mid-scan (F4 — printed as "ABORTED", to
///       stay visibly distinct from a real "FAILED" violation even though
///       both currently exit 1)
///   `--report` always exits 0 UNLESS a torn read aborts the run (still
///   exit 1 — a diagnostic dump built on corrupted content is not safe to
///   print as if it were real) — otherwise it is a pure dump, never a gate.
library;

import 'dart:io';

/// The 18 profile-scoped Firestore collections nested directly under
/// `users/{uid}/learner_profiles/{profileId}/` in `firestore.rules` today.
/// Verified by direct reading of `firestore.rules:211-584` (the
/// `match /learner_profiles/{profileId} { ... }` block), NOT inherited from
/// any prior handoff — step 0 below re-verifies this list against the rules
/// file on every single invocation so this hardcoded set can never silently
/// drift from the ground truth again.
const _kCollections = <String>{
  'completions',
  'streak_events',
  'learning_ledger',
  'points_ledger',
  'reward_redemptions',
  'settings',
  'stage_definitions',
  'point_configs',
  'curriculum_tracks',
  'bookmarks',
  'learning_order',
  'track_learning_order',
  'preferences',
  'goals',
  'import_metadata',
  'profile_programs',
  'curriculum_scopes',
  'study_day_configs',
};

/// Baseline of already-known live production keying splits.
const _baselinePath = 'tool/profile_path_keying_baseline.txt';

/// Mirrors the constant of the same name in `tool/check_dependency_direction.
/// dart` — the repository-implementation layer path segment. Dart cannot
/// import a private top-level const across two standalone `tool/` scripts,
/// so this is a deliberate, identically-named/valued re-declaration, not an
/// independent invention.
const _repositoryDirSegment = '/data/repositories/';

const _learnerProfilesAnchor = 'match /learner_profiles/{profileId} {';

final _matchCollectionRe = RegExp(r'match\s+/(\w+)/\{');

/// Matches a `Firestore*`-named class declaration, INCLUDING every Dart 3
/// class-modifier prefix (`abstract`, `base`, `interface`, `final`,
/// `sealed`, `mixin`, and their valid combinations, e.g. `abstract final
/// class`) — not just a bare `class`. F3: the original `^class\s+
/// (Firestore\w+)` missed all of these; 70 files in this repo already use
/// modifier styling, including `lib/core/sync/firestore_gateway.dart:27`
/// (`abstract class FirestoreGateway`). A modifier this regex doesn't list
/// would still be missed — accepting zero-or-more of a fixed keyword set is
/// a deliberate, bounded widening, not a fully generic `^\S*\s*class\s+
/// (Firestore\w+)` match, so a non-class-modifier token placed before
/// `class` (which would be invalid Dart anyway) still fails closed rather
/// than matching something unintended.
final _classFirestoreRe = RegExp(
  r'^(?:(?:abstract|base|interface|final|sealed|mixin)\s+)*'
  r'class\s+(Firestore\w+)',
);
final _providerDeclRe = RegExp(r'^final\s+(\w+RepositoryProvider)\s*=');

/// Normalizes a path to forward slashes and strips a leading `./` so
/// `--root .` (the default) produces the same `lib/foo.dart`-style output
/// as every other `tool/check_*.dart` script, not `./lib/foo.dart`.
String _cleanPath(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.startsWith('./') ? normalized.substring(2) : normalized;
}

class _Touch {
  _Touch(this.path, this.line, this.snippet);
  final String path;
  final int line;
  final String snippet;

  @override
  String toString() => '$path:$line: $snippet';
}

class _RegistryResult {
  _RegistryResult({
    required this.matches,
    required this.rulesCollections,
    required this.missingFromRegistry,
    required this.extraInRegistry,
  });
  final bool matches;
  final Set<String> rulesCollections;
  final Set<String> missingFromRegistry; // in rules, not in _kCollections
  final Set<String> extraInRegistry; // in _kCollections, not in rules
}

class _ReachInfo {
  _ReachInfo({
    required this.primaryClass,
    required this.providerId,
    required this.live,
    required this.hop1Trace,
    required this.hop2Trace,
  });
  final String primaryClass;
  final String? providerId;
  final bool live;
  final String hop1Trace;
  final String hop2Trace;
}

/// F4 hardening: thrown by [_readLinesVerified] when a file read looks
/// TORN rather than genuinely absent/deleted (see that function's doc
/// comment). Deliberately never caught inside any scanning helper — it
/// propagates all the way to `main`'s top-level handler, which aborts the
/// entire run loudly instead of letting a corrupted read silently produce
/// a wrong classification (a phantom violation, or a phantom clean pass).
class _SuspectRead implements Exception {
  _SuspectRead(this.path, this.reason);
  final String path;
  final String reason;

  @override
  String toString() => 'SUSPECT READ: $path — $reason';
}

/// F4: one run of this checker (pre-fix) reported `completions` as a
/// brand-new live split; 40+ subsequent runs on an unchanged tree were
/// clean. A full read of this file found no randomness, no
/// unordered-iteration-affecting-a-decision, and no threading — the
/// leading hypothesis is a torn read against a file another process was
/// mid-write on (the checkout was shared at the time). This checker cannot
/// make concurrent writes impossible, so instead it makes a torn read
/// LOUD instead of silent: every line-read in this file goes through this
/// function rather than a bare `file.readAsLinesSync()`, and two cheap,
/// no-false-positive-on-a-quiescent-tree signals are checked:
///   1. The file's on-disk length differs between immediately before and
///      immediately after the read — another process wrote to it inside
///      our own read window.
///   2. The file is non-empty on disk but decoded to ZERO lines — no
///      genuinely non-empty `.dart`/`.rules`/`.txt` file in this repo
///      should ever decode to nothing; that combination is truncation, not
///      content.
/// Either signal throws [_SuspectRead], which aborts the whole run (see
/// that class's doc comment) rather than silently treating truncated
/// content as "this file has no touches" (which could just as easily HIDE
/// a real violation as fabricate one, if the truncation happens to land
/// mid-token).
///
/// ## Comment and string-literal stripping for reachability matching (F5)
///
/// Every reachability matcher below — HOP 1's provider-identifier search,
/// HOP 1B's direct-construction search, HOP 2's adapter-class-construction
/// search, and the provider `return $primaryClass(...)` search that HOP 1
/// starts from — now runs against a STRIPPED copy of each file
/// ([_stripCodeLine] / [_stripFileForReachability]: `//`/`///` comments,
/// `/* ... */` block comments including ones spanning multiple lines, and
/// single-line quoted string literal CONTENT are all blanked to a single
/// space first) instead of the raw source text. Before this, a mention
/// inside a doc comment or a string literal counted as a live reference
/// exactly like real code.
///
/// Reproduced without this fix: of the 10 occurrences of
/// `firestoreBookmarkRepositoryProvider` in `lib/**` outside its own
/// declaration site in `repository_providers.dart`, 8 are `///` doc-comment
/// prose (`bookmark_repository_impl.dart:384,428,478,528`,
/// `bookmark_providers.dart:15`, `firestore_learning_order_repository.
/// dart:85`, `completion_repository_impl.dart:421`,
/// `learning_order_repository_impl.dart:293`) and 1 is a string literal
/// inside `BookmarkRepositoryNotReadyException.toString()`
/// (`bookmark_repository_impl.dart:408`) — only `bookmark_repository_impl.
/// dart:536` (`_ref.read(firestoreBookmarkRepositoryProvider((...` inside
/// `_resolveOrNull()`) is a genuine reference. `bookmarks` is correctly
/// LIVE today regardless — that one real reference already carries it —
/// but a DORMANT collection mentioned only in a doc comment (the same
/// shape as 8 of these 10) was misclassified LIVE before this fix; see the
/// fixture-proven "F5" test group in
/// `test/tool/check_profile_path_keying_test.dart`.
///
/// [_hasCodeTouch] above (the INT-A/INT-B/ULID-C-raw touch scanner) is
/// deliberately NOT changed by this: it searches FOR a quoted
/// collection-name literal, so it must keep string CONTENT intact. Only
/// the reachability layer — which searches for a bare identifier or a
/// `ClassName(` construction that should never legitimately appear inside
/// a string or comment — benefits from blanking both out. This is one
/// stripping implementation reused across every reachability match site
/// below, not a second one that could quietly diverge from
/// [_hasCodeTouch]'s.
///
/// Not fully solved — a regex/char-scanner, not a lexer. See "Known blind
/// spots" below for the residual string-literal gaps this leaves open.
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
// Step 0 — collection-registry self-check.
// ---------------------------------------------------------------------------

/// Walks `$root/firestore.rules` from the `match /learner_profiles/{profileId}
/// {` anchor line, tracking brace depth (not a full parser — a simple
/// per-character `{`/`}` counter, mirroring the approach verified by direct
/// reproduction against the real rules file: 17 direct-child `match
/// /(\w+)/{` blocks, closing brace at the line where depth returns to 0).
/// Collects every child collection name at depth 1 or 2 (immediate children,
/// plus one further level of nesting in case a future collection is
/// declared inside a helper `match` block).
///
/// Returns `null` if the rules file is missing or the anchor line can't be
/// found — callers treat that as a hard step-0 failure.
_RegistryResult? _selfCheckRegistry(String root, Set<String> collections) {
  final rulesFile = File('$root/firestore.rules');
  if (!rulesFile.existsSync()) return null;
  List<String> lines;
  try {
    lines = _readLinesVerified(rulesFile);
  } on FileSystemException {
    return null;
  }

  final openIdx = lines.indexWhere((l) => l.contains(_learnerProfilesAnchor));
  if (openIdx == -1) return null;

  var relDepth = 0;
  for (final ch in lines[openIdx].split('')) {
    if (ch == '{') relDepth++;
    if (ch == '}') relDepth--;
  }

  final found = <String>{};
  for (var i = openIdx + 1; i < lines.length; i++) {
    final line = lines[i];
    if (relDepth == 1 || relDepth == 2) {
      final m = _matchCollectionRe.firstMatch(line);
      if (m != null) found.add(m.group(1)!);
    }
    for (final ch in line.split('')) {
      if (ch == '{') relDepth++;
      if (ch == '}') relDepth--;
    }
    if (relDepth <= 0) break;
  }

  final missing = found.difference(collections);
  final extra = collections.difference(found);
  return _RegistryResult(
    matches: missing.isEmpty && extra.isEmpty,
    rulesCollections: found,
    missingFromRegistry: missing,
    extraInRegistry: extra,
  );
}

// ---------------------------------------------------------------------------
// File discovery.
// ---------------------------------------------------------------------------

List<File> _dartFilesUnder(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const [];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.replaceAll(r'\', '/').endsWith('.dart'))
      .where((f) {
        final p = f.path.replaceAll(r'\', '/');
        if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) {
          return false;
        }
        if (p.contains('/test/')) return false;
        return true;
      })
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// F1: recursively finds every directory ending in `/data/repositories`
/// under `$root/lib/features/**` (arbitrary nesting depth — `lib/features/
/// gamification/data/repositories`, `lib/features/tracks/stages/data/
/// repositories`, etc. all match) and returns the `.dart` files directly
/// inside each one via [_dartFilesUnder] (so `.g.dart`/`.freezed.dart`/
/// `test/` stay excluded exactly like every other bucket).
///
/// This is the sanctioned seam for the Firestore-rewrite migration — audit
/// check 102 specifically permits `lib/features/**/data/repositories/` to
/// import the data ring — yet the original ULID-C bucket only ever scanned
/// `lib/data/repositories/`. Reproduction: `FirestoreBookmarkRepository
/// Adapter` (`lib/features/learning/data/repositories/
/// bookmark_repository_impl.dart:515`) has its OWN direct `'bookmarks'`
/// touch at line 222 that the un-widened scan never saw at all (bookmarks
/// only entered `currentSplits` via the separate raw `lib/data/
/// repositories/firestore_bookmark_repository.dart` file).
List<File> _featureRepositoryFiles(String root) {
  final featuresDir = Directory('$root/lib/features');
  if (!featuresDir.existsSync()) return const [];
  final repoDirs = featuresDir
      .listSync(recursive: true)
      .whereType<Directory>()
      .where((d) => d.path.replaceAll(r'\', '/').endsWith('/data/repositories'))
      .toList();
  final files = <File>[];
  for (final dir in repoDirs) {
    files.addAll(_dartFilesUnder(dir.path));
  }
  return files;
}

List<File> _tsFilesUnder(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const [];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.replaceAll(r'\', '/').endsWith('.ts'))
      .where((f) {
        final p = f.path.replaceAll(r'\', '/');
        if (p.endsWith('.test.ts')) return false;
        if (p.contains('/functions/test/')) return false;
        return true;
      })
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

// ---------------------------------------------------------------------------
// Literal-token touch scanning (buckets INT-A, INT-B, and raw ULID-C).
// ---------------------------------------------------------------------------

/// A "touch" = `name` appears as a whole quoted token (`'name'`/`"name"`,
/// inherently word-bounded — `'bookmarks2'` cannot match a `'bookmarks'`
/// pattern) on a line that, after stripping any `//...` trailing comment,
/// still contains the match. Does not parse `/* */` block comments — none
/// exist in the scanned trees today (verified: zero `/*` in lib/core/sync/,
/// functions/src/, lib/data/repositories/).
final _tokenReCache = <String, RegExp>{};
RegExp _tokenRegexFor(String name) =>
    _tokenReCache[name] ??= RegExp("['\"]${RegExp.escape(name)}['\"]");

bool _hasCodeTouch(String line, String collectionName) {
  final commentIdx = line.indexOf('//');
  final codePart = commentIdx == -1 ? line : line.substring(0, commentIdx);
  return _tokenRegexFor(collectionName).hasMatch(codePart);
}

/// Scans [files] for literal touches of every name in [collections],
/// grouped by file then by collection name — TOCTOU-safe (a file deleted
/// between listing and read is skipped, not a crash). Every read goes
/// through [_readLinesVerified] (F4): a torn/truncated read throws
/// [_SuspectRead], which is deliberately NOT caught here — it propagates to
/// `main`'s top-level handler and aborts the whole run rather than silently
/// scanning corrupted content.
Map<String, Map<String, List<_Touch>>> _scanTouchesByFile(
  List<File> files,
  Set<String> collections,
) {
  final result = <String, Map<String, List<_Touch>>>{};
  for (final file in files) {
    List<String> lines;
    try {
      lines = _readLinesVerified(file);
    } on FileSystemException {
      continue;
    }
    final path = _cleanPath(file.path);
    final perCollection = <String, List<_Touch>>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final c in collections) {
        if (_hasCodeTouch(line, c)) {
          (perCollection[c] ??= []).add(_Touch(path, i + 1, line.trim()));
        }
      }
    }
    if (perCollection.isNotEmpty) result[path] = perCollection;
  }
  return result;
}

Map<String, List<_Touch>> _flattenByCollection(
  Map<String, Map<String, List<_Touch>>> byFile,
  Set<String> collections,
) {
  final out = <String, List<_Touch>>{for (final c in collections) c: []};
  for (final perCollection in byFile.values) {
    for (final entry in perCollection.entries) {
      out[entry.key]!.addAll(entry.value);
    }
  }
  for (final list in out.values) {
    list.sort((a, b) => a.toString().compareTo(b.toString()));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Comment/string-literal stripping for reachability matching (F5 — see the
// library doc comment's "Comment and string-literal stripping for
// reachability matching (F5)" section for why this exists and what it does
// and does not cover).
// ---------------------------------------------------------------------------

/// Strips `//`/`///` comments (a `///` doc comment begins with `//`, so one
/// pass covers both), `/* ... */` block comments (including ones that carry
/// an open `/*` across a line boundary — [blockCommentOpen] in, the second
/// tuple element out, thread that state across a whole file via
/// [_stripFileForReachability]), and single-line quoted string literal
/// CONTENT (both `'...'`/`"..."`, backslash-escape aware) out of one line of
/// Dart source. Every stripped span is replaced by a single space — never
/// removed outright, which could otherwise fuse the token before a stripped
/// span to the token after it into a new, fabricated match.
///
/// See the library doc comment's F5 section for why this is a SEPARATE
/// implementation from [_hasCodeTouch] above (that one must keep quoted
/// string CONTENT intact — it searches FOR a collection-name literal, not
/// past one) and for the residual gaps ("Known blind spots") this one still
/// leaves open.
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
      if (end == -1) {
        return (buffer.toString(), true);
      }
      buffer.write(' ');
      i = end + 2;
      inBlock = false;
      continue;
    }
    final ch = line[i];
    if (ch == '/' && i + 1 < len && line[i + 1] == '/') {
      break; // Rest of the line is a `//`/`///` comment — not code.
    }
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

/// Runs [_stripCodeLine] over every line of one file IN ORDER, threading the
/// block-comment-open state from each line to the next so a `/* ... */`
/// spanning multiple lines strips correctly across the whole file. Returns
/// a list the SAME LENGTH as [lines], index-aligned, so callers keep using
/// `i + 1` as a 1-based line number exactly like they already do against
/// the raw [libFilesCache]-style cache this mirrors.
List<String> _stripFileForReachability(List<String> lines) {
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
// 2-hop reachability for a single ULID-C repository file.
// ---------------------------------------------------------------------------

_ReachInfo _computeReachability({
  required String filePath,
  required Map<String, List<String>> libFilesCache,
  required Map<String, List<String>> strippedLibFilesCache,
  required String providerFilePath,
}) {
  final fLines = libFilesCache[filePath] ?? const <String>[];
  String? primaryClass;
  for (final line in fLines) {
    final m = _classFirestoreRe.firstMatch(line);
    if (m != null) {
      primaryClass = m.group(1);
      break;
    }
  }
  if (primaryClass == null) {
    return _ReachInfo(
      primaryClass: '(unknown)',
      providerId: null,
      live: false,
      hop1Trace: 'no `class Firestore...` declaration found in $filePath',
      hop2Trace: '',
    );
  }

  // HOP 1B (F2) — direct construction, independent of the provider layer
  // entirely. HOP 1 below only ever greps for the `$xRepositoryProvider`
  // identifier; a `Firestore*` class built directly (`FirestoreFooRepo(...)`
  // with no provider indirection at all — e.g. straight inside a
  // presentation widget's build method) was invisible to it and reported
  // DEAD/dormant forever, no matter how it was actually wired in. This
  // closes that: grep all of lib/** (excluding F itself and the provider
  // registry file — the registry's own `return $primaryClass(` line is F's
  // definition site, not a reachability signal) for `$primaryClass(`; any
  // hit outside $_repositoryDirSegment is LIVE, with or without a provider.
  //
  // Known residual (still undetectable after this — see the class doc
  // comment's "Known blind spots" section): construction via an
  // intermediate factory function, a DI/service-locator lookup
  // (`GetIt.I<FirestoreFooRepo>()`), a torn-off constructor reference
  // (`FirestoreFooRepo.new`), or any other indirection where the literal
  // token `$primaryClass(` never appears in the referencing file's source
  // text. A fully general points-to analysis is out of reach for a regex-
  // based checker; this closes the specific reproduced gap (direct
  // construction), not every conceivable one.
  final directCtorRe = RegExp('${RegExp.escape(primaryClass)}\\(');
  final excludedForHop1b = {filePath, providerFilePath};
  for (final entry in strippedLibFilesCache.entries) {
    if (excludedForHop1b.contains(entry.key)) continue;
    for (var i = 0; i < entry.value.length; i++) {
      if (directCtorRe.hasMatch(entry.value[i]) &&
          !entry.key.contains(_repositoryDirSegment)) {
        return _ReachInfo(
          primaryClass: primaryClass,
          providerId: null,
          live: true,
          hop1Trace:
              'HOP1B LIVE: $primaryClass constructed directly at '
              '${entry.key}:${i + 1} (outside $_repositoryDirSegment) — no '
              'provider indirection needed',
          hop2Trace: '',
        );
      }
    }
  }

  // Stripped (F5): both the `return $primaryClass(` search and the
  // `^final ... RepositoryProvider =` search below only need to see code,
  // never a doc comment or a string literal that happens to mention either
  // shape.
  final providerLines =
      strippedLibFilesCache[providerFilePath] ?? const <String>[];
  final returnRe = RegExp('return\\s+${RegExp.escape(primaryClass)}\\(');
  int? returnLineIdx;
  for (var i = 0; i < providerLines.length; i++) {
    if (returnRe.hasMatch(providerLines[i])) {
      returnLineIdx = i;
      break;
    }
  }
  String? providerId;
  if (returnLineIdx != null) {
    for (var i = returnLineIdx; i >= 0; i--) {
      final m = _providerDeclRe.firstMatch(providerLines[i]);
      if (m != null) {
        providerId = m.group(1);
        break;
      }
    }
  }
  if (providerId == null) {
    return _ReachInfo(
      primaryClass: primaryClass,
      providerId: null,
      live: false,
      hop1Trace:
          'HOP1B found no direct construction of $primaryClass outside '
          '$_repositoryDirSegment, AND no `final <id>RepositoryProvider = '
          '...return $primaryClass(...)` wiring found in $providerFilePath',
      hop2Trace: '',
    );
  }

  // HOP 1 — stripped (F5): a doc-comment or string-literal mention of
  // $providerId must not count as a reference, only real code.
  final excludedForHop1 = {filePath, providerFilePath};
  final r1Files = <String>{};
  for (final entry in strippedLibFilesCache.entries) {
    if (excludedForHop1.contains(entry.key)) continue;
    for (var i = 0; i < entry.value.length; i++) {
      if (entry.value[i].contains(providerId)) {
        r1Files.add(entry.key);
        break;
      }
    }
  }
  final r1Sorted = r1Files.toList()..sort();
  for (final f in r1Sorted) {
    if (!f.contains(_repositoryDirSegment)) {
      return _ReachInfo(
        primaryClass: primaryClass,
        providerId: providerId,
        live: true,
        hop1Trace:
            'HOP1 LIVE: $providerId referenced in $f (outside '
            '$_repositoryDirSegment)',
        hop2Trace: '',
      );
    }
  }
  final hop1TraceStr = r1Sorted.isEmpty
      ? 'HOP1: $providerId not referenced anywhere outside '
            '$providerFilePath'
      : 'HOP1: $providerId referenced only inside '
            '$_repositoryDirSegment-scoped file(s): ${r1Sorted.join(', ')}';

  // HOP 2 — restricted to Firestore\w+-named classes; see the doc comment
  // "Deviation from a fully-generic HOP-2 class extraction" above for why.
  final hop2TraceParts = <String>[];
  for (final r1File in r1Sorted) {
    final r1Lines = libFilesCache[r1File] ?? const <String>[];
    final classNames = <String>{};
    for (final line in r1Lines) {
      final m = _classFirestoreRe.firstMatch(line);
      if (m != null) classNames.add(m.group(1)!);
    }
    for (final cls in classNames) {
      final ctorRe = RegExp('${RegExp.escape(cls)}\\(');
      // Stripped (F5): a doc-comment or string-literal mention of
      // `$cls(` must not count as a construction, only real code.
      for (final entry in strippedLibFilesCache.entries) {
        if (entry.key == r1File) continue;
        for (var i = 0; i < entry.value.length; i++) {
          if (ctorRe.hasMatch(entry.value[i])) {
            if (!entry.key.contains(_repositoryDirSegment)) {
              return _ReachInfo(
                primaryClass: primaryClass,
                providerId: providerId,
                live: true,
                hop1Trace: hop1TraceStr,
                hop2Trace:
                    'HOP2 LIVE: $cls (declared in $r1File) constructed at '
                    '${entry.key}:${i + 1} (outside $_repositoryDirSegment)',
              );
            }
            hop2TraceParts.add(
              '$cls( found at ${entry.key}:${i + 1} (still inside '
              '$_repositoryDirSegment)',
            );
          }
        }
      }
    }
  }

  return _ReachInfo(
    primaryClass: primaryClass,
    providerId: providerId,
    live: false,
    hop1Trace: hop1TraceStr,
    hop2Trace: hop2TraceParts.isEmpty
        ? 'HOP2: no external construction of any Firestore*-class declared '
              'in ${r1Sorted.join(', ')}'
        : 'HOP2 DEAD (every construction found is still inside '
              '$_repositoryDirSegment): ${hop2TraceParts.join('; ')}',
  );
}

// ---------------------------------------------------------------------------
// Baseline / collections-override I/O.
// ---------------------------------------------------------------------------

Set<String> _readNameListFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>{};
  return _readLinesVerified(file)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}

void _writeBaseline(String path, List<String> entries) {
  final buffer = StringBuffer()
    ..writeln('# PROFILE-KEY-SPLIT baseline — generated by')
    ..writeln('# tool/check_profile_path_keying.dart --update-baseline.')
    ..writeln(
      '# Every profile-scoped Firestore collection listed here has a '
      'VERIFIED,',
    )
    ..writeln(
      '# already-reviewed live production keying-scheme split (Drift int '
      'path',
    )
    ..writeln(
      '# vs Firestore ULID path) — docs/firestore-rewrite-map.md item 10.',
    )
    ..writeln(
      '# A new collection NOT listed here fails `make audit`/`make ci`.',
    )
    ..writeln(
      '# Widening this file requires the same team sign-off any other '
      'ratchet',
    )
    ..writeln(
      '# widening requires — a new entry here means a NEW collection '
      'became',
    )
    ..writeln(
      '# genuinely production-split, not that this checker got noisier.',
    );
  for (final entry in entries) {
    buffer.writeln(entry);
  }
  File(path).writeAsStringSync(buffer.toString());
}

String _flagValue(List<String> args, String flag, String fallback) {
  final i = args.indexOf(flag);
  return (i != -1 && i + 1 < args.length) ? args[i + 1] : fallback;
}

String? _flagValueOrNull(List<String> args, String flag) {
  final i = args.indexOf(flag);
  return (i != -1 && i + 1 < args.length) ? args[i + 1] : null;
}

// ---------------------------------------------------------------------------
// main.
// ---------------------------------------------------------------------------

/// F4: the ENTIRE run — step 0 plus every bucket scan — is wrapped here so
/// a [_SuspectRead] thrown anywhere (registry file, sync/functions/
/// repository sources, the whole-of-lib cache, baseline/collections files)
/// aborts loudly instead of letting [_run] finish on corrupted content.
/// This is deliberately NOT "exit code 1 == a real violation": the message
/// says ABORTED, not FAILED, so a human or CI log reader re-runs rather
/// than treating it as a fabricated production regression.
void main(List<String> args) {
  try {
    _run(args);
  } on _SuspectRead catch (e) {
    stderr.writeln('PROFILE-KEY-SPLIT ABORTED (not a real violation): $e');
    stderr.writeln(
      'This is F4 hardening: a torn/truncated read was detected mid-scan '
      '(almost certainly a concurrent writer to the checkout this checker '
      'is scanning, not a real production keying split). Re-run once the '
      'tree is quiescent — do NOT interpret this as a PROFILE-KEY-SPLIT '
      'violation.',
    );
    exit(1);
  }
}

void _run(List<String> args) {
  final root = _flagValue(args, '--root', '.');
  final baselinePath = _flagValue(args, '--baseline', _baselinePath);
  final collectionsOverridePath = _flagValueOrNull(args, '--collections');
  final report = args.contains('--report');
  final updateBaseline = args.contains('--update-baseline');

  final testMode = collectionsOverridePath != null;
  final Set<String> collections;
  _RegistryResult? registryResult;

  if (testMode) {
    collections = _readNameListFile(collectionsOverridePath);
  } else {
    collections = Set<String>.of(_kCollections);
    registryResult = _selfCheckRegistry(root, collections);
    if (registryResult == null) {
      stderr.writeln(
        'PROFILE-KEY-SPLIT step 0 FAILED: could not read/parse '
        '$root/firestore.rules (file missing, or the anchor line '
        '`$_learnerProfilesAnchor` was not found). This checker cannot '
        'safely run without validating its collection registry first.',
      );
      exit(1);
    }
    if (!registryResult.matches && !report) {
      stderr.writeln(
        'PROFILE-KEY-SPLIT step 0 (collection-registry self-check) FAILED: '
        'firestore.rules and the hardcoded _kCollections list in '
        'tool/check_profile_path_keying.dart have DRIFTED APART.',
      );
      if (registryResult.missingFromRegistry.isNotEmpty) {
        final list = registryResult.missingFromRegistry.toList()..sort();
        stderr.writeln(
          '  In firestore.rules but NOT in _kCollections (ADD these): '
          '${list.join(', ')}',
        );
      }
      if (registryResult.extraInRegistry.isNotEmpty) {
        final list = registryResult.extraInRegistry.toList()..sort();
        stderr.writeln(
          '  In _kCollections but NOT in firestore.rules (REMOVE these): '
          '${list.join(', ')}',
        );
      }
      stderr.writeln(
        '  Update _kCollections in tool/check_profile_path_keying.dart to '
        'match firestore.rules exactly, then re-run — never silently scan '
        'a stale list.',
      );
      exit(1);
    }
  }

  // ---- Bucket scanning ----
  final intAByFile = _scanTouchesByFile(
    _dartFilesUnder('$root/lib/core/sync'),
    collections,
  );
  final intBByFile = _scanTouchesByFile(
    _tsFilesUnder('$root/functions/src'),
    collections,
  );
  final intA = _flattenByCollection(intAByFile, collections);
  final intB = _flattenByCollection(intBByFile, collections);

  // F1: scan BOTH lib/data/repositories/** AND lib/features/**/data/
  // repositories/** — the sanctioned migration seam (audit check 102). No
  // filename-prefix filter: `lib/data/repositories/` is 15/16
  // `firestore_`-prefixed (the one exception, `points_ledger_entry.dart`, is
  // a plain data-class with zero collection-name touches, so scanning it is
  // harmless), but the feature-level Adapter files are NOT prefix-
  // consistent at all (`bookmark_repository_impl.dart`,
  // `completion_repository_impl.dart`, ...) — a filename heuristic can't
  // work there. Any file with zero literal touches simply never appears in
  // `ulidRawByFile` below, so scanning non-repository files in these
  // directories (e.g. Drift-only impls) costs nothing.
  final ulidFiles = <File>[
    ..._dartFilesUnder('$root/lib/data/repositories'),
    ..._featureRepositoryFiles(root),
  ]..sort((a, b) => a.path.compareTo(b.path));
  final ulidRawByFile = _scanTouchesByFile(ulidFiles, collections);

  final libFilesCache = <String, List<String>>{};
  for (final file in _dartFilesUnder('$root/lib')) {
    final path = _cleanPath(file.path);
    try {
      libFilesCache[path] = _readLinesVerified(file);
    } on FileSystemException {
      continue;
    }
  }
  // F5: a comment/string-stripped mirror of libFilesCache, same keys, same
  // index-per-line alignment — see [_stripFileForReachability]'s doc
  // comment and the library doc comment's F5 section.
  final strippedLibFilesCache = <String, List<String>>{
    for (final entry in libFilesCache.entries)
      entry.key: _stripFileForReachability(entry.value),
  };
  final providerFilePath = _cleanPath(
    '$root/lib/data/firestore/repository_providers.dart',
  );

  final reachability = <String, _ReachInfo>{};
  for (final filePath in ulidRawByFile.keys) {
    reachability[filePath] = _computeReachability(
      filePath: filePath,
      libFilesCache: libFilesCache,
      strippedLibFilesCache: strippedLibFilesCache,
      providerFilePath: providerFilePath,
    );
  }

  final ulidRaw = _flattenByCollection(ulidRawByFile, collections);
  final ulidLive = <String, List<_Touch>>{for (final c in collections) c: []};
  for (final entry in ulidRawByFile.entries) {
    final info = reachability[entry.key]!;
    if (!info.live) continue;
    for (final ce in entry.value.entries) {
      ulidLive[ce.key]!.addAll(ce.value);
    }
  }
  for (final list in ulidLive.values) {
    list.sort((a, b) => a.toString().compareTo(b.toString()));
  }

  final currentSplits = <String>{};
  for (final c in collections) {
    final intTouch = intA[c]!.isNotEmpty || intB[c]!.isNotEmpty;
    final ulidTouch = ulidLive[c]!.isNotEmpty;
    if (intTouch && ulidTouch) currentSplits.add(c);
  }

  // ---- Mandatory watchlist ----
  final watchlist = <String>[];
  for (final c in collections) {
    final intTouch = intA[c]!.isNotEmpty || intB[c]!.isNotEmpty;
    if (!intTouch) continue;
    if (ulidLive[c]!.isNotEmpty) continue;
    if (ulidRaw[c]!.isEmpty) continue;
    final bucket = <String>[
      if (intA[c]!.isNotEmpty) 'sync-engine',
      if (intB[c]!.isNotEmpty) 'cloud-functions',
    ];
    final deadFiles =
        ulidRawByFile.entries
            .where((e) => e.value.containsKey(c) && !reachability[e.key]!.live)
            .map((e) => e.key)
            .toSet()
            .toList()
          ..sort();
    for (final f in deadFiles) {
      final info = reachability[f]!;
      watchlist.add(
        'WATCHLIST: $c — live INT writer (bucket: ${bucket.join(', ')}) '
        'opposite a DORMANT ULID repo at $f:${info.primaryClass} (not '
        'reachable from outside $_repositoryDirSegment today). This gate '
        'WILL start failing on it with zero code change required here the '
        'moment ${info.primaryClass} is EITHER wired through a '
        r'`$xRepositoryProvider` into a lib/features/**/presentation/** '
        'provider, OR constructed directly (`${info.primaryClass}(`) '
        'anywhere outside $_repositoryDirSegment (HOP 1B). It will NOT '
        'start failing if the wiring instead goes through an intermediate '
        'factory function, a DI/service-locator lookup, or a torn-off '
        'constructor reference (`${info.primaryClass}.new`) — those remain '
        'undetectable by this static checker; see the class doc comment\'s '
        '"Known blind spots" section.',
      );
    }
  }
  watchlist.sort();

  final baseline = _readNameListFile(baselinePath);
  final newViolations = currentSplits.difference(baseline).toList()..sort();
  final resolved = baseline.difference(currentSplits).toList()..sort();

  // ---- --report: full diagnostic dump, always exits 0 ----
  if (report) {
    if (testMode) {
      final list = collections.toList()..sort();
      stdout.writeln(
        'STEP 0 (collection-registry self-check): SKIPPED — --collections '
        'override active (test mode). Using ${collections.length} fixture '
        'collection name(s): ${list.join(', ')}. NOT cross-checked against '
        'firestore.rules.',
      );
    } else {
      final r = registryResult!;
      stdout.writeln(
        'STEP 0 (collection-registry self-check): '
        '${r.matches ? 'PASSED' : 'FAILED (drift detected — continuing in '
                  '--report mode with the hardcoded _kCollections list)'} — '
        'firestore.rules has ${r.rulesCollections.length} profile-scoped '
        'collection(s) under learner_profiles/{profileId}, _kCollections '
        'has ${_kCollections.length}.',
      );
      if (!r.matches) {
        if (r.missingFromRegistry.isNotEmpty) {
          final list = r.missingFromRegistry.toList()..sort();
          stdout.writeln(
            '  In firestore.rules but NOT in _kCollections: '
            '${list.join(', ')}',
          );
        }
        if (r.extraInRegistry.isNotEmpty) {
          final list = r.extraInRegistry.toList()..sort();
          stdout.writeln(
            '  In _kCollections but NOT in firestore.rules: '
            '${list.join(', ')}',
          );
        }
      }
    }
    stdout.writeln();

    final sortedCollections = collections.toList()..sort();
    for (final c in sortedCollections) {
      stdout.writeln('--- $c ---');
      stdout.writeln(
        '  INT-A (lib/core/sync/**): ${intA[c]!.length} touch(es)',
      );
      for (final t in intA[c]!) {
        stdout.writeln('    $t');
      }
      stdout.writeln(
        '  INT-B (functions/src/**): ${intB[c]!.length} touch(es)',
      );
      for (final t in intB[c]!) {
        stdout.writeln('    $t');
      }
      stdout.writeln(
        '  ULID-C raw (lib/data/repositories/firestore_*.dart, '
        'pre-liveness): ${ulidRaw[c]!.length} touch(es)',
      );
      for (final t in ulidRaw[c]!) {
        stdout.writeln('    $t');
      }
      stdout.writeln(
        '  ULID-C live (liveness-filtered): ${ulidLive[c]!.length} '
        'touch(es)',
      );
      for (final t in ulidLive[c]!) {
        stdout.writeln('    $t');
      }
      // Every LIVE file also gets its reachability trace printed — not
      // just DEAD candidates below. There are now three independent ways a
      // file can resolve LIVE (classic HOP 1's provider reference, HOP 1B's
      // direct construction, or HOP 2's adapter-class construction); a
      // report that only explains DEAD verdicts and stays silent on WHY a
      // LIVE one resolved live is itself an undocumented blind spot in the
      // diagnostic output, not just in detection.
      final liveFilesForC =
          ulidRawByFile.entries
              .where((e) => e.value.containsKey(c) && reachability[e.key]!.live)
              .map((e) => e.key)
              .toSet()
              .toList()
            ..sort();
      for (final f in liveFilesForC) {
        final info = reachability[f]!;
        stdout.writeln(
          '  LIVE ULID-C source: $f (class ${info.primaryClass}, provider '
          '${info.providerId})',
        );
        stdout.writeln('    ${info.hop1Trace}');
        if (info.hop2Trace.isNotEmpty) {
          stdout.writeln('    ${info.hop2Trace}');
        }
      }
      final deadFilesForC =
          ulidRawByFile.entries
              .where(
                (e) => e.value.containsKey(c) && !reachability[e.key]!.live,
              )
              .map((e) => e.key)
              .toSet()
              .toList()
            ..sort();
      for (final f in deadFilesForC) {
        final info = reachability[f]!;
        stdout.writeln(
          '  DEAD ULID-C candidate: $f (class ${info.primaryClass}, '
          'provider ${info.providerId})',
        );
        stdout.writeln('    ${info.hop1Trace}');
        if (info.hop2Trace.isNotEmpty) {
          stdout.writeln('    ${info.hop2Trace}');
        }
      }
    }

    stdout.writeln();
    stdout.writeln('--- WATCHLIST (${watchlist.length}) ---');
    for (final w in watchlist) {
      stdout.writeln(w);
    }

    stdout.writeln();
    stdout.writeln('--- currentSplits vs baseline ---');
    final sortedSplits = currentSplits.toList()..sort();
    final sortedBaseline = baseline.toList()..sort();
    stdout.writeln('currentSplits: ${sortedSplits.join(', ')}');
    stdout.writeln('baseline ($baselinePath): ${sortedBaseline.join(', ')}');
    stdout.writeln(
      'newViolations (currentSplits - baseline): '
      '${newViolations.join(', ')}',
    );
    stdout.writeln(
      'resolved (baseline - currentSplits): '
      '${resolved.join(', ')}',
    );
    return;
  }

  // ---- --update-baseline ----
  if (updateBaseline) {
    final sortedSplits = currentSplits.toList()..sort();
    _writeBaseline(baselinePath, sortedSplits);
    stdout.writeln(
      'Baseline updated: ${currentSplits.length} collection(s) recorded in '
      '$baselinePath (${sortedSplits.join(', ')})',
    );
    for (final w in watchlist) {
      stdout.writeln(w);
    }
    return;
  }

  // ---- Normal ratchet check ----
  for (final w in watchlist) {
    stdout.writeln(w);
  }

  if (resolved.isNotEmpty) {
    stdout.writeln(
      'INFO: the following tracked-baseline collection(s) show NO current '
      'writer/reader split — the backlog shrank. Consider running '
      '--update-baseline to keep the baseline honest: ${resolved.join(', ')}',
    );
  }

  if (newViolations.isNotEmpty) {
    stderr.writeln(
      'PROFILE-KEY-SPLIT check FAILED — NEW profile-scoped collection(s) '
      'now have a live production keying-scheme split (old sync-engine/'
      'Cloud-Functions Drift-int path vs new Firestore-repository ULID '
      'path) that were NOT already in the tracked baseline ($baselinePath):',
    );
    for (final c in newViolations) {
      stderr.writeln('  $c:');
      for (final t in intA[c]!) {
        stderr.writeln('    INT (sync-engine): $t');
      }
      for (final t in intB[c]!) {
        stderr.writeln('    INT (cloud-functions): $t');
      }
      for (final t in ulidLive[c]!) {
        stderr.writeln('    ULID (live repository): $t');
      }
    }
    stderr.writeln(
      '\nThis is docs/firestore-rewrite-map.md item 10\'s defect class: a '
      'writer and a reader silently disagree about which document tree '
      'they use — the test suite cannot catch it by construction. If this '
      'split is genuine and reviewed, widen the ratchet with `dart run '
      'tool/check_profile_path_keying.dart --update-baseline` (team '
      'sign-off required, same as any other ratchet widening) — never to '
      'make a real regression disappear.',
    );
    exit(1);
  }

  final sortedSplits = currentSplits.toList()..sort();
  stdout.writeln(
    'PROFILE-KEY-SPLIT check OK: ${currentSplits.length} collection(s) '
    'currently split (${sortedSplits.join(', ')}), all within the tracked '
    'baseline (0 new violations).',
  );
}
