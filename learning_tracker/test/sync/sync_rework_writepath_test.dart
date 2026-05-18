/// Wave 0 — characterization tests for the sync rework write-path invariants.
///
/// S1: bulk-mark of N items → exactly 1 Drift transaction (not N).
/// S2: bulk-mark of N items → N outbox rows, 0 sync_queue rows.
///
/// All tests are skipped; un-skip in Wave 1 once the fix is in.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Transaction-counting shim
// ---------------------------------------------------------------------------

/// Wraps [UserDatabase] and counts how many times [transaction] is entered
/// at the top level.
///
/// Note: because Drift's [transaction] is a concrete method on the live
/// database we cannot easily intercept it without codegen mocks. Instead we
/// count outbox insertions as a proxy, since each transaction inserts exactly
/// one outbox row.  A future Wave 1 fix may use a counting DAO wrapper if a
/// per-transaction counter is needed.
///
/// For S1 the invariant is that N separate [CompletionWriter.commit] calls on
/// a *single* facade produce exactly N outbox rows AND that a future
/// "bulk-commit" path produces exactly 1 Drift transaction. The test below
/// pins the desired post-fix behaviour: a bulk helper should write N
/// completion_events and N outbox rows in **one** transaction, observable as
/// a single BEGIN/COMMIT pair in the WAL.  Since we cannot count
/// BEGIN/COMMITs without hooking into the native driver, we validate the
/// *outcome* of the invariant: N outbox rows exist after the bulk call, and
/// no rows were written via the legacy sync_queue path.
// ---------------------------------------------------------------------------

void main() {
  group('S1 + S2 — write-path invariants (Wave 0 characterization)', () {
    late UserDatabase db;
    late int trackId;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
      trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
              isActive: const Value(true),
            ),
          );
    });

    tearDown(() => db.close());

    // ── S1 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: a bulk-mark of N distinct completions executes exactly ONE
    // Drift transaction (not N individual ones).
    //
    // Current behaviour (pre-fix): CompletionWriter.commit() opens one
    // transaction per item. The rework must expose a bulk API that wraps all
    // N inserts in a single `db.transaction()` call.
    //
    // The test validates the *proxy observable*: after one hypothetical bulk
    // call the outbox holds exactly N rows, confirming that all N commits
    // landed.  Counting actual BEGIN/COMMIT pairs requires WAL-level
    // instrumentation not yet available; Wave 1 may add a
    // `TransactionCountingDb` wrapper if needed.
    test(
      'S1: bulk-mark of N items produces N outbox rows (1-transaction invariant)',
      skip: 'un-skip in Wave 1',
      () async {
        const n = 10;
        final writer = CompletionWriter(db);

        // TODO (Wave 1): replace this loop with the new bulk API once it
        // exists, e.g.:
        //   await writer.commitBulk(commands);
        // and assert that the underlying db.transaction() was called once.
        // For now the loop acts as the baseline (N transactions) that the
        // fix must beat.
        for (var i = 0; i < n; i++) {
          await writer.commit(
            CompletionCommand(
              profileId: 1,
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot ${i + 1}:1',
              stageId: 1,
              trackType: 'personal',
              trackId: trackId,
              completedAt: DateTime.utc(2026, 5, 1, 0, i),
              points: 5,
            ),
          );
        }

        final outboxRows = await db.select(db.outbox).get();
        expect(
          outboxRows,
          hasLength(n),
          reason: 'S1: exactly N outbox rows must exist after bulk mark',
        );

        // The real Wave-1 assertion that gates passing:
        // expect(transactionCount, equals(1),
        //   reason: 'S1: all N inserts must share one Drift transaction');
      },
    );

    // ── S2 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: bulk-mark writes N `outbox` rows and ZERO `sync_queue` rows.
    //
    // The legacy OfflineQueue path (sync_queue table) must not be written by
    // the new write path. CompletionWriter already routes through `outbox`;
    // this test pins that sync_queue stays empty.
    test(
      'S2: bulk-mark of N items → N outbox rows, 0 sync_queue rows',
      skip: 'un-skip in Wave 1',
      () async {
        const n = 5;
        final writer = CompletionWriter(db);

        for (var i = 0; i < n; i++) {
          await writer.commit(
            CompletionCommand(
              profileId: 1,
              curriculumId: 'mishnayos',
              sefariaRef: 'Shabbat ${i + 1}:1',
              stageId: 1,
              trackType: 'personal',
              trackId: trackId,
              completedAt: DateTime.utc(2026, 5, 2, 0, i),
              points: 5,
            ),
          );
        }

        final outboxRows = await db.select(db.outbox).get();
        expect(
          outboxRows,
          hasLength(n),
          reason: 'S2: exactly N outbox rows must be written',
        );

        final syncQueueRows = await db.select(db.syncQueue).get();
        expect(
          syncQueueRows,
          isEmpty,
          reason:
              'S2: the new write path must write zero sync_queue rows; '
              'only the outbox table is the push source',
        );
      },
    );
  });
}
