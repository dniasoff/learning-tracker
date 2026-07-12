/// DB-2/DB-3 DAO-layer loop-write checker — AUD-core-database-05.
///
/// AUD-core-database-05's fix replaced `TrackLearningOrderDao.upsertOrder`'s
/// awaited per-row insert loop with a single `batch()` (DB-3) and wrapped
/// its repository call sites' order-write + `stampReorderAt` pair in a
/// single `transaction()` (DB-2). The finding's own acceptance criterion
/// notes no Rule-0 checker existed yet for this class of bug in the DAO
/// layer and names the cheap pattern to catch it: "a grep for `for (`
/// followed within a few lines by `await into(` or `await (db.update`/
/// `await (db.delete`".
///
/// This script implements exactly that pattern: it finds every `for (` /
/// `.forEach(` loop opener in the scoped file(s) below and fails if an
/// `await into(`, `await (db.update`, or `await (db.delete` call appears
/// within the following few lines — the awaited-per-row-write shape DB-3
/// forbids. The fixed `upsertOrder` (a `batch((b) { for (...) b.insert(...) }
/// )`) does not match: `b.insert(` is a synchronous batch-builder call, not
/// an awaited `into(...).insert(...)`.
///
/// **Scope (Rule 0 — start scoped, expand later; mirrors the DB-2/DB-3/EH-3/
/// EH-4 scoped-checker precedent in this codebase — see
/// `tool/check_db_transactions.dart`, `tool/check_db3_batch_inserts.dart`,
/// `tool/check_eh3_log_less_catch.dart`):** only
/// `lib/core/database/daos/track_learning_order_dao.dart`, the exact file
/// this finding fixes. `point_config_dao.dart` and `study_day_config_dao.dart`
/// carry the same pre-existing loop-write shape in their (unfixed, out of
/// scope for AUD-core-database-05) `seedDefaults` methods — see the
/// finding's evidence — a codebase-wide rollout would immediately fail the
/// audit gate on that unrelated backlog; widening this checker's scope is a
/// follow-up, not part of this fix.
///
/// Usage:
///   dart run tool/check_db_dao_loop_writes.dart
///
/// Exit codes:
///   0 — no `for`/`.forEach(` loop in the scoped file(s) awaits a per-row
///       `into(`/`db.update`/`db.delete` write
///   1 — one or more such loops found (prints file:line)
library;

import 'dart:io';

const _scopedFiles = ['lib/core/database/daos/track_learning_order_dao.dart'];

/// Matches a loop-opening statement: `for (...)` or `...forEach(`.
final _loopOpener = RegExp(r'\bfor\s*\(|\.forEach\s*\(');

/// Matches an awaited per-row write call — the exact shape named by
/// AUD-core-database-05's acceptance criterion.
final _awaitedPerRowWrite = RegExp(
  r'await\s+into\(|await\s*\(\s*db\.update|await\s*\(\s*db\.delete',
);

/// How many lines after a loop opener to scan for an awaited per-row write.
/// Generous enough to cover a multi-line loop header/body opening without
/// bleeding into an unrelated subsequent method.
const _windowLines = 6;

void main() {
  final violations = <String>[];

  for (final path in _scopedFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('ERROR: scoped file not found: $path');
      exit(1);
    }
    violations.addAll(_findLoopedPerRowWrites(path, file.readAsStringSync()));
  }

  if (violations.isNotEmpty) {
    stderr.writeln('DB-2/DB-3 DAO loop-write check FAILED:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'DB-2/DB-3 DAO loop-write check passed — no for/.forEach( loop in the '
    'scoped file(s) awaits a per-row into(/db.update/db.delete write.',
  );
}

List<String> _findLoopedPerRowWrites(String path, String content) {
  final violations = <String>[];
  final lines = content.split('\n');

  for (var i = 0; i < lines.length; i++) {
    if (!_loopOpener.hasMatch(lines[i])) continue;

    final windowEnd = (i + _windowLines).clamp(0, lines.length);
    for (var j = i; j < windowEnd; j++) {
      final match = _awaitedPerRowWrite.firstMatch(lines[j]);
      if (match == null) continue;
      violations.add(
        '$path:${j + 1}: a loop opened at line ${i + 1} awaits a per-row '
        'write (DB-2/DB-3, AUD-core-database-05) — use batch()/insertAll '
        'and wrap paired writes in transaction() instead: '
        '${match.group(0)}',
      );
      break;
    }
  }

  return violations;
}
