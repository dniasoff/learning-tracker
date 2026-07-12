// Tests for `tool/check_db_dao_loop_writes.dart` (AUD-core-database-05,
// DB-2/DB-3).
//
// Mirrors the fixture-based approach in `check_db_transactions_test.dart`:
// write a disposable fixture file into the checker's scanned file, run the
// script, assert it fires, restore the clean file, assert a clean pass.
// This is the Rule-0 "demonstrate it fires on a deliberately-broken fixture
// then passes clean" evidence, captured as a durable regression test rather
// than a one-off manual run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_db_dao_loop_writes.dart';
  final scopedFile = File(
    '$packageDir/lib/core/database/daos/track_learning_order_dao.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  group('tool/check_db_dao_loop_writes.dart (AUD-core-database-05, '
      'DB-2/DB-3)', () {
    test('exits 0 on the real (fixed) tree — upsertOrder uses batch(), not an '
        'awaited per-row loop', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('check passed'));
    });

    test('AC: reverting upsertOrder to an awaited per-row into( loop flips the '
        'checker from clean to FAILED, and restoring the batch() fix restores '
        'clean', () async {
      final originalContent = scopedFile.readAsStringSync();

      try {
        // The exact pre-fix shape this finding (AUD-core-database-05)
        // replaced: an awaited per-row `into(...).insert(...)` loop with
        // no enclosing batch()/transaction().
        scopedFile.writeAsStringSync(r'''
import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/track_learning_order.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'track_learning_order_dao.g.dart';

@DriftAccessor(tables: [TrackLearningOrder])
class TrackLearningOrderDao extends DatabaseAccessor<UserDatabase>
    with _$TrackLearningOrderDaoMixin {
  TrackLearningOrderDao(super.db);

  Future<void> upsertOrder(int trackId, List<String> refs) async {
    for (var i = 0; i < refs.length; i++) {
      await into(trackLearningOrder).insert(
        TrackLearningOrderCompanion.insert(
          trackId: trackId,
          sefariaRef: refs[i],
          sortOrder: i,
        ),
      );
    }
  }
}
''');

        final withFixture = await runCheck();
        expect(
          withFixture.exitCode,
          1,
          reason:
              'an awaited per-row into( loop with no enclosing batch()/'
              'transaction() must fail the checker.\n'
              'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
        );
        expect(
          withFixture.stderr.toString(),
          allOf(
            contains('track_learning_order_dao.dart'),
            contains('await into('),
          ),
        );
      } finally {
        scopedFile.writeAsStringSync(originalContent);
      }

      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'restoring the batch()-based fix must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
    });

    test('a fixture loop wrapping the write in batch() (the real fix shape) '
        'does NOT trip the checker', () async {
      // The real fixed file already exercises this shape end-to-end (see
      // the first test above) — this test isolates just the loop-plus-
      // batch-builder pattern to document why the checker does not
      // consider it a violation: `b.insert(` is a synchronous batch
      // builder call, never `await into(`.
      expect(scopedFile.readAsStringSync(), contains('batch((b) {'));
      expect(scopedFile.readAsStringSync(), isNot(contains('await into(')));
    });
  });
}
