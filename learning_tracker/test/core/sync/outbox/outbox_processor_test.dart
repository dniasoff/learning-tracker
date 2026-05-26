/// Tests for OutboxProcessor — covers drain() dispatch logic with a fake
/// PushPipeline and in-memory OutboxDao.
library;

import 'dart:async';
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
        pushCause: Exception('total failure — first chunk threw'),
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
        pushCause: Exception('partial failure — a later chunk threw'),
      );
    }
    for (final entry in entries) {
      calls.add(('completion', entry.entityKey));
    }
    return entries.map((e) => e.entityKey).toList();
  }

  /// When true, [pushStreak] returns a Future that never completes — models a
  /// Firestore write hanging on an online-but-unreachable network (the bug the
  /// per-push timeout guards against).
  bool hangStreak = false;

  @override
  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    if (hangStreak) {
      await Completer<void>().future; // never completes
    }
    calls.add(('streak', entityKey));
  }

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('learner_profile', entityKey));
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
    int rowProfileId = profileId,
  }) async {
    await db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: rowProfileId,
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

    test('SYNC-2: account-level row enqueued under profile 0 is swept when '
        'draining the active profile', () async {
      // The initial learner_profile push is queued before any profile is
      // active (facade _profileId == 0). Draining the active profile (1)
      // must also sweep profile-0 rows, else the profile never uploads.
      await insertRow(
        entityKind: OutboxEntityKind.learnerProfile,
        entityKey: '1',
        payload: {'profile_id': 1, 'display_name': 'X'},
        rowProfileId: 0,
      );

      final count = await processor.drain(profileId); // active profile = 1
      expect(count, 1);
      expect(pipeline.calls, [('learner_profile', '1')]);
      // Row is deleted after a successful push.
      expect(await db.outboxDao.depth(0), 0);
    });

    test('SYNC-1: a hung push times out and does NOT wedge the single-flight '
        'guard; the row is retried on the next drain', () async {
      // Short timeout/stale window so the test runs in milliseconds.
      final p = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: pipeline,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
        pushTimeout: const Duration(milliseconds: 50),
        drainStaleAfter: const Duration(milliseconds: 10),
      );
      await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 's1');

      // First drain: push hangs → times out → row marked attempted, NOT
      // deleted, and the drain returns (does not hang forever).
      pipeline.hangStreak = true;
      final first = await p.drain(profileId);
      expect(first, 0, reason: 'hung push commits nothing');
      final rows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.streak,
        profileId,
      );
      expect(rows, hasLength(1));
      expect(
        rows.single.attempts,
        greaterThan(0),
        reason: 'timed-out push is recorded as an attempt, not left at 0',
      );

      // Guard not wedged: the timed-out drain completed and released the
      // single-flight guard, so a subsequent drain runs normally. Prove it
      // by pushing a FRESH row (the hung row itself is now in backoff).
      pipeline.hangStreak = false;
      await insertRow(
        entityKind: OutboxEntityKind.completion,
        entityKey: 'c-fresh',
      );
      final second = await p.drain(profileId);
      expect(
        second,
        greaterThanOrEqualTo(1),
        reason: 'guard was reclaimed; a later drain still works',
      );
      expect(pipeline.calls, contains(('completion', 'c-fresh')));
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

    test('partial failure — committed rows are deleted, the rest are retained '
        'and marked attempted', () async {
      // Three distinct completions queued.
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c2');
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c3');

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
    });

    test('a subsequent drain retries ONLY the uncommitted rows after a partial '
        'failure', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c2');
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c3');

      pipeline.partialFailureCommitted = ['c1', 'c2'];
      await processor.drain(profileId);
      pipeline.batchCalls.clear();

      // c3 was marked attempted (attempts=1) — its retry-backoff window is
      // ~30 s. Advance the (shared) clock past it so c3 is eligible again.
      clock.advance(const Duration(minutes: 5));

      // Second drain — only c3 remains, so only c3 is pushed.
      final count = await processor.drain(profileId);
      expect(count, 1);
      expect(
        pipeline.batchCalls,
        equals([
          ['c3'],
        ]),
      );
      expect(await pendingCompletionKeys(), isEmpty);
    });

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

    test('K4 — duplicate entityKey rows are all retained when the key is NOT '
        'committed (total failure)', () async {
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
    });
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

    test('studyDayConfig constant is "study_day_config"', () {
      expect(OutboxEntityKind.studyDayConfig, 'study_day_config');
    });
  });

  // Phase 0 — single-flight guard. Concurrent drain() calls collapse to one
  // in-flight invocation so the five wired triggers (write-tee + pull-complete
  // + connectivity + lifecycle + periodic) cannot stampede the pipeline.
  group('OutboxProcessor.drain — single-flight', () {
    test('concurrent drains run the pipeline exactly once', () async {
      // Use a pipeline whose batch call awaits a Completer so we can hold
      // the in-flight drain open long enough to fire concurrent drains.
      final blocking = _BlockingPipeline();
      final guarded = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: blocking,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
      );

      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      // Kick off the first drain — it blocks inside the fake pipeline.
      final first = guarded.drain(profileId);

      // Fire four more drains while the first is still in flight. Each must
      // return 0 immediately (the single-flight guard short-circuits them).
      final concurrent = await Future.wait([
        guarded.drain(profileId),
        guarded.drain(profileId),
        guarded.drain(profileId),
        guarded.drain(profileId),
      ]);

      expect(
        concurrent,
        equals([0, 0, 0, 0]),
        reason: 'concurrent drains must skip while another is in flight',
      );

      // Unblock the first drain and let it complete.
      blocking.release();
      final firstResult = await first;
      expect(firstResult, 1, reason: 'first drain pushed the row');

      // The pipeline saw exactly one batch call (the others were short-circuited).
      expect(blocking.batchCalls, 1);
    });

    test('drain releases the guard after completion so a subsequent drain '
        'can run again', () async {
      // Use the standard fake pipeline (synchronous) — we drain twice in
      // sequence to assert the guard is released after the first call.
      final guarded = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: pipeline,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
      );

      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');
      await guarded.drain(profileId);

      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c2');
      final secondCount = await guarded.drain(profileId);
      expect(secondCount, 1, reason: 'guard released → second drain runs');
    });

    test('drain releases the guard even when the pipeline throws', () async {
      // Use a pipeline that throws on its first invocation. The pre-existing
      // total-failure tests prove _doDrain itself doesn't propagate the
      // BatchPushException — what matters here is that the single-flight
      // flag is reset whether or not the inner work threw. After the first
      // drain runs (and "fails" by retaining the row), a second drain must
      // be able to start: that is only possible if `_draining` was cleared
      // in the try/finally.
      final throwing = _ThrowingThenSucceedingPipeline();
      final guarded = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: throwing,
        // Use a clock pinned in the future so the row is always eligible
        // (the backoff check compares lastAttemptAt + delay < now).
        clock: FakeLocalDayClock(DateTime.utc(2099, 1, 1)),
      );

      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      // First drain — the pipeline throws (BatchPushException with empty
      // committed), the row is retained and marked attempted. The drain
      // method itself does NOT rethrow.
      await guarded.drain(profileId);

      final rowsAfterFirst = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        profileId,
      );
      expect(rowsAfterFirst, hasLength(1), reason: 'row retained on failure');

      // Second drain — single-flight flag was cleared, so the drain runs
      // and the pipeline succeeds on its second invocation. The pinned
      // future clock keeps the backoff window in the past.
      final secondCount = await guarded.drain(profileId);
      expect(
        secondCount,
        1,
        reason: 'guard was released — second drain pushed the row',
      );
    });
  });
}

/// Pipeline whose `pushCompletionsBatch` parks on a Completer until [release]
/// is invoked. Lets the test hold an in-flight drain open while firing
/// concurrent drains.
class _BlockingPipeline extends Fake implements PushPipeline {
  final Completer<void> _gate = Completer<void>();
  int batchCalls = 0;

  void release() => _gate.complete();

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    batchCalls++;
    await _gate.future;
    return entries.map((e) => e.entityKey).toList();
  }
}

/// Pipeline that throws on its first batch call (total failure) and succeeds
/// thereafter — used to verify the single-flight guard is released even when
/// the pipeline throws.
class _ThrowingThenSucceedingPipeline extends Fake implements PushPipeline {
  bool _firstCall = true;

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    if (_firstCall) {
      _firstCall = false;
      throw BatchPushException(
        committed: const [],
        pushCause: Exception('first-call failure'),
      );
    }
    return entries.map((e) => e.entityKey).toList();
  }
}
