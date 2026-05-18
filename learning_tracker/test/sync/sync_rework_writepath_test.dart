/// Wave 4 — write-path invariant tests for the sync rework.
///
/// S1: bulk-mark of N items → exactly 1 Drift transaction (not N) and
///     exactly N `completion_events` rows.
/// S2: bulk-mark of N items → N `outbox` rows, 0 `sync_queue` rows; AND
///     re-running `commitBatch` with overlapping commands does NOT pile up
///     duplicate outbox rows (the outbox table has no UNIQUE index).
/// S3: a failure mid-transaction rolls BOTH `completion_events` and `outbox`
///     back together — no partial writes.
/// G6: `SyncQueueDao.purgeCompletionRows` removes legacy `completion` rows;
///     it references a shared constant so a rename cannot silently no-op it.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Transaction-counting database
// ---------------------------------------------------------------------------

/// A [UserDatabase] subclass that counts every call to [transaction].
///
/// `commitBatch` must wrap its whole batch in exactly ONE `transaction()`
/// call — counting the invocations directly (rather than a proxy such as the
/// outbox row count) is what actually proves the S1 single-transaction
/// invariant.
class _TxnCountingDb extends UserDatabase {
  _TxnCountingDb(super.executor);

  int transactionCount = 0;

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) {
    transactionCount++;
    return super.transaction(action, requireNew: requireNew);
  }
}

void main() {
  group('S1 + S2 + S3 — write-path invariants', () {
    late _TxnCountingDb db;
    late int trackId;

    setUp(() async {
      db = _TxnCountingDb(NativeDatabase.memory());
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
      // Ignore transactions opened by setUp seeding — only writer-path
      // transactions matter for the S1 assertion.
      db.transactionCount = 0;
    });

    tearDown(() => db.close());

    List<CompletionCommand> commands(
      int n, {
      required String refPrefix,
      DateTime Function(int i)? at,
    }) => List.generate(
      n,
      (i) => CompletionCommand(
        profileId: 1,
        curriculumId: 'mishnayos',
        sefariaRef: '$refPrefix ${i + 1}:1',
        stageId: 1,
        trackType: 'personal',
        trackId: trackId,
        completedAt: at?.call(i) ?? DateTime.utc(2026, 5, 1, 0, i),
        points: 5,
      ),
    );

    // ── S1 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: a bulk-mark of N distinct completions executes exactly ONE
    // Drift transaction (not N), and writes exactly N completion_events rows.
    test('S1: commitBatch of N items opens exactly 1 transaction and writes N '
        'completion_events rows', () async {
      const n = 10;
      final writer = CompletionWriter(db);

      final results = await writer.commitBatch(
        commands(n, refPrefix: 'Berakhot'),
      );

      expect(
        db.transactionCount,
        equals(1),
        reason: 'S1: commitBatch must wrap all N inserts in ONE transaction',
      );

      final events = await db.select(db.completionEvents).get();
      expect(
        events,
        hasLength(n),
        reason: 'S1: exactly N completion_events rows must exist',
      );

      final outboxRows = await db.select(db.outbox).get();
      expect(
        outboxRows,
        hasLength(n),
        reason: 'S1: exactly N outbox rows must exist after bulk mark',
      );

      expect(results, hasLength(n));
      expect(
        results.every((r) => r.isNew),
        isTrue,
        reason: 'S1: all N completions are genuinely new',
      );
    });

    // ── S2 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: bulk-mark writes N `outbox` rows and ZERO `sync_queue` rows.
    test(
      'S2: commitBatch of N items → N outbox rows, 0 sync_queue rows',
      () async {
        const n = 5;
        final writer = CompletionWriter(db);

        await writer.commitBatch(commands(n, refPrefix: 'Shabbat'));

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

    // ── S2 (double-call) — catches G1: duplicate outbox rows ────────────────
    //
    // The outbox table has NO unique index, so re-running commitBatch with
    // overlapping commands must NOT pile up duplicate outbox rows. This test
    // FAILS against the pre-G1 writer (which inserted unconditionally) and
    // PASSES once commitBatch enqueues outbox rows only for genuinely-new
    // completions.
    test('S2: commitBatch called twice with overlapping commands keeps exactly '
        'the distinct-N outbox rows (no duplicate pushes)', () async {
      final writer = CompletionWriter(db);

      // Seven distinct completions: Eruvin 1..7.
      final all = commands(7, refPrefix: 'Eruvin');

      // First call: the first 5 (Eruvin 1..5).
      final firstResults = await writer.commitBatch(all.take(5).toList());
      expect(firstResults.every((r) => r.isNew), isTrue);

      // Second call: 3 of the SAME completions (Eruvin 1..3) overlapping
      // the first call + 2 brand-new ones (Eruvin 6..7).
      final secondResults = await writer.commitBatch([
        ...all.take(3),
        ...all.skip(5),
      ]);

      // The 3 overlapping commands resolve as NOT new; the 2 fresh ones do.
      expect(
        secondResults.where((r) => r.isNew).length,
        equals(2),
        reason: 'only the 2 genuinely-new completions report isNew=true',
      );
      expect(
        secondResults.where((r) => !r.isNew).length,
        equals(3),
        reason: 'the 3 pre-existing completions report isNew=false',
      );

      // 5 distinct from the first call + 2 new from the second = 7.
      final outboxRows = await db.select(db.outbox).get();
      expect(
        outboxRows,
        hasLength(7),
        reason:
            'G1: re-running commitBatch must NOT pile up duplicate outbox '
            'rows for already-persisted completions',
      );

      final events = await db.select(db.completionEvents).get();
      expect(
        events,
        hasLength(7),
        reason: 'completion_events likewise holds 7 distinct rows',
      );
    });

    // ── S2 (in-batch dedup) — catches G1/G3: duplicate commands in one call ─
    test(
      'S2: commitBatch dedupes commands with the same natural key inside one '
      'batch — one event + one outbox row',
      () async {
        final writer = CompletionWriter(db);

        final dup = CompletionCommand(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Yoma 1:1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 5, 3),
          points: 5,
        );
        // Two commands with the SAME natural key but differing curriculumId /
        // trackId — they must still collapse to one event + one outbox row.
        final results = await writer.commitBatch([
          dup,
          dup.copyWith(curriculumId: 'shas', trackId: trackId + 999),
        ]);

        expect(results, hasLength(2), reason: 'one result per input command');

        final events = await db.select(db.completionEvents).get();
        expect(
          events,
          hasLength(1),
          reason: 'G1: in-batch duplicate natural keys collapse to one event',
        );

        final outboxRows = await db.select(db.outbox).get();
        expect(
          outboxRows,
          hasLength(1),
          reason: 'G1: in-batch duplicate produces exactly one outbox row',
        );

        // G3: both input commands resolve to the same (correct) event row.
        expect(
          results[0].completion.id,
          equals(results[1].completion.id),
          reason: 'G3: both duplicate commands resolve to the same event row',
        );
      },
    );

    // ── S3 — partial-failure rollback ───────────────────────────────────────
    //
    // A failure mid-transaction must roll BOTH completion_events and outbox
    // back together. We trigger the failure by wrapping a commitBatch in an
    // outer transaction that then throws — the writer's transaction composes
    // with the outer one, so both tables must end up empty.
    test(
      'S3: a failure mid-transaction rolls back completion_events AND outbox '
      'together — no partial writes',
      () async {
        final writer = CompletionWriter(db);

        await expectLater(
          () => db.transaction(() async {
            await writer.commitBatch(commands(4, refPrefix: 'Sukkah'));
            // Simulate a downstream failure after the batch wrote its rows.
            throw Exception('simulated downstream failure');
          }),
          throwsA(isA<Exception>()),
        );

        final events = await db.select(db.completionEvents).get();
        final outboxRows = await db.select(db.outbox).get();
        expect(
          events,
          isEmpty,
          reason: 'S3: completion_events must roll back with the transaction',
        );
        expect(
          outboxRows,
          isEmpty,
          reason: 'S3: outbox must roll back with the transaction',
        );
      },
    );

    // ── outbox payload schema — snake_case (G8) ─────────────────────────────
    //
    // The Firestore completion-document schema is snake_case; the merge path
    // reads `stage_id` etc. An outbox payload emitting camelCase causes every
    // pulled completion to be skipped (insertedCount:0).
    test(
      'commitBatch outbox payload uses snake_case Firestore schema keys',
      () async {
        final writer = CompletionWriter(db);

        await writer.commitBatch([
          CompletionCommand(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 9:1',
            stageId: 2,
            trackType: 'personal',
            trackId: trackId,
            completedAt: DateTime.utc(2026, 5, 4, 14, 30),
            points: 7,
          ),
        ]);

        final outboxRows = await db.select(db.outbox).get();
        expect(outboxRows, hasLength(1));
        final payload = _decodePayload(outboxRows.first.payload);

        expect(payload, containsPair('profile_id', 1));
        expect(payload, containsPair('curriculum_id', 'mishnayos'));
        expect(payload, containsPair('sefaria_ref', 'Berakhot 9:1'));
        expect(payload, containsPair('stage_id', 2));
        expect(payload, containsPair('track_type', 'personal'));
        expect(payload, containsPair('track_id', trackId));
        expect(payload, containsPair('points', 7));
        expect(
          payload,
          containsPair('completed_at', '2026-05-04T14:30:00.000Z'),
        );
        // No camelCase leakage.
        expect(payload.keys, isNot(contains('stageId')));
        expect(payload.keys, isNot(contains('sefariaRef')));
      },
    );
  });

  // ── G6 — purgeCompletionRows removes legacy `completion` sync_queue rows ──
  //
  // purgeCompletionRows must filter on the shared OutboxEntityKind.completion
  // constant, not a hardcoded literal — a rename then cannot silently turn the
  // purge into a no-op.
  group('G6 — SyncQueueDao.purgeCompletionRows', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
    });

    tearDown(() => db.close());

    test('purgeCompletionRows removes a seeded completion row and leaves other '
        'operation types untouched', () async {
      // Seed a legacy `completion` row plus a non-completion row.
      await db.syncQueueDao.enqueue(OutboxEntityKind.completion, '{}');
      await db.syncQueueDao.enqueue(OutboxEntityKind.streak, '{}');

      expect(
        await db.syncQueueDao.getPendingCount(),
        equals(2),
        reason: 'precondition: two rows queued',
      );

      final removed = await db.syncQueueDao.purgeCompletionRows();
      expect(
        removed,
        equals(1),
        reason: 'exactly the one completion row must be purged',
      );

      final remaining = await db.syncQueueDao.getAllPending();
      expect(remaining, hasLength(1));
      expect(
        remaining.single.operationType,
        equals(OutboxEntityKind.streak),
        reason: 'non-completion rows must survive the purge',
      );
    });
  });
}

Map<String, Object?> _decodePayload(String raw) =>
    Map<String, Object?>.from(jsonDecode(raw) as Map);
