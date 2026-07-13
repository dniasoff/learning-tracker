/// Sync-explainer merger-count checker — AUD-docs-18 (AG-8).
///
/// `docs/explainers/sync-subsystem.md` states the number of `EntityMerger`
/// implementations under `lib/core/sync/merge/` in prose (the "One
/// decomposed subsystem" section) and again in the "Where the code lives"
/// file tree. AUD-docs-18 found the doc still claiming "8" years after 10
/// more mergers were added, alongside a stale two-stack (`SyncEngine` /
/// `OfflineQueue`) narrative for a decomposition that had already finished —
/// nobody re-derives a hand-picked count when a merger is added, so it
/// silently drifts (AG-8: "a new invariant updates this file, with its
/// checker — Rule 0").
///
/// This is a cheap Rule-0 doc-lint that operationalizes AG-8 for this one
/// doc: it re-derives the true merger count from the filesystem and asserts
/// every "<N> EntityMerger(s)" claim in the doc matches it.
///
/// Usage (run from `learning_tracker/`):
///   dart run tool/check_sync_explainer_merger_count.dart
///
/// Exit codes:
///   0 — every count claim in the doc matches the actual merger file count
///   1 — a claim is stale (drifted from the actual count), or the doc no
///       longer states a checkable count claim at all (a rewrite that
///       silently drops the claim should fail loudly, not disappear)
///   2 — usage error (run from the wrong directory; doc or merge/ missing)
library;

import 'dart:io';

/// Matches doc prose like "18 EntityMergers", "18 EntityMerger
/// implementations", or the markdown-code-spanned "18 `EntityMerger`" —
/// captures the claimed count. The optional backtick tolerates the doc
/// wrapping the type name in an inline code span.
final _countClaimPattern = RegExp(r'(\d+)\s+`?EntityMerger');

/// Returns the true count of concrete `EntityMerger` implementations: every
/// `*_merger.dart` file under [mergeDir], excluding the abstract base class
/// `entity_merger.dart`.
int _actualMergerCount(Directory mergeDir) {
  return mergeDir.listSync().whereType<File>().where((f) {
    final basename = f.path.replaceAll(r'\', '/').split('/').last;
    return basename.endsWith('_merger.dart') &&
        basename != 'entity_merger.dart';
  }).length;
}

void main(List<String> args) {
  final docFile = File('../docs/explainers/sync-subsystem.md');
  final mergeDir = Directory('lib/core/sync/merge');

  if (!docFile.existsSync() || !mergeDir.existsSync()) {
    stderr.writeln(
      'ERROR: ../docs/explainers/sync-subsystem.md or lib/core/sync/merge '
      'not found — run from the learning_tracker/ directory',
    );
    exit(2);
  }

  final actualCount = _actualMergerCount(mergeDir);
  final content = docFile.readAsStringSync();
  final claims = _countClaimPattern
      .allMatches(content)
      .map((m) => int.parse(m.group(1)!))
      .toSet();

  if (claims.isEmpty) {
    stderr.writeln(
      'AUD-docs-18 merger-count check FAILED — '
      'docs/explainers/sync-subsystem.md no longer states an '
      '"<N> EntityMerger(s)" count anywhere. This checker exists to keep '
      'that count honest (AG-8) — if the doc genuinely no longer needs to '
      'state a count, update this checker deliberately instead of letting '
      'it silently pass.',
    );
    exit(1);
  }

  final stale = claims.where((c) => c != actualCount).toList()..sort();
  if (stale.isNotEmpty) {
    stderr.writeln(
      'AUD-docs-18 merger-count check FAILED — '
      'docs/explainers/sync-subsystem.md claims ${stale.join(', ')} '
      'EntityMerger(s), but lib/core/sync/merge/ actually has $actualCount '
      '*_merger.dart file(s) (excluding entity_merger.dart). Update the '
      "doc's count to $actualCount.",
    );
    exit(1);
  }

  stdout.writeln(
    'AUD-docs-18 merger-count check OK: docs/explainers/sync-subsystem.md '
    'claim(s) (${claims.join(', ')}) match the actual $actualCount '
    '*_merger.dart file(s) under lib/core/sync/merge/.',
  );
}
