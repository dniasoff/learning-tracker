/// Tests for OutboxProcessor — covers drain() dispatch logic with a fake
/// PushPipeline and in-memory OutboxDao.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';

import '../../../helpers/drift_memory.dart';

// ── Fake PushPipeline ────────────────────────────────────────────────────────

class _FakePipeline extends Fake implements PushPipeline {
  final List<(String kind, String entityKey)> calls = [];
  bool failNextPush = false;

  /// When set, [pushCompletionsBatch] throws a [BatchPushException] reporting
  /// exactly these entityKeys as committed (modelling a per-chunk partial
  /// failure where an earlier chunk committed before a later one threw).
  /// The flag is one-shot — it is cleared after it fires.
  List<String>? partialFailureCommitted;

  /// When true, [pushCompletionsBatch] throws a [BatchPushException] with an
  /// empty `committed` list (a TOTAL failure — the first chunk threw).
  /// One-shot — cleared after it fires.
  bool failTotalNextBatch = false;

  /// Records every batch of entityKeys passed to [pushCompletionsBatch].
  final List<List<String>> batchCalls = [];

  @override
  Future<void> pushCompletion({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('completion', entityKey));
  }

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    batchCalls.add(entries.map((e) => e.entityKey).toList());
    if (failNextPush) {
      failNextPush = false;
      throw Exception('network error');
    }
    if (failTotalNextBatch) {
      failTotalNextBatch = false;
      throw BatchPushException(
        committed: const [],
        cause: Exception('total failure — first chunk threw'),
      );
    }
    final partial = partialFailureCommitted;
    if (partial != null) {
      partialFailureCommitted = null;
      for (final key in partial) {
        calls.add(('completion', key));
      }
      throw BatchPushException(
        committed: List.of(partial),
        cause: Exception('partial failure — a later chunk threw'),
      );
    }
    for (final entry in entries) {
      calls.add(('completion', entry.entityKey));
    }
    return entries.map((e) => e.entityKey).toList();
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('streak', entityKey));
  }

  @override
  Future<void> pushSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('settings', entityKey));
  }

  @override
  Future<void> pushTrack({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('track', entityKey));
  }

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('learning_order', entityKey));
  }

  @override
  Future<void> pushBookmark({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('bookmark', entityKey));
  }
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;
  late _FakePipeline pipeline;
  late OutboxProcessor processor;
  const profileId = 1;

  setUp(() {
    db = inMemoryDb();
    pipeline = _FakePipeline();
    processor = OutboxProcessor(
      outboxDao: db.outboxDao,
      pipeline: pipeline,
      clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertRow({
    String entityKind = OutboxEntityKind.completion,
    String entityKey = 'key1',
    Map<String, dynamic>? payload,
  }) async {
    await db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: profileId,
        entityKind: entityKind,
        entityKey: entityKey,
        payload: jsonEncode(payload ?? {'ref': 'Berakhot.2a'}),
        createdAt: DateTime.utc(2026, 5, 14),
      ),
    );
  }

  group('OutboxProcessor.drain', () {
    test('returns 0 when no pending rows', () async {
      final count = await processor.drain(profileId);
      expect(count, 0);
      expect(pipeline.calls, isEmpty);
    });

    test('pushes completion rows and returns 1', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      final count = await processor.drain(profileId);
      expect(count, 1);
      expect(pipeline.calls, [('completion', 'c1')]);
    });

    test('pushes streak rows', () async {
      await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 's1');

      await processor.drain(profileId);
      expect(pipeline.calls, [('streak', 's1')]);
    });

    test('pushes track rows', () async {
      await insertRow(entityKind: OutboxEntityKind.track, entityKey: 't1');

      await processor.drain(profileId);
      expect(pipeline.calls, [('track', 't1')]);
    });

    test('pushes learning_order rows', () async {
      await insertRow(
        entityKind: OutboxEntityKind.learningOrder,
        entityKey: 'lo1',
      );

      await processor.drain(profileId);
      expect(pipeline.calls, [('learning_order', 'lo1')]);
    });

    test('pushes bookmark rows', () async {
      await insertRow(entityKind: OutboxEntityKind.bookmark, entityKey: 'bm1');

      await processor.drain(profileId);
      expect(pipeline.calls, [('bookmark', 'bm1')]);
    });

    test('pushes settings rows', () async {
      await insertRow(entityKind: OutboxEntityKind.settings, entityKey: 'st1');

      await processor.drain(profileId);
      expect(pipeline.calls, [('settings', 'st1')]);
    });

    test('deletes row from outbox after successful push', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      await processor.drain(profileId);

      // Row should be removed.
      final remaining = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        profileId,
      );
      expect(remaining, isEmpty);
    });

    test('keeps row in outbox when push fails', () async {
      pipeline.failNextPush = true;
      await insertRow(
        entityKind: OutboxEntityKind.completion,
        entityKey: 'fail1',
      );

      final count = await processor.drain(profileId);
      expect(count, 0); // failed push does not count

      final remaining = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        profileId,
      );
      expect(remaining, hasLength(1));
    });

    test('continues draining remaining rows after a single failure', () async {
      pipeline.failNextPush = true;
      // Insert a completion (will fail) and then a streak (should succeed).
      await insertRow(
        entityKind: OutboxEntityKind.completion,
        entityKey: 'fail1',
      );
      await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 's1');

      final count = await processor.drain(profileId);
      // Only streak succeeded.
      expect(count, 1);
      expect(pipeline.calls, [('streak', 's1')]);
    });

    test('does not process rows for a different profileId', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      // Drain for profile 2 — should not touch profile 1's row.
      final count = await processor.drain(2);
      expect(count, 0);
      expect(pipeline.calls, isEmpty);
    });

    test('pushes multiple rows of different kinds', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');
      await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 's1');
      await insertRow(entityKind: OutboxEntityKind.bookmark, entityKey: 'bm1');

      final count = await processor.drain(profileId);
      expect(count, 3);
    });
  });

  // ── K3 — BatchPushException partial / total failure accounting ────────────
  group('OutboxProcessor.drain — BatchPushException accounting', () {
    // A mutable clock shared by the processor AND installed globally so
    // `OutboxDao.markAttempted` (which stamps `lastAttemptAt` via
    // `DateTimeFactory.nowUtc()`) reads the same deterministic instant —
    // the retry-backoff window is then fully controllable from the test.
    late FakeLocalDayClock clock;

    setUp(() {
      clock = FakeLocalDayClock(DateTime.utc(2026, 5, 14));
      useLocalDayClock(clock);
      processor = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: pipeline,
        clock: clock,
      );
    });

    tearDown(resetLocalDayClock);

    Future<List<String>> pendingCompletionKeys() async {
      final rows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        profileId,
      );
      return rows.map((r) => r.entityKey).toList()..sort();
    }

    test(
      'partial failure — committed rows are deleted, the rest are retained '
      'and marked attempted',
      () async {
        // Three distinct completions queued.
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
        );
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c2',
        );
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c3',
        );

        // Model a per-chunk partial failure: c1 + c2 committed, then a later
        // chunk threw before c3 landed.
        pipeline.partialFailureCommitted = ['c1', 'c2'];

        final count = await processor.drain(profileId);

        // Only the committed completions count as success.
        expect(count, 2);

        // c1 / c2 deleted; c3 retained for retry.
        final remaining = await pendingCompletionKeys();
        expect(remaining, equals(['c3']));

        // c3's attempt counter was incremented (markAttempted).
        final c3 = (await db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          profileId,
        )).single;
        expect(c3.attempts, 1);
        expect(c3.lastError, isNotNull);
      },
    );

    test(
      'a subsequent drain retries ONLY the uncommitted rows after a partial '
      'failure',
      () async {
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
        );
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c2',
        );
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c3',
        );

        pipeline.partialFailureCommitted = ['c1', 'c2'];
        await processor.drain(profileId);
        pipeline.batchCalls.clear();

        // c3 was marked attempted (attempts=1) — its retry-backoff window is
        // ~30 s. Advance the (shared) clock past it so c3 is eligible again.
        clock.advance(const Duration(minutes: 5));

        // Second drain — only c3 remains, so only c3 is pushed.
        final count = await processor.drain(profileId);
        expect(count, 1);
        expect(pipeline.batchCalls, equals([['c3']]));
        expect(await pendingCompletionKeys(), isEmpty);
      },
    );

    test(
      'total failure — first chunk throws, all rows retained and retried',
      () async {
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
        );
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c2',
        );

        // BatchPushException with an empty committed list — nothing landed.
        pipeline.failTotalNextBatch = true;

        final count = await processor.drain(profileId);
        expect(count, 0);

        // Every row is retained for retry.
        expect(await pendingCompletionKeys(), equals(['c1', 'c2']));
        for (final row in await db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          profileId,
        )) {
          expect(row.attempts, 1, reason: 'every row marked attempted');
          expect(row.lastError, isNotNull);
        }
      },
    );

    test(
      'K4 — duplicate entityKey rows: a committed key deletes EVERY row that '
      'shares it, and a non-committed key retains all of its rows',
      () async {
        // Two outbox rows share entityKey "dup" (no UNIQUE index permits
        // this); a third row "solo" is distinct.
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'dup',
        );
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'dup',
        );
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'solo',
        );

        // The push receives each key exactly once (de-duplicated).
        // "dup" commits; "solo" does not.
        pipeline.partialFailureCommitted = ['dup'];

        final count = await processor.drain(profileId);

        // Each key passed to the pipeline exactly once.
        expect(pipeline.batchCalls, hasLength(1));
        expect(pipeline.batchCalls.single..sort(), equals(['dup', 'solo']));

        // successCount counts unique committed completions, not rows.
        expect(count, 1);

        // BOTH "dup" rows deleted (idempotent — same completion); the "solo"
        // row retained.
        expect(await pendingCompletionKeys(), equals(['solo']));
      },
    );

    test(
      'K4 — duplicate entityKey rows are all retained when the key is NOT '
      'committed (total failure)',
      () async {
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'dup',
        );
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'dup',
        );

        pipeline.failTotalNextBatch = true;

        final count = await processor.drain(profileId);
        expect(count, 0);

        // Both rows retained and each marked attempted.
        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          profileId,
        );
        expect(rows, hasLength(2));
        for (final row in rows) {
          expect(row.attempts, 1);
        }
      },
    );
  });

  group('OutboxEntityKind constants', () {
    test('completion constant is "completion"', () {
      expect(OutboxEntityKind.completion, 'completion');
    });

    test('streak constant is "streak"', () {
      expect(OutboxEntityKind.streak, 'streak');
    });

    test('settings constant is "settings"', () {
      expect(OutboxEntityKind.settings, 'settings');
    });

    test('track constant is "track"', () {
      expect(OutboxEntityKind.track, 'track');
    });

    test('learningOrder constant is "learning_order"', () {
      expect(OutboxEntityKind.learningOrder, 'learning_order');
    });

    test('bookmark constant is "bookmark"', () {
      expect(OutboxEntityKind.bookmark, 'bookmark');
    });
  });
}
