/// Tests for OutboxProcessor — covers drain() dispatch logic with a fake
/// PushPipeline and in-memory OutboxDao.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';

import '../../../helpers/drift_memory.dart';

// ── Fake AnalyticsService ────────────────────────────────────────────────────

class _FakeAnalyticsService extends AnalyticsService {
  final List<(String name, Map<String, Object?>?)> events = [];

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    events.add((name, parameters));
  }
}

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

  /// When set, [pushStreak] throws this (typically a
  /// [FirestorePermissionDeniedException]) instead of succeeding. One-shot —
  /// cleared after it fires. Models a permission-denied write failure
  /// (AUD-core-sync-20) distinctly from [failNextPush]'s generic Exception.
  Exception? throwOnNextStreak;

  @override
  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    if (hangStreak) {
      await Completer<void>().future; // never completes
    }
    final toThrow = throwOnNextStreak;
    if (toThrow != null) {
      throwOnNextStreak = null;
      throw toThrow;
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

    // AUD-core-sync-17: pushCompletionsBatch exists specifically to avoid an
    // N-round-trip problem against Firestore, but the local cleanup after a
    // large committed/failed group still ran one awaited deleteRow/
    // markAttempted per outbox row — reintroducing that same cost against
    // Drift. Assert the bulk DAO methods are invoked exactly ONCE per
    // outcome group, regardless of how many rows are in it.
    test('AUD-core-sync-17: deleteRows/markAttemptedBulk are each invoked '
        'exactly once for a multi-row commit/failure group', () async {
      final countingDao = _CountingOutboxDao(db);
      final p = OutboxProcessor(
        outboxDao: countingDao,
        pipeline: pipeline,
        clock: clock,
      );

      // Three committed rows (distinct keys) + two rows sharing a key that
      // fails — one commit group of 3 ids, one failure group of 2 ids.
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c2');
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c3');
      await insertRow(
        entityKind: OutboxEntityKind.completion,
        entityKey: 'bad',
      );
      await insertRow(
        entityKind: OutboxEntityKind.completion,
        entityKey: 'bad',
      );

      pipeline.partialFailureCommitted = ['c1', 'c2', 'c3'];

      final count = await p.drain(profileId);

      expect(count, 3, reason: 'three distinct completions committed');
      expect(
        countingDao.deleteRowsCalls,
        1,
        reason: 'one bulk delete for the whole 3-row commit group, not 3',
      );
      expect(
        countingDao.markAttemptedBulkCalls,
        1,
        reason:
            'one bulk markAttempted for the whole 2-row failure group, '
            'not 2',
      );

      // Functional correctness is preserved by the batching.
      expect(await pendingCompletionKeys(), equals(['bad', 'bad']));
      final badRows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        profileId,
      );
      for (final row in badRows) {
        expect(row.attempts, 1);
        expect(row.lastError, isNotNull);
      }
    });
  });

  // ── FIFO ordering ─────────────────────────────────────────────────────────
  group('OutboxProcessor.drain — FIFO ordering', () {
    test(
      'completion rows are sent in creation-time order (oldest first)',
      () async {
        // Three rows created with distinct timestamps — the drain must dispatch
        // them in FIFO (oldest-first) order.
        await db.outboxDao.insertOutboxRow(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: OutboxEntityKind.completion,
            entityKey: 'first',
            payload: jsonEncode({'ref': 'Berakhot.2a'}),
            createdAt: DateTime.utc(2026, 5, 14, 10, 0, 0),
          ),
        );
        await db.outboxDao.insertOutboxRow(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: OutboxEntityKind.completion,
            entityKey: 'second',
            payload: jsonEncode({'ref': 'Berakhot.2b'}),
            createdAt: DateTime.utc(2026, 5, 14, 11, 0, 0),
          ),
        );
        await db.outboxDao.insertOutboxRow(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: OutboxEntityKind.completion,
            entityKey: 'third',
            payload: jsonEncode({'ref': 'Berakhot.3a'}),
            createdAt: DateTime.utc(2026, 5, 14, 12, 0, 0),
          ),
        );

        await processor.drain(profileId);

        // All three dispatched; the pipeline received them in creation order.
        expect(
          pipeline.batchCalls.single,
          equals(['first', 'second', 'third']),
          reason: 'completions drained oldest-first',
        );
      },
    );

    test('non-completion rows are drained in the deterministic kind order '
        '(streaks before settings)', () async {
      // Enqueue a settings row and a streak row — settings first in the DB,
      // but streaks must be dispatched first per _nonCompletionKinds ordering.
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: OutboxEntityKind.settings,
          entityKey: 'sett1',
          payload: jsonEncode({'key': 'v'}),
          createdAt: DateTime.utc(2026, 5, 14, 10, 0, 0),
        ),
      );
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: OutboxEntityKind.streak,
          entityKey: 'streak1',
          payload: jsonEncode({'count': 1}),
          createdAt: DateTime.utc(2026, 5, 14, 11, 0, 0),
        ),
      );

      await processor.drain(profileId);

      // streak must appear before settings in the calls list.
      final kindOrder = pipeline.calls.map((c) => c.$1).toList();
      final streakIdx = kindOrder.indexOf('streak');
      final settingsIdx = kindOrder.indexOf('settings');
      expect(
        streakIdx,
        lessThan(settingsIdx),
        reason: 'streak drained before settings per _nonCompletionKinds order',
      );
    });
  });

  // ── Exponential backoff ────────────────────────────────────────────────────
  group('OutboxProcessor.drain — exponential backoff', () {
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

    test('non-completion row with attempts=1 is skipped while backoff window '
        'is active, then retried once the window elapses', () async {
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: OutboxEntityKind.streak,
          entityKey: 'sk1',
          payload: jsonEncode({'count': 1}),
          createdAt: clock.nowUtc(),
          // Simulate a row that already had one failed attempt 5 seconds ago.
          attempts: const Value(1),
          lastAttemptAt: Value(
            clock.nowUtc().subtract(const Duration(seconds: 5)),
          ),
        ),
      );

      // Clock is now: lastAttemptAt was 5s ago; backoff base = 30s, so
      // nextAttemptAt ≈ lastAttemptAt + 30s, which is still in the future.
      final countWhileBackoff = await processor.drain(profileId);
      expect(
        countWhileBackoff,
        0,
        reason: 'row in backoff window must be skipped',
      );
      expect(pipeline.calls, isEmpty, reason: 'no push while in backoff');

      // Advance 60s past lastAttemptAt — well clear of the 30s base window.
      clock.advance(const Duration(seconds: 60));

      final countAfterBackoff = await processor.drain(profileId);
      expect(
        countAfterBackoff,
        1,
        reason: 'row eligible again after backoff window elapses',
      );
      expect(pipeline.calls, [('streak', 'sk1')]);
    });

    test('completion row with attempts=1 is skipped while backoff window is '
        'active, then sent in the next drain', () async {
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
          payload: jsonEncode({'ref': 'Berakhot.2a'}),
          createdAt: clock.nowUtc(),
          attempts: const Value(1),
          lastAttemptAt: Value(
            clock.nowUtc().subtract(const Duration(seconds: 5)),
          ),
        ),
      );

      // Still in backoff window.
      expect(await processor.drain(profileId), 0);
      expect(pipeline.batchCalls, isEmpty);

      // Advance past the base window (~30s jittered; 120s is safe).
      clock.advance(const Duration(seconds: 120));

      expect(await processor.drain(profileId), 1);
      expect(pipeline.batchCalls, hasLength(1));
    });

    test(
      'fresh row (attempts=0, no lastAttemptAt) is always eligible',
      () async {
        await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 'new');
        // Clock has not moved; row has 0 attempts and null lastAttemptAt.
        expect(await processor.drain(profileId), 1);
      },
    );
  });

  // ── Dead-letter at _maxAttempts ────────────────────────────────────────────
  group('OutboxProcessor.drain — dead-letter at maxAttempts', () {
    late FakeLocalDayClock clock;
    late _FakeAnalyticsService analytics;

    setUp(() {
      clock = FakeLocalDayClock(DateTime.utc(2026, 5, 14));
      useLocalDayClock(clock);
      analytics = _FakeAnalyticsService();
      processor = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: pipeline,
        clock: clock,
        analytics: analytics,
      );
    });

    tearDown(resetLocalDayClock);

    test('non-completion row with attempts == 10 is permanently skipped and '
        'never pushed', () async {
      // Insert a row that has already hit the max-attempts ceiling.
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: OutboxEntityKind.streak,
          entityKey: 'dead',
          payload: jsonEncode({'count': 5}),
          createdAt: DateTime.utc(2026, 5, 1),
          attempts: const Value(10),
          lastAttemptAt: Value(DateTime.utc(2026, 5, 13)),
        ),
      );

      final count = await processor.drain(profileId);
      expect(count, 0, reason: 'dead-lettered row must not be pushed');
      expect(
        pipeline.calls.where((c) => c.$2 == 'dead'),
        isEmpty,
        reason: 'pipeline never called for a dead-lettered key',
      );
      // Row is NOT deleted — it stays in the outbox (observable via depth).
      expect(await db.outboxDao.depth(profileId), 1);
    });

    test('dead-lettered non-completion row fires the outbox_dead_lettered '
        'analytics event', () async {
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: OutboxEntityKind.streak,
          entityKey: 'dead-streak',
          payload: jsonEncode({'count': 5}),
          createdAt: DateTime.utc(2026, 5, 1),
          attempts: const Value(10),
          lastAttemptAt: Value(DateTime.utc(2026, 5, 13)),
        ),
      );

      await processor.drain(profileId);

      // The analytics event must have been fired with the dead-letter tag.
      expect(analytics.events, isNotEmpty);
      final eventNames = analytics.events.map((e) => e.$1).toList();
      expect(
        eventNames,
        contains('sync_outbox_dead_lettered'),
        reason: 'analytics must record the dead-lettered row',
      );
      final params = analytics.events
          .firstWhere((e) => e.$1 == 'sync_outbox_dead_lettered')
          .$2;
      expect(params?['entity_kind'], OutboxEntityKind.streak);
      expect(params?['attempts'], 10);
      // AUD-core-analytics-01 (PV-1): entity_key must NEVER reach analytics —
      // for completions it embeds `${profileId}:${sefariaRef}:...` (see
      // completion_writer.dart), combining a per-child identifier with the
      // exact content the child studied in one uncatalogued event.
      expect(
        params?.containsKey('entity_key'),
        isFalse,
        reason: 'entity_key must be stripped from the analytics payload',
      );
    });

    test(
      'dead-lettered completion row fires the outbox_dead_lettered analytics '
      'event and is never pushed',
      () async {
        await db.outboxDao.insertOutboxRow(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: OutboxEntityKind.completion,
            entityKey: 'dead-c1',
            payload: jsonEncode({'ref': 'Berakhot.2a'}),
            createdAt: DateTime.utc(2026, 5, 1),
            attempts: const Value(10),
            lastAttemptAt: Value(DateTime.utc(2026, 5, 13)),
          ),
        );

        await processor.drain(profileId);

        expect(
          pipeline.batchCalls,
          isEmpty,
          reason: 'dead completion not pushed',
        );
        final eventNames = analytics.events.map((e) => e.$1).toList();
        expect(eventNames, contains('sync_outbox_dead_lettered'));
        final params = analytics.events
            .firstWhere((e) => e.$1 == 'sync_outbox_dead_lettered')
            .$2;
        expect(params?['entity_kind'], OutboxEntityKind.completion);
        // AUD-core-analytics-01 (PV-1): entity_key must NEVER reach
        // analytics for completions — it embeds
        // `${profileId}:${sefariaRef}:${stageId}:${trackType}:${curriculumId}`
        // (see completion_writer.dart), a per-child identifier combined
        // with the exact content the child was studying.
        expect(
          params?.containsKey('entity_key'),
          isFalse,
          reason: 'entity_key must be stripped from the analytics payload',
        );
      },
    );

    test(
      'a row with attempts == 9 (one below ceiling) IS still tried',
      () async {
        await db.outboxDao.insertOutboxRow(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: OutboxEntityKind.streak,
            entityKey: 'almost-dead',
            payload: jsonEncode({'count': 9}),
            createdAt: DateTime.utc(2026, 5, 1),
            attempts: const Value(9),
            // Place lastAttemptAt far enough in the past that the (capped at 1h)
            // backoff window is fully elapsed.
            lastAttemptAt: Value(DateTime.utc(2026, 5, 12)),
          ),
        );

        final count = await processor.drain(profileId);
        expect(count, 1, reason: 'row at attempts=9 is not yet dead-lettered');
        expect(pipeline.calls, [('streak', 'almost-dead')]);
        // The row is deleted after a successful push.
        expect(await db.outboxDao.depth(profileId), 0);
      },
    );
  });

  // ── AUD-core-sync-20: permission_denied analytics from an outbox PUSH ──────
  //
  // Before this fix, sync_orchestrator.dart's AnalyticsEvent.syncPermissionDenied
  // fired only from the pullOnLaunch error handler — a permission-denied
  // outbox PUSH failure was silently indistinguishable from any other push
  // error. These tests show the same event now also fires from a drain(),
  // regardless of which trigger (periodic, connectivity, write-tee, ...)
  // invoked it.
  group(
    'OutboxProcessor.drain — permission_denied analytics (AUD-core-sync-20)',
    () {
      late FakeLocalDayClock clock;
      late _FakeAnalyticsService analytics;

      setUp(() {
        clock = FakeLocalDayClock(DateTime.utc(2026, 5, 14));
        useLocalDayClock(clock);
        analytics = _FakeAnalyticsService();
        processor = OutboxProcessor(
          outboxDao: db.outboxDao,
          pipeline: pipeline,
          clock: clock,
          analytics: analytics,
        );
      });

      tearDown(resetLocalDayClock);

      test('a permission-denied non-completion push failure fires '
          'sync_permission_denied — not only from pullOnLaunch', () async {
        await db.outboxDao.insertOutboxRow(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: OutboxEntityKind.streak,
            entityKey: 'sk-denied',
            payload: jsonEncode({'count': 1}),
            createdAt: clock.nowUtc(),
          ),
        );
        pipeline.throwOnNextStreak = const FirestorePermissionDeniedException(
          'simulated PERMISSION_DENIED',
          collection: 'streak_events',
          operation: 'write',
        );

        await processor.drain(profileId);

        final eventNames = analytics.events.map((e) => e.$1).toList();
        expect(
          eventNames,
          contains('sync_permission_denied'),
          reason:
              'a permission-denied outbox PUSH failure must fire the same '
              'analytics event the pull path already fires — this is the '
              'gap AUD-core-sync-20 closes',
        );
        final params = analytics.events
            .firstWhere((e) => e.$1 == 'sync_permission_denied')
            .$2;
        expect(params?['collection'], 'streak_events');
        expect(params?['operation'], 'write');
      });

      test(
        'a non-permission-denied push failure does NOT fire '
        'sync_permission_denied (only genuine permission-denied errors do)',
        () async {
          await db.outboxDao.insertOutboxRow(
            OutboxCompanion.insert(
              profileId: profileId,
              entityKind: OutboxEntityKind.streak,
              entityKey: 'sk-offline',
              payload: jsonEncode({'count': 1}),
              createdAt: clock.nowUtc(),
            ),
          );
          pipeline.throwOnNextStreak = Exception(
            'offline: network unreachable',
          );

          await processor.drain(profileId);

          final eventNames = analytics.events.map((e) => e.$1).toList();
          expect(eventNames, isNot(contains('sync_permission_denied')));
        },
      );
    },
  );

  // ── T1.isolation — tutored-profile guard ──────────────────────────────────
  group('OutboxProcessor.drain — isTutoredProfile guard (T1.isolation)', () {
    test(
      'tutored profiles are never drained — drain returns 0 immediately',
      () async {
        final tutoredProcessor = OutboxProcessor(
          outboxDao: db.outboxDao,
          pipeline: pipeline,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
          isTutoredProfile: (id) async => true, // every profile is tutored
        );

        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
        );

        final count = await tutoredProcessor.drain(profileId);
        expect(count, 0, reason: 'tutored profile must never be drained');
        expect(pipeline.calls, isEmpty);
        // Row is preserved — never deleted.
        expect(await db.outboxDao.depth(profileId), 1);
      },
    );

    test(
      'non-tutored profile is drained normally when guard returns false',
      () async {
        final normalProcessor = OutboxProcessor(
          outboxDao: db.outboxDao,
          pipeline: pipeline,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
          isTutoredProfile: (id) async => false, // not tutored
        );

        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
        );

        final count = await normalProcessor.drain(profileId);
        expect(count, 1);
        expect(pipeline.calls, [('completion', 'c1')]);
      },
    );

    test('tutored-profile guard also blocks the profile-0 sweep so '
        'tutored account-level rows are never pushed', () async {
      final tutoredProcessor = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: pipeline,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
        // Both the active profile AND profile 0 are treated as tutored.
        isTutoredProfile: (id) async => true,
      );

      // Enqueue a row under profile 0 (the SYNC-2 account-level path).
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: 0,
          entityKind: OutboxEntityKind.learnerProfile,
          entityKey: '1',
          payload: jsonEncode({'profile_id': 1}),
          createdAt: DateTime.utc(2026, 5, 14),
        ),
      );

      final count = await tutoredProcessor.drain(profileId);
      expect(count, 0);
      // Profile-0 row still in outbox.
      expect(await db.outboxDao.depth(0), 1);
    });

    test('guard is only consulted for matching profileId — other profiles '
        'are unaffected', () async {
      // Guard returns true only for profileId 99 (simulates a tutored profile
      // running alongside a normal profile).
      final mixedProcessor = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: pipeline,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
        isTutoredProfile: (id) async => id == 99,
      );

      // Normal profile (profileId=1) has a completion row.
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      final count = await mixedProcessor.drain(profileId); // profileId == 1
      expect(count, 1, reason: 'non-tutored profile still drained');
      expect(pipeline.calls, [('completion', 'c1')]);
    });
  });

  group('OutboxDao.reviveIdentityDeadLetters', () {
    Future<void> insertDead({
      required String entityKey,
      required int attempts,
      String? lastError,
    }) async {
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion(
          profileId: const Value(profileId),
          entityKind: const Value(OutboxEntityKind.profileProgram),
          entityKey: Value(entityKey),
          payload: const Value('{}'),
          createdAt: Value(DateTime.utc(2026, 5, 14)),
          attempts: Value(attempts),
          lastError: Value(lastError),
        ),
      );
    }

    test('resets ONLY dead-lettered rows that failed with an identity/'
        'permission error; leaves others untouched', () async {
      await insertDead(
        entityKey: 'permdenied',
        attempts: 10,
        lastError:
            '[cloud_firestore/permission-denied] The caller does not have '
            'permission to execute the specified operation.',
      );
      await insertDead(
        entityKey: 'unauth',
        attempts: 10,
        lastError: '[firebase_functions/unauthenticated] UNAUTHENTICATED',
      );
      // Dead-lettered but for a DIFFERENT reason — must stay dead.
      await insertDead(
        entityKey: 'badpayload',
        attempts: 10,
        lastError: 'FormatException: malformed payload',
      );
      // Identity error but NOT yet dead-lettered — left alone (still retries
      // on its own backoff schedule).
      await insertDead(
        entityKey: 'notyetdead',
        attempts: 2,
        lastError: '[cloud_firestore/permission-denied] denied',
      );

      final revived = await db.outboxDao.reviveIdentityDeadLetters(profileId);
      expect(revived, 2, reason: 'only the 2 identity-class dead-letters');

      Future<int> attemptsOf(String key) async {
        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.profileProgram,
          profileId,
          limit: 100,
        );
        return rows.firstWhere((r) => r.entityKey == key).attempts;
      }

      expect(await attemptsOf('permdenied'), 0);
      expect(await attemptsOf('unauth'), 0);
      expect(
        await attemptsOf('badpayload'),
        10,
        reason: 'non-identity stays dead',
      );
      expect(
        await attemptsOf('notyetdead'),
        2,
        reason: 'sub-threshold untouched',
      );
    });
  });

  group('OutboxProcessor.drain — isIdentityMismatched guard', () {
    test(
      'mismatched identity skips the whole drain — drain returns 0, no push, '
      'rows preserved and attempts NOT incremented',
      () async {
        final mismatchedProcessor = OutboxProcessor(
          outboxDao: db.outboxDao,
          pipeline: pipeline,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
          // Live Firebase token belongs to a different account than the active
          // one — every push would be permission-denied / unauthenticated.
          isIdentityMismatched: () => true,
        );

        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
        );
        await insertRow(
          entityKind: OutboxEntityKind.profileProgram,
          entityKey: 'mishnayos_6',
          payload: {'profile_id': 1},
        );

        final count = await mismatchedProcessor.drain(profileId);
        expect(count, 0, reason: 'identity mismatch must skip the drain');
        expect(pipeline.calls, isEmpty, reason: 'no push attempted');
        // Rows preserved AND untouched — the whole point is to not burn the
        // retry budget toward dead-lettering while the wrong account is signed
        // in. attempts must remain 0.
        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.profileProgram,
          profileId,
          limit: 10,
        );
        expect(rows.single.attempts, 0, reason: 'no retry must accrue');
      },
    );

    test('matched identity (guard false) drains normally', () async {
      final matchedProcessor = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: pipeline,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
        isIdentityMismatched: () => false,
      );

      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      final count = await matchedProcessor.drain(profileId);
      expect(count, 1);
      expect(pipeline.calls, [('completion', 'c1')]);
    });

    test(
      'guard re-evaluated each drain — resumes once identity matches',
      () async {
        var mismatched = true;
        final processor = OutboxProcessor(
          outboxDao: db.outboxDao,
          pipeline: pipeline,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
          isIdentityMismatched: () => mismatched,
        );

        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
        );

        // First drain: wrong account → skipped, row retained untouched.
        expect(await processor.drain(profileId), 0);
        expect(pipeline.calls, isEmpty);
        expect(await db.outboxDao.depth(profileId), 1);

        // User signs in as the correct account → next drain flushes the backlog.
        mismatched = false;
        expect(await processor.drain(profileId), 1);
        expect(pipeline.calls, [('completion', 'c1')]);
        expect(await db.outboxDao.depth(profileId), 0);
      },
    );
  });

  // ── Drain-while-offline behaviour ─────────────────────────────────────────
  group('OutboxProcessor.drain — drain-while-offline (network failure)', () {
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

    test('all rows are retained in the outbox when every push fails '
        '(simulating offline / network unavailable)', () async {
      // Enqueue 3 completion rows. Total failure = every key NOT committed.
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c2');
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c3');

      pipeline.failNextPush = true; // triggers Exception('network error')

      final count = await processor.drain(profileId);
      expect(count, 0, reason: 'offline drain pushes nothing');

      // All 3 rows are still in the outbox — no data is lost.
      expect(await db.outboxDao.depth(profileId), 3);
    });

    test(
      'rows that failed while offline have their attempt counter incremented '
      'and will be retried once connectivity is restored',
      () async {
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'c1',
        );

        pipeline.failNextPush = true;
        await processor.drain(profileId);

        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          profileId,
        );
        expect(rows.single.attempts, 1, reason: 'attempt counter incremented');
        expect(rows.single.lastError, isNotNull);
        expect(rows.single.lastAttemptAt, isNotNull);

        // Simulate connectivity restored: advance clock past backoff window and
        // drain again — this time the push succeeds.
        clock.advance(const Duration(seconds: 120));
        pipeline.failNextPush = false;

        final countOnline = await processor.drain(profileId);
        expect(countOnline, 1, reason: 'row successfully drained once online');
        expect(await db.outboxDao.depth(profileId), 0);
      },
    );

    test('non-completion rows are also retained when the push fails offline, '
        'and other rows in the batch continue to be attempted', () async {
      // Two streak rows — both will fail. Other rows in later kinds are
      // unaffected: failure on one row does NOT abort the whole drain.
      pipeline.hangStreak = false; // ensure no hang
      final failPipeline = _ErroringNonCompletionPipeline();
      final offlineProcessor = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: failPipeline,
        clock: clock,
      );

      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: OutboxEntityKind.streak,
          entityKey: 'sk1',
          payload: jsonEncode({'count': 1}),
          createdAt: clock.nowUtc(),
        ),
      );
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: OutboxEntityKind.streak,
          entityKey: 'sk2',
          payload: jsonEncode({'count': 2}),
          createdAt: clock.nowUtc().add(const Duration(seconds: 1)),
        ),
      );

      final count = await offlineProcessor.drain(profileId);
      expect(count, 0, reason: 'both streak pushes failed');
      expect(await db.outboxDao.depth(profileId), 2);

      // Both rows have attempts == 1 (each individually marked attempted).
      final rows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.streak,
        profileId,
      );
      for (final row in rows) {
        expect(row.attempts, 1);
        expect(row.lastError, isNotNull);
      }
    });
  });

  // ── Non-completion batch-size ceiling (_batchSize = 50) ───────────────────
  group('OutboxProcessor.drain — non-completion batch size', () {
    test('drains at most 50 non-completion rows per drain call', () async {
      // Insert 55 streak rows — only the first 50 should be drained.
      final now = DateTime.utc(2026, 5, 14);
      for (var i = 0; i < 55; i++) {
        await db.outboxDao.insertOutboxRow(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: OutboxEntityKind.streak,
            entityKey: 'sk$i',
            payload: jsonEncode({'idx': i}),
            createdAt: now.add(Duration(seconds: i)),
          ),
        );
      }

      final count = await processor.drain(profileId);
      expect(count, 50, reason: 'batch ceiling is 50 for non-completion kinds');
      expect(await db.outboxDao.depth(profileId), 5, reason: '5 rows deferred');
    });
  });

  group('OutboxProcessor.drain — malformed payload isolation '
      '(AUD-core-sync-09)', () {
    Future<void> insertRawRow({
      required String entityKind,
      required String entityKey,
      required String rawPayload,
    }) => db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: profileId,
        entityKind: entityKind,
        entityKey: entityKey,
        payload: rawPayload,
        createdAt: DateTime.utc(2026, 5, 14),
      ),
    );

    test(
      'a malformed non-JSON-object completion payload does not abort the '
      'whole drain — the sibling valid row of a different kind still pushes, '
      'and the bad row is marked attempted without blocking siblings',
      () async {
        // Non-JSON-object payload (a bare JSON null) — decodes fine via
        // jsonDecode but fails the `is Map<String, dynamic>` check.
        await insertRawRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'bad-completion',
          rawPayload: 'null',
        );
        await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 's1');

        final count = await processor.drain(profileId);

        expect(count, 1, reason: 'the valid streak row must still be pushed');
        expect(
          pipeline.calls,
          contains(('streak', 's1')),
          reason: 'sibling of a different kind is not blocked by the bad row',
        );

        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          profileId,
        );
        expect(rows, hasLength(1), reason: 'bad row is retained, not deleted');
        expect(
          rows.single.attempts,
          greaterThan(0),
          reason: 'bad row is marked attempted, not left at 0 forever',
        );
      },
    );

    test(
      'a malformed non-JSON-object non-completion payload does not abort '
      'the whole drain — a sibling valid row of the SAME kind still pushes, '
      'and the bad row is marked attempted without blocking siblings',
      () async {
        await insertRawRow(
          entityKind: OutboxEntityKind.streak,
          entityKey: 'bad-streak',
          rawPayload: 'null',
        );
        await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 'ok');

        final count = await processor.drain(profileId);

        expect(count, 1, reason: 'the valid streak row must still be pushed');
        expect(pipeline.calls, contains(('streak', 'ok')));

        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.streak,
          profileId,
        );
        expect(rows, hasLength(1), reason: 'bad row is retained, not deleted');
        expect(rows.single.entityKey, 'bad-streak');
        expect(
          rows.single.attempts,
          greaterThan(0),
          reason: 'bad row is marked attempted, not left at 0 forever',
        );
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

    // R6-13 regression: when a drain is wedged past the stale threshold, the
    // reclaim branch must reset _draining/_drainingSince so the new drain
    // establishes a fresh guard.  Before the fix, the code fell through to
    // `_draining = true` without resetting the stale `_drainingSince`, leaving
    // the state machine inconsistent.
    //
    // Scenario:
    //   1. Start a drain that hangs (simulates a stuck push).
    //   2. Advance the clock past drainStaleAfter.
    //   3. A second drain call detects the stale guard and reclaims it — it
    //      must proceed (return > 0, not 0) and push the queued row.
    //   4. After the reclaimed drain completes, a THIRD drain must also
    //      proceed (guard was properly reset, not wedged by step 3).
    test('R6-13: a drain arriving after staleAfter reclaims the guard, '
        'proceeds to push, and the next drain is not blocked', () async {
      final clock = FakeLocalDayClock(DateTime.utc(2026, 5, 31));
      useLocalDayClock(clock);
      addTearDown(resetLocalDayClock);

      // A pipeline whose batch call parks until released — lets us keep a
      // drain in-flight while advancing the clock.
      final hangingBatch = _BlockingPipeline();
      final p = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: hangingBatch,
        clock: clock,
        // pushTimeout long — we advance the clock, not real time.
        pushTimeout: const Duration(hours: 1),
        drainStaleAfter: const Duration(milliseconds: 100),
      );

      await insertRow(
        entityKind: OutboxEntityKind.completion,
        entityKey: 'hung',
      );

      // Step 1: start a drain that blocks — guard is held (_draining=true).
      final wedgedDrain = p.drain(profileId);

      // A concurrent drain within the stale window must be blocked.
      expect(
        await p.drain(profileId),
        0,
        reason: 'concurrent drain within stale window must be a no-op',
      );

      // Step 2: advance clock so the held guard looks stale.
      clock.advance(const Duration(milliseconds: 200));

      // Step 3: call drain() on a SECOND processor that shares the same db
      // + clock but uses the non-blocking pipeline.  Because the stale
      // reclaim only inspects the *same instance's* private state we also
      // need a second processor to demonstrate the pattern — the alternative
      // is testing via the same instance with a releaseable pipeline.
      //
      // We test the same-instance path:  release the hanging pipeline
      // immediately after the reclaim call so the reclaimed drain completes.
      // Insert a new row that the reclaimed drain will pick up.
      hangingBatch.release(); // unblock the wedged drain
      await wedgedDrain; // let it finish and release the guard

      // ── Second round: demonstrate stale-reclaim on a fresh processor ─────
      // Build a new processor, wedge it, then verify reclaim.
      final hangingBatch2 = _BlockingPipeline();
      final p2 = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: hangingBatch2,
        clock: clock,
        pushTimeout: const Duration(hours: 1),
        drainStaleAfter: const Duration(milliseconds: 100),
      );

      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'r1');

      // Wedge p2's guard.
      final wedgedDrain2 = p2.drain(profileId);

      // Advance past staleAfter.
      clock.advance(const Duration(milliseconds: 200));

      // p2 is now wedged.  Build a same-instance reclaim: we call p2.drain()
      // again; the stale-guard check fires and the reclaim path must NOT
      // return 0 — it must proceed.  For p2 to actually push rows, release
      // hangingBatch2 *before* calling drain so the batch call that the
      // reclaimed drain will issue completes immediately.
      hangingBatch2.release(); // first drain can now finish too
      await wedgedDrain2;

      // After guard is released naturally, third drain runs normally.
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'r2');
      final thirdCount = await p2.drain(profileId);
      expect(
        thirdCount,
        greaterThanOrEqualTo(1),
        reason: 'guard released cleanly; third drain proceeds',
      );

      // ── Direct reclaim path ──────────────────────────────────────────────
      // Use a processor backed by a pipeline that can toggle hang on/off.
      final togglePipeline = _TogglePipeline(pipeline);
      final p3 = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: togglePipeline,
        clock: clock,
        pushTimeout: const Duration(hours: 1),
        drainStaleAfter: const Duration(milliseconds: 100),
      );

      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 's1');

      // Wedge p3: hang the first drain.
      togglePipeline.hang = true;
      final wedgedDrain3 = p3.drain(profileId);

      // Advance past staleAfter.
      clock.advance(const Duration(milliseconds: 200));

      // Now allow pushes to succeed.
      togglePipeline.hang = false;

      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 's2');

      // Reclaim call on p3 itself — stale guard detected, must proceed.
      final reclaimedCount = await p3.drain(profileId);
      expect(
        reclaimedCount,
        greaterThanOrEqualTo(1),
        reason: 'reclaimed drain on same instance proceeds and pushes rows',
      );

      // The guard was reset by the reclaim, so a following drain also works.
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 's3');
      final afterReclaimCount = await p3.drain(profileId);
      expect(
        afterReclaimCount,
        greaterThanOrEqualTo(1),
        reason: 'guard is clean after reclaim; drain after reclaim proceeds',
      );

      // Unblock wedgedDrain3 to avoid leaking the future.
      togglePipeline.hang = false;
      togglePipeline.releaseHung();
      await wedgedDrain3;
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

    // AUD-core-sync-06: a generation token must stop a SUPERSEDED (stale)
    // invocation's `finally` from clearing a guard a later, still-in-flight
    // reclaiming drain currently owns. The pre-fix code cleared
    // _draining/_drainingSince unconditionally in every `finally`, so a
    // wedged drain that eventually finished WHILE the reclaiming drain was
    // still genuinely running would wrongly free the guard, letting a THIRD
    // caller start a concurrent _doDrain on top of the second.
    test(
      'AUD-core-sync-06: a stale invocation completing AFTER a reclaiming '
      'drain has already started does not clear the guard out from under '
      'the still-running reclaimer, so a third caller cannot barge in',
      () async {
        final clock = FakeLocalDayClock(DateTime.utc(2026, 6, 1));
        final blocking = _IndependentlyBlockingPipeline();
        final p = OutboxProcessor(
          outboxDao: db.outboxDao,
          pipeline: blocking,
          clock: clock,
          pushTimeout: const Duration(hours: 1),
          drainStaleAfter: const Duration(milliseconds: 100),
        );

        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'hung',
        );

        // drain1 acquires the guard and parks inside its pipeline call
        // (call #0) — the still-pending 'hung' row is what it is pushing.
        final drain1 = p.drain(profileId);
        await blocking.awaitCallStarted(0);

        // Advance the clock so drain1's held guard now looks stale.
        clock.advance(const Duration(milliseconds: 200));

        // drain2 detects the stale guard, reclaims it (new generation), and
        // starts a genuinely NEW _doDrain — 'hung' is still pending (drain1
        // hasn't deleted it yet), so drain2 re-pushes it too, blocking on
        // its OWN pipeline call (call #1). Both calls are now truly
        // concurrent — this is the real-world race the finding describes.
        final drain2 = p.drain(profileId);
        await blocking.awaitCallStarted(1);
        expect(
          blocking.callCount,
          2,
          reason: 'drain1 and drain2 are both genuinely in flight',
        );

        // Let drain1 finish WHILE drain2 is still genuinely running.
        blocking.releaseCall(0);
        expect(await drain1, 1, reason: 'drain1 pushed the row it committed');

        // A third caller, arriving the instant drain1 has returned, must be
        // gated by the guard drain2 still legitimately holds — NOT slip
        // through because drain1's finally (belatedly) cleared state it no
        // longer owned.
        await insertRow(
          entityKind: OutboxEntityKind.completion,
          entityKey: 'r3',
        );
        final drain3Result = await p.drain(profileId);
        expect(
          drain3Result,
          0,
          reason:
              'drain2 is still genuinely in flight (blocked inside its own '
              'pipeline call) — a stale finally from the superseded drain1 '
              'must not release the guard drain2 still owns',
        );
        expect(
          blocking.callCount,
          2,
          reason:
              'drain3 must not have started a third concurrent pipeline call',
        );

        // Let drain2 finish; the guard is now genuinely free.
        blocking.releaseCall(1);
        expect(await drain2, 1);

        // A drain called AFTER the guard is genuinely free must proceed
        // normally, pushing 'r3' — the guard is not permanently wedged by
        // the reclaim. The pipeline still blocks every call by design, so
        // release its call (#2) once it starts.
        final drain4 = p.drain(profileId);
        await blocking.awaitCallStarted(2);
        blocking.releaseCall(2);
        expect(
          await drain4,
          1,
          reason: 'r3 is pushed once the guard is truly free',
        );
      },
    );
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

/// [OutboxDao] wrapper that counts calls to the AUD-core-sync-17 bulk
/// methods while delegating to the real (in-memory) implementation for
/// every other operation — TQ-4: a hand-written fake/spy around the real
/// collaborator, not a full mock, so functional correctness is unaffected.
class _CountingOutboxDao extends OutboxDao {
  _CountingOutboxDao(super.db);

  int deleteRowsCalls = 0;
  int markAttemptedBulkCalls = 0;

  @override
  Future<int> deleteRows(List<int> ids) {
    deleteRowsCalls++;
    return super.deleteRows(ids);
  }

  @override
  Future<void> markAttemptedBulk(List<int> ids, {String? error}) {
    markAttemptedBulkCalls++;
    return super.markAttemptedBulk(ids, error: error);
  }
}

/// Pipeline whose `pushCompletionsBatch` calls block on INDEPENDENT gates —
/// the Nth call parks on its own [Completer], only released by an explicit
/// [releaseCall]. Lets a test hold multiple concurrent drains' pipeline
/// calls open independently — needed to reproduce true overlap between a
/// stale (wedged) drain and the reclaiming drain that supersedes it
/// (AUD-core-sync-06), which the single shared gate in [_BlockingPipeline]
/// cannot model (releasing it unblocks every call, not just one).
///
/// [awaitCallStarted] is deterministic regardless of how many internal async
/// hops precede the pipeline call (e.g. the DAO query inside `_doDrain`): it
/// polls with `Future.delayed(Duration.zero)` until the Nth call has been
/// entered, so tests never need a fixed-duration sleep to synchronize.
class _IndependentlyBlockingPipeline extends Fake implements PushPipeline {
  final List<Completer<void>> _releaseGates = [];
  final List<Completer<void>> _startedGates = [];

  /// Total number of `pushCompletionsBatch` calls entered so far.
  int get callCount => _releaseGates.length;

  /// Completes once the [index]-th call (0-based, in call order) has been
  /// entered and is now parked on its release gate.
  Future<void> awaitCallStarted(int index) async {
    while (_startedGates.length <= index) {
      await Future<void>.delayed(Duration.zero);
    }
    await _startedGates[index].future;
  }

  /// Release the [index]-th call so it can return.
  void releaseCall(int index) => _releaseGates[index].complete();

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    final releaseGate = Completer<void>();
    final startedGate = Completer<void>();
    _releaseGates.add(releaseGate);
    _startedGates.add(startedGate);
    startedGate.complete();
    await releaseGate.future;
    return entries.map((e) => e.entityKey).toList();
  }
}

/// Pipeline that always throws [Exception] for non-completion kinds.
/// Used to test drain-while-offline behaviour for non-completion rows.
class _ErroringNonCompletionPipeline extends Fake implements PushPipeline {
  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    return entries.map((e) => e.entityKey).toList();
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushStreak failed');
  }

  @override
  Future<void> pushSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushSettings failed');
  }

  @override
  Future<void> pushTrack({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushTrack failed');
  }

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushLearningOrder failed');
  }

  @override
  Future<void> pushBookmark({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushBookmark failed');
  }

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushLearnerProfile failed');
  }

  @override
  Future<void> pushStageDefinition({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushStageDefinition failed');
  }

  @override
  Future<void> pushGoal({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushGoal failed');
  }

  @override
  Future<void> deleteGoal({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: deleteGoal failed');
  }

  @override
  Future<void> deleteLearnerProfile({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: deleteLearnerProfile failed');
  }

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushGamificationSettings failed');
  }

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushNotificationSettings failed');
  }

  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushUiPreferences failed');
  }

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushProfileProgram failed');
  }

  @override
  Future<void> pushLearningLedgerEntry({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushLearningLedgerEntry failed');
  }

  @override
  Future<void> pushStudyDayConfig({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushStudyDayConfig failed');
  }

  @override
  Future<void> pushPointsLedgerEntry({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushPointsLedgerEntry failed');
  }

  @override
  Future<void> pushRewardRedemption({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('offline: pushRewardRedemption failed');
  }
}

/// Pipeline that can be toggled between hanging and passing mode.  When [hang]
/// is true, [pushCompletionsBatch] parks on a Completer; set [hang] to false
/// and call [releaseHung] to unblock a parked call.  Used by R6-13 to simulate
/// a wedged drain that can be unstuck after the stale threshold elapses.
class _TogglePipeline extends Fake implements PushPipeline {
  _TogglePipeline(this._inner);

  final PushPipeline _inner;

  /// When true the next pushCompletionsBatch call hangs.
  bool hang = false;

  Completer<void>? _parked;

  /// Unblocks any currently-parked pushCompletionsBatch call.
  void releaseHung() => _parked?.complete();

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    if (hang) {
      _parked = Completer<void>();
      await _parked!.future;
    }
    return _inner.pushCompletionsBatch(profileId: profileId, entries: entries);
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
