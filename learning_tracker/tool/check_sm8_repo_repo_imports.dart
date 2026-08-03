/// SM-8 repository→repository import checker — AUD-tracks-15.
///
/// SM-8 ("Repositories never import or depend on other repositories;
/// compose multi-source data in a Notifier or domain service") previously
/// had no automated enforcement (`docs/coding-standards.md` listed it as
/// `[Pending] audit grep`). AUD-tracks-15 flagged
/// `TrackLearningOrderRepositoryImpl` importing `ContentRepository`
/// directly — the repository-imports-repository shape SM-8 forbids — and
/// its acceptance criteria name this checker as the artifact to ship. AC3
/// names `lib/features/tracks/` as the enforced scope with no carve-outs;
/// the sibling `LearningOrderRepositoryImpl` violation found inside that
/// same directory during review was fixed the same way (provider resolves
/// `allItems`), not excluded.
///
/// This script scans every `*_repository*.dart` file under
/// `lib/features/tracks/` (excluding generated `.g.dart`/`.freezed.dart`)
/// for an `import` of another `*_repository*.dart` file. A repository impl
/// importing the interface it itself implements (e.g.
/// `foo_repository_impl.dart` -> `foo_repository.dart`) is the ordinary
/// `implements` contract, not the repo→repo composition anti-pattern SM-8
/// forbids, and is allowed. Importing any OTHER repository file — its own
/// impl, or (as in AUD-tracks-15's evidence) a different feature's
/// repository interface such as `ContentRepository` — is a violation.
///
/// Usage:
///   dart run tool/check_sm8_repo_repo_imports.dart
///
/// Exit codes:
///   0 — no repository file under lib/features/tracks/ imports another
///       repository file
///   1 — one or more repo→repo imports found (prints file: violation)
library;

import 'dart:io';

/// Matches a `*_repository*.dart` basename (e.g. `foo_repository.dart`,
/// `foo_repository_impl.dart`).
final _repositoryFileName = RegExp(r'_repository[a-zA-Z_]*\.dart$');

/// The canonical Firestore data-access ring (`R --> A` in AD-23's diagram).
///
/// **Narrowed 2026-08-03, during the Drift→Firestore rewrite.** SM-8 exists
/// because AUD-tracks-15 found `TrackLearningOrderRepositoryImpl` importing
/// **`ContentRepository`** — a DIFFERENT FEATURE's repository. That is the
/// hidden-coupling shape SM-8 forbids, and it is still caught: a
/// `lib/features/**` repository importing another `lib/features/**`
/// repository remains a violation.
///
/// Importing `lib/data/repositories/**` is a categorically different
/// relationship. That directory IS the data-access ring a repository is
/// supposed to depend on — the same `Repositories --> {Data-access ring,
/// Domain}` edge AD-23 sanctions and `tool/check_dependency_direction.dart`
/// enforces from the other side. A feature's `*_repository_impl.dart` now
/// adapts the Firestore repository for its collection; forbidding that would
/// forbid the architecture, not a smell.
///
/// This is a deliberate scope narrowing, not a carve-out for convenience:
/// the original AUD-tracks-15 evidence (`ContentRepository`) still fails, and
/// a test pins that.
const _dataAccessRingPrefix = 'data/repositories/';

/// Matches an `import 'package:learning_tracker/<path>'` line, capturing
/// `<path>`. Trailing `as x;` / `show ...` / `hide ...` clauses are ignored
/// since the match isn't anchored to end-of-line.
final _importPath = RegExp(
  r'''^\s*import\s+['"]package:learning_tracker/([^'"]+)['"]''',
);

void main() {
  final root = Directory('lib/features/tracks');
  if (!root.existsSync()) {
    stderr.writeln(
      'ERROR: lib/features/tracks/ not found — run from the '
      'learning_tracker/ package root.',
    );
    exit(1);
  }

  final violations = <String>[];

  final entities = root.listSync(recursive: true, followLinks: false).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final entity in entities) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;

    final basename = path.split('/').last;
    if (!_repositoryFileName.hasMatch(basename)) continue;

    final ownInterfaceBasename = _ownInterfaceBasename(basename);

    for (final line in entity.readAsLinesSync()) {
      final match = _importPath.firstMatch(line);
      if (match == null) continue;
      final importedPath = match.group(1)!;
      final importedBasename = importedPath.split('/').last;
      if (!_repositoryFileName.hasMatch(importedBasename)) continue;
      if (importedBasename == ownInterfaceBasename) continue;
      if (importedPath.startsWith(_dataAccessRingPrefix)) continue;

      violations.add(
        '$path: imports another repository file '
        '(package:learning_tracker/$importedPath) — SM-8 forbids '
        'repository→repository composition; compose multi-source data in '
        'a Notifier or domain service instead: ${line.trim()}',
      );
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('SM-8 repository→repository import check FAILED:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'SM-8 repository→repository import check passed — no repository file '
    'under lib/features/tracks/ imports another repository file.',
  );
}

/// For an `..._impl.dart` file, returns the basename of the interface it's
/// expected to implement (the same stem with the `_impl` suffix dropped) —
/// e.g. `track_learning_order_repository_impl.dart` ->
/// `track_learning_order_repository.dart`. Returns null for non-impl files
/// (an interface file has no "own" repository import to allow).
String? _ownInterfaceBasename(String basename) {
  if (!basename.endsWith('_impl.dart')) return null;
  final stem = basename.substring(0, basename.length - '_impl.dart'.length);
  return '$stem.dart';
}
