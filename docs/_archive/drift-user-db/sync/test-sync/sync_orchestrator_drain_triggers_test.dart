/// Tests for the five drain triggers wired into [SyncOrchestratorImpl]
/// (Phase 0 of the sync-architecture plan):
///
///   1. write-tee         (covered by `outbox_sync_write_facade_test.dart`)
///   2. pull-complete     (this file)
///   3. connectivity      (this file)
///   4. lifecycle resume  (this file — chains through pull-complete)
///   5. periodic          (this file)
///
/// Plus the single-flight guard inside `OutboxProcessor` (covered by
/// `outbox_processor_test.dart`).
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/sync/sync_identity_status.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Empty gateway — `fetchPage` returns no rows so `pullOnLaunch` traverses every
/// entity kind cheaply and completes; the drain triggers fire after the pull
/// success path, which is what these tests care about. `listenToCollection`
/// returns an empty stream so listener attach is cheap.
class _EmptyGateway implements FirestoreGateway {
  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: []);

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => const [];

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = FirestoreGatewayImpl.kListenerPageSize,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({
    int limit = FirestoreGatewayImpl.kListenerPageSize,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({
    int limit = FirestoreGatewayImpl.kListenerPageSize,
  }) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Counts every drain attempt the orchestrator routes through it. The actual
/// outbox state is touched via the injected DAO, but the counter lets the
/// tests assert "the trigger fired" without relying on database side-effects.
class _CountingPipeline extends Fake implements PushPipeline {
  int drainAttempts = 0;

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    drainAttempts++;
    return entries.map((e) => e.entityKey).toList();
  }
}

/// Builds a fresh orchestrator + processor pair backed by an in-memory DB.
/// The caller controls connectivity, lifecycle, and pull triggers via the
/// returned handles.
class _Setup {
  _Setup({
    required this.orchestrator,
    required this.processor,
    required this.pipeline,
    required this.connectivity,
    required this.db,
  });

  final SyncOrchestratorImpl orchestrator;
  final OutboxProcessor processor;
  final _CountingPipeline pipeline;
  final StreamController<bool> connectivity;
  final UserDatabase db;

  Future<void> close() async {
    orchestrator.dispose();
    await connectivity.close();
    // AUD-core-sync-26 (EH-4): pullOnLaunch() fires a trailing
    // `unawaited(_recomputeOutboxStatus())` follow-up query that this test
    // helper does not otherwise wait for. Before EH-4 narrowed
    // _recomputeOutboxStatus's catches, a query landing after the DB below
    // was closed threw a Drift `StateError` ("closed database") that a bare
    // `catch` silently swallowed-and-logged; now it propagates, so this
    // helper must let the dangling task settle before closing the DB out
    // from under it — otherwise every caller of `pullOnLaunch` in this file
    // would need its own manual settle-then-close dance.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await db.close();
  }
}

_Setup _buildSetup({
  Duration periodic = const Duration(seconds: 60),
  SyncIdentityStatus Function()? resolveIdentityStatus,
  bool wireOutboxDao = false,
}) {
  final db = inMemoryDb();
  final pipeline = _CountingPipeline();
  final processor = OutboxProcessor(
    outboxDao: db.outboxDao,
    pipeline: pipeline,
    clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
    isIdentityMismatched: resolveIdentityStatus == null
        ? null
        : () => resolveIdentityStatus().isMismatch,
  );
  final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
  // ignore: close_sinks — closed via [_Setup.close] in addTearDown.
  final connectivity = StreamController<bool>();
  final orchestrator = SyncOrchestratorImpl(
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => _EmptyGateway(),
    resolveProfileId: () => 1,
    resolvePushAllLocalData: () async {},
    resolveBackfillGoals: () async => 0,
    connectivityStream: connectivity.stream,
    resetFirestoreNetworkOverride: () async {},
    resolveOutboxProcessor: () => processor,
    periodicDrainInterval: periodic,
    resolveIdentityStatus: resolveIdentityStatus,
    resolveOutboxDao: wireOutboxDao ? () => db.outboxDao : null,
  );
  return _Setup(
    orchestrator: orchestrator,
    processor: processor,
    pipeline: pipeline,
    connectivity: connectivity,
    db: db,
  );
}

/// Seed one pending completion row so a drain actually has work to do (and
/// therefore lands a `pushCompletionsBatch` call on the fake pipeline).
Future<void> _seedOnePending(UserDatabase db) async {
  await db.outboxDao.insertOutboxRow(
    OutboxCompanion.insert(
      profileId: 1,
      entityKind: OutboxEntityKind.completion,
      entityKey: 'k1',
      payload: '{"ref":"Berakhot.2a"}',
      createdAt: DateTime.utc(2026, 5, 21),
    ),
  );
}

void main() {
  // `LifecycleObserver.start()` registers a [WidgetsBindingObserver].
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncOrchestrator drain triggers', () {
    test(
      'pull-complete trigger fires drain after pullOnLaunch success',
      () async {
        final setup = _buildSetup();
        addTearDown(setup.close);

        setup.orchestrator.start();
        await _seedOnePending(setup.db);

        // pullOnLaunch chains a drain after the pull success path.
        await setup.orchestrator.pullOnLaunch();

        expect(
          setup.pipeline.drainAttempts,
          greaterThanOrEqualTo(1),
          reason: 'pull-complete must chain a drain',
        );
        final remaining = await setup.db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          1,
        );
        expect(remaining, isEmpty, reason: 'the seeded row was pushed');
      },
    );

    test(
      'lifecycle resume trigger fires drain via the chained pull-complete',
      () async {
        final setup = _buildSetup();
        addTearDown(setup.close);

        setup.orchestrator.start();
        await _seedOnePending(setup.db);

        // The lifecycle observer's resume callback routes through
        // pullOnLaunch(triggeredFromResume: true). Calling it directly here
        // mirrors what the WidgetsBinding observer does — see
        // `LifecycleObserver.didChangeAppLifecycleState`.
        await setup.orchestrator.pullOnLaunch(triggeredFromResume: true);

        expect(
          setup.pipeline.drainAttempts,
          greaterThanOrEqualTo(1),
          reason: 'lifecycle resume → pull-complete → drain',
        );
      },
    );

    test('connectivity online transition fires reset and then drain', () async {
      final setup = _buildSetup();
      addTearDown(setup.close);

      setup.orchestrator.start();
      await _seedOnePending(setup.db);

      // offline → online: connectivity handler schedules a debounced
      // reset; once the timer fires (≥ 1.5 s), the drain is chained.
      setup.connectivity.add(false);
      setup.connectivity.add(true);

      await Future<void>.delayed(const Duration(milliseconds: 1700));

      expect(
        setup.pipeline.drainAttempts,
        greaterThanOrEqualTo(1),
        reason: 'connectivity online → drain',
      );
    });

    test('periodic timer drains every interval WHILE online', () async {
      final setup = _buildSetup(
        // Short interval so the test runs in ~milliseconds.
        periodic: const Duration(milliseconds: 100),
      );
      addTearDown(setup.close);

      setup.orchestrator.start();
      // Mark connectivity as online so the periodic gate opens. We feed
      // false→true to satisfy the orchestrator's "real transition" gate;
      // the debounced reset fires once but the periodic timer is what we
      // care about here.
      setup.connectivity.add(false);
      setup.connectivity.add(true);

      // Let two periodic ticks (and the connectivity-driven debounce) fire.
      await Future<void>.delayed(const Duration(milliseconds: 1900));

      await _seedOnePending(setup.db);
      // Another two ticks.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        setup.pipeline.drainAttempts,
        greaterThanOrEqualTo(1),
        reason: 'periodic timer must have drained the seeded row',
      );
      final remaining = await setup.db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        1,
      );
      expect(
        remaining,
        isEmpty,
        reason: 'periodic drain pushed the seeded row',
      );
    });

    test('periodic timer does NOT drain WHILE offline', () async {
      final setup = _buildSetup(periodic: const Duration(milliseconds: 100));
      addTearDown(setup.close);

      setup.orchestrator.start();
      // Never feed an online emission: the connectivity gate stays false,
      // so the periodic callback returns without calling drain.
      setup.connectivity.add(false);

      await _seedOnePending(setup.db);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(
        setup.pipeline.drainAttempts,
        0,
        reason: 'offline → periodic drain must be skipped',
      );
      final remaining = await setup.db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        1,
      );
      expect(remaining, hasLength(1), reason: 'row is still queued');
    });
  });

  group('SyncOrchestrator — identity dead-letter revive (once per launch)', () {
    Future<void> seedIdentityDeadLetter(UserDatabase db) async {
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion(
          profileId: const Value(1),
          entityKind: const Value(OutboxEntityKind.completion),
          entityKey: const Value('c_dead'),
          payload: const Value('{"ref":"Berakhot.2a"}'),
          createdAt: Value(DateTime.utc(2026, 5, 21)),
          attempts: const Value(10), // dead-lettered
          lastError: const Value('[cloud_firestore/permission-denied] denied'),
        ),
      );
    }

    test(
      'matched identity → a drain revives the dead-letter and pushes it',
      () async {
        final setup = _buildSetup(
          wireOutboxDao: true,
          resolveIdentityStatus: () => const SyncIdentityStatus.matched(),
        );
        addTearDown(setup.close);

        setup.orchestrator.start();
        await seedIdentityDeadLetter(setup.db);

        // pullOnLaunch chains a drain → revive runs first, resetting attempts,
        // then the drain pushes the now-eligible row.
        await setup.orchestrator.pullOnLaunch();

        final remaining = await setup.db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          1,
          limit: 10,
        );
        expect(
          remaining,
          isEmpty,
          reason:
              'revived dead-letter was retried and pushed under the '
              'matched identity',
        );
      },
    );

    test(
      'mismatched identity → dead-letter is NOT revived (guard skips drain)',
      () async {
        final setup = _buildSetup(
          wireOutboxDao: true,
          resolveIdentityStatus: () => const SyncIdentityStatus.mismatched(
            activeAccountEmail: 'dniasoff@gmail.com',
            signedInEmail: 'familyniasoff@gmail.com',
          ),
        );
        addTearDown(setup.close);

        setup.orchestrator.start();
        await seedIdentityDeadLetter(setup.db);

        await setup.orchestrator.pullOnLaunch();

        final rows = await setup.db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          1,
          limit: 10,
        );
        expect(rows, hasLength(1), reason: 'row preserved while mismatched');
        expect(
          rows.single.attempts,
          10,
          reason: 'not revived while the wrong account is signed in',
        );
      },
    );
  });

  group('SYNC-DRAIN-DELAY-01 (loop-iter8) — mismatched→matched identity '
      'transition drains immediately', () {
    // Regression test for the iter8 fix.
    //
    // On a device with multiple Firebase accounts, the Auth SDK may transiently
    // restore the previous account's token at launch (identity mismatch window).
    // The OutboxProcessor correctly skips the drain during that window to
    // avoid burning retry budget. Once the correct token is restored, the
    // provider fix (SYNC-DRAIN-DELAY-01) calls processor.drain() immediately
    // rather than waiting for the next periodic drain (up to 60 s).
    //
    // This test verifies:
    //   a) drain is skipped while identity is mismatched (no push, row intact)
    //   b) as soon as identity transitions to matched, calling drain() flushes
    //      the row within the same async step — no timer needed.

    test('mismatched identity skips drain; matched identity drains immediately '
        'in the same tick (no timer needed)', () async {
      // Use a fresh DB + processor directly (no orchestrator) so we can
      // control the identity resolver without going through a timer-driven
      // orchestrator spin-up.
      final db = inMemoryDb();
      addTearDown(db.close);

      final pipeline = _CountingPipeline();

      // Mutable identity: start as mismatched.
      var currentlyMismatched = true;

      final processor = OutboxProcessor(
        outboxDao: db.outboxDao,
        pipeline: pipeline,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
        isIdentityMismatched: () => currentlyMismatched,
        // Fast timeout so the test doesn't hang if something goes wrong.
        pushTimeout: const Duration(seconds: 5),
        drainStaleAfter: const Duration(seconds: 10),
      );

      // Seed 1 pending completion row.
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: 1,
          entityKind: OutboxEntityKind.completion,
          entityKey: 'k_drain_delay',
          payload: '{"ref":"Berakhot.2a"}',
          createdAt: DateTime.utc(2026, 5, 21),
        ),
      );

      // --- Phase 1: drain is skipped while mismatched ---
      final skippedCount = await processor.drain(1);
      expect(
        skippedCount,
        0,
        reason:
            'drain must return 0 while identity is mismatched — pushing would '
            'be denied by Firestore rules and burn the retry budget',
      );
      final rowsBefore = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        1,
      );
      expect(
        rowsBefore,
        hasLength(1),
        reason: 'row must still be queued after the skipped drain',
      );
      expect(
        pipeline.drainAttempts,
        0,
        reason: 'no push pipeline calls while mismatched',
      );

      // --- Phase 2: identity transitions to matched ---
      // Simulate what the provider's ref.listen callback does: as soon as
      // syncIdentityStatusProvider transitions mismatched→matched, it calls
      // processor.drain(profileId) immediately (SYNC-DRAIN-DELAY-01 fix).
      currentlyMismatched = false;

      // Call drain() immediately — no timer, no periodic wait.
      // This mirrors the single processor.drain(profileId) call in the
      // provider's ref.listen block that fires on mismatched→matched.
      final drained = await processor.drain(1);
      expect(
        drained,
        greaterThanOrEqualTo(1),
        reason:
            'once identity matches, drain() must push the queued row '
            'immediately without waiting for the next periodic timer',
      );

      final rowsAfter = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        1,
      );
      expect(
        rowsAfter,
        isEmpty,
        reason:
            'row must be gone after draining under the matched identity '
            '— SYNC-DRAIN-DELAY-01: drain fires in the same async step '
            'as the identity transition, not 60 s later',
      );
      expect(
        pipeline.drainAttempts,
        greaterThanOrEqualTo(1),
        reason: 'push pipeline was called after identity matched',
      );
    });
  });
}
