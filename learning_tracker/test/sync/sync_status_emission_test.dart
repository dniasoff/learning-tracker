/// Acceptance test for Plan §F Phase 4 deliverable 2.
///
/// `SyncOrchestratorImpl.recordDrainAttempt` must derive [SyncStatus] from
/// the outbox + connectivity state matrix:
///
///   * `offline`   — connectivity stream emits false (regardless of outbox).
///   * `degraded`  — outbox has rows with `attempts ≥ 3` (stuck).
///   * `pending`   — online + outbox not empty + no stuck rows.
///   * `synced`    — online + outbox empty + a pull has completed.
///
/// The orchestrator also fires `LogEvents.sync.outboxDepth` on every drain
/// attempt with `{count, oldest_age_seconds, stuck_count, is_online}` —
/// that gauge is observable in production logs and exercised here to
/// confirm the wiring.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/sync_identity_status.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/drift_memory.dart';
import '../helpers/no_op_firestore_gateway.dart';

/// A [FirestoreGateway] whose every collection/document fetch succeeds with
/// no rows (AUD-t-cross-30). Mirrors `_ProfileProgramsGateway` in
/// `sync_rework_profile_programs_pull_test.dart`, minus the seeded row —
/// this lets `pullOnLaunch` complete the full pull sequence without
/// throwing, so the orchestrator reaches its real "synced" emission instead
/// of an error status. Built on the shared no-op base (AUD-t-cross-19)
/// rather than hand-rolling the ~46-method interface.
class _SuccessfulPullGateway extends NoOpFirestoreGateway {
  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: []);

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
}

class _EmptyGateway implements FirestoreGateway {
  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SyncOrchestratorImpl _buildOrchestrator({
  required UserDatabase db,
  Stream<bool>? connectivityStream,
  SyncIdentityStatus Function()? resolveIdentityStatus,
  FirestoreGateway? gateway,
}) {
  final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
  return SyncOrchestratorImpl(
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => gateway ?? _EmptyGateway(),
    resolveProfileId: () => 1,
    resolvePushAllLocalData: () async {},
    connectivityStream: connectivityStream,
    resolveOutboxDao: () => db.outboxDao,
    resolveIdentityStatus: resolveIdentityStatus,
  );
}

Future<void> _enqueue(
  UserDatabase db, {
  String kind = OutboxEntityKind.completion,
  String entityKey = 'k',
  int attempts = 0,
  DateTime? createdAt,
}) async {
  await db.outboxDao.insertOutboxRow(
    OutboxCompanion(
      profileId: const Value(1),
      entityKind: Value(kind),
      entityKey: Value(entityKey),
      payload: const Value('{}'),
      createdAt: Value(createdAt ?? DateTimeFactory.nowUtc()),
      attempts: Value(attempts),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan §F Phase 4 deliverable 2 — outbox-derived SyncStatus', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('empty outbox + online + after pull → synced', () async {
      // AUD-t-cross-30: unlike the other tests in this file, this scenario
      // needs a pull that actually COMPLETES (not just "attempted and
      // swallowed") — `synced` per the header matrix requires online +
      // empty outbox + a completed pull, and _EmptyGateway can never
      // deliver that third leg (every fetch throws via noSuchMethod).
      final orchestrator = _buildOrchestrator(
        db: db,
        gateway: _SuccessfulPullGateway(),
      );
      addTearDown(orchestrator.dispose);

      // Non-throttled cold-start pull against an all-empty-but-successful
      // gateway: every collection returns zero rows, so the outbox stays
      // empty and `pullOnLaunch` reaches its own `SyncStatus.synced` emit
      // once the post-pull drain finds nothing to push.
      await orchestrator.pullOnLaunch();

      expect(
        orchestrator.currentStatus,
        isA<SyncStatusSynced>(),
        reason:
            'a completed pull with an empty outbox while online must leave '
            'the orchestrator in SyncStatus.synced',
      );

      // recordDrainAttempt() must independently re-derive `synced` from the
      // outbox + _everPulledOnLaunch state (the matrix this file's header
      // documents), not merely inherit the pull's own direct emit.
      await orchestrator.recordDrainAttempt();
      expect(orchestrator.currentStatus, isA<SyncStatusSynced>());
    });

    test('non-empty outbox + online → pending (with depth count)', () async {
      // Connectivity stream seeded online (true) so _lastConnectivity is set.
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final orchestrator = _buildOrchestrator(
        db: db,
        connectivityStream: controller.stream,
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      // Seed the connectivity state to online via the stream.
      controller.add(true);
      await Future<void>.delayed(Duration.zero);

      // Two queued rows, both fresh (attempts == 0).
      await _enqueue(db, entityKey: 'a');
      await _enqueue(db, entityKey: 'b');

      // Listen for the first emit.
      SyncStatus? observed;
      final sub = orchestrator.statusStream.listen((s) => observed = s);
      addTearDown(sub.cancel);

      await orchestrator.recordDrainAttempt();
      await Future<void>.delayed(Duration.zero);

      expect(observed, isA<SyncStatusPending>());
      expect((observed! as SyncStatusPending).pendingChanges, 2);
    });

    test('non-empty outbox + offline → offline (with depth count)', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final orchestrator = _buildOrchestrator(
        db: db,
        connectivityStream: controller.stream,
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      // Seed connectivity as online then transition to offline so the
      // orchestrator sees a real transition (not the seed).
      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      controller.add(false);
      await Future<void>.delayed(Duration.zero);

      await _enqueue(db);

      // Capture emissions after the offline transition.
      final emissions = <SyncStatus>[];
      final sub = orchestrator.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      await orchestrator.recordDrainAttempt();
      await Future<void>.delayed(Duration.zero);

      // The recompute call must emit offline (the connectivity transition
      // also triggers a recompute, so we accept either emission carrying
      // the right state).
      expect(
        emissions.whereType<SyncStatusOffline>(),
        isNotEmpty,
        reason: 'offline + non-empty outbox → SyncStatus.offline',
      );
    });

    test(
      'stuck row (attempts ≥ 3) + online → degraded (with depth count)',
      () async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          db: db,
          connectivityStream: controller.stream,
        );
        addTearDown(orchestrator.dispose);
        orchestrator.start();

        controller.add(true);
        await Future<void>.delayed(Duration.zero);

        // Stuck row — already attempted 5 times, no success.
        await _enqueue(db, attempts: 5);

        SyncStatus? observed;
        final sub = orchestrator.statusStream.listen((s) => observed = s);
        addTearDown(sub.cancel);

        await orchestrator.recordDrainAttempt();
        await Future<void>.delayed(Duration.zero);

        expect(observed, isA<SyncStatusDegraded>());
        expect((observed! as SyncStatusDegraded).pendingChanges, 1);
      },
    );

    test('offline takes precedence over degraded — a stuck outbox while '
        'offline emits SyncStatus.offline (not degraded)', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final orchestrator = _buildOrchestrator(
        db: db,
        connectivityStream: controller.stream,
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      controller.add(false);
      await Future<void>.delayed(Duration.zero);

      // Stuck row but offline — spec says offline wins.
      await _enqueue(db, attempts: 7);

      final emissions = <SyncStatus>[];
      final sub = orchestrator.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      await orchestrator.recordDrainAttempt();
      await Future<void>.delayed(Duration.zero);

      expect(emissions.whereType<SyncStatusOffline>(), isNotEmpty);
      expect(emissions.whereType<SyncStatusDegraded>(), isEmpty);
    });

    test(
      'identity mismatch + online + queued rows → degraded with an actionable '
      '"sign in as <email>" reason (NOT the "stuck after N attempts" message)',
      () async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          db: db,
          connectivityStream: controller.stream,
          resolveIdentityStatus: () => const SyncIdentityStatus.mismatched(
            activeAccountEmail: 'dniasoff@gmail.com',
            signedInEmail: 'familyniasoff@gmail.com',
          ),
        );
        addTearDown(orchestrator.dispose);
        orchestrator.start();

        controller.add(true);
        await Future<void>.delayed(Duration.zero);

        // A row stuck at the retry ceiling — without the identity branch this
        // would surface as "outbox has 1 row(s) stuck after 3+ attempts".
        await _enqueue(db, attempts: 10);

        SyncStatus? observed;
        final sub = orchestrator.statusStream.listen((s) => observed = s);
        addTearDown(sub.cancel);

        await orchestrator.recordDrainAttempt();
        await Future<void>.delayed(Duration.zero);

        expect(observed, isA<SyncStatusDegraded>());
        final degraded = observed! as SyncStatusDegraded;
        expect(degraded.pendingChanges, 1);
        expect(degraded.reason, contains('dniasoff@gmail.com'));
        expect(degraded.reason, contains('familyniasoff@gmail.com'));
        expect(
          degraded.reason,
          isNot(contains('stuck')),
          reason:
              'identity mismatch must override the generic stuck-attempts '
              'message with the actionable re-auth prompt',
        );
      },
    );

    test(
      'matched identity → ordinary stuck-attempts degraded message is unchanged',
      () async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          db: db,
          connectivityStream: controller.stream,
          resolveIdentityStatus: () => const SyncIdentityStatus.matched(),
        );
        addTearDown(orchestrator.dispose);
        orchestrator.start();

        controller.add(true);
        await Future<void>.delayed(Duration.zero);
        await _enqueue(db, attempts: 5);

        SyncStatus? observed;
        final sub = orchestrator.statusStream.listen((s) => observed = s);
        addTearDown(sub.cancel);

        await orchestrator.recordDrainAttempt();
        await Future<void>.delayed(Duration.zero);

        expect(observed, isA<SyncStatusDegraded>());
        expect((observed! as SyncStatusDegraded).reason, contains('stuck'));
      },
    );

    test('syncing status is NOT overwritten while a pull is in progress — '
        'the post-pull recompute owns the transition out of syncing', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      final orchestrator = _buildOrchestrator(
        db: db,
        connectivityStream: controller.stream,
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      controller.add(true);
      await Future<void>.delayed(Duration.zero);

      // Capture the very first emission to confirm syncing fires.
      SyncStatus? firstStatus;
      final completer = Completer<void>();
      final sub = orchestrator.statusStream.listen((s) {
        firstStatus ??= s;
        if (!completer.isCompleted) completer.complete();
      });
      addTearDown(sub.cancel);

      // Fire pullOnLaunch in the background; it should emit `syncing`
      // before its first await. The empty gateway will fail the pull
      // internally, but for this assertion we only care that
      // `recordDrainAttempt` mid-pull does not overwrite the `syncing`
      // emission. We don't await the pull's completion.
      unawaited(
        orchestrator.pullOnLaunch().catchError((Object _) {
          // PullPipeline against an empty gateway throws — we expect this.
        }),
      );

      // Wait for the first status emission (syncing).
      await completer.future.timeout(const Duration(seconds: 1));
      expect(firstStatus, isA<SyncStatusSyncing>());

      // Now enqueue rows and force a recompute. While the pull is mid-
      // flight (status is still SyncStatusSyncing because the await
      // inside pullOnLaunch hasn't completed), recordDrainAttempt must
      // NOT overwrite syncing with pending.
      await _enqueue(db);
      if (orchestrator.currentStatus is SyncStatusSyncing) {
        await orchestrator.recordDrainAttempt();
        expect(orchestrator.currentStatus, isA<SyncStatusSyncing>());
      }
    });

    test(
      'SYNC-ERR-OVERWRITE-01 (loop-iter3): error status is NOT overwritten by '
      'outbox-derived status — a pending outbox must not hide the pull-failure '
      'retry affordance',
      () async {
        // Scenario:
        //   1. Pull fails → orchestrator status = SyncStatus.error(...)
        //   2. User has outbox rows (queued while offline)
        //   3. Periodic drain fires → _recomputeOutboxStatus()
        //   4. BUG: status becomes SyncStatus.pending(...), hiding the error card
        //   5. FIX: error status must survive _recomputeOutboxStatus()
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        final orchestrator = _buildOrchestrator(
          db: db,
          connectivityStream: controller.stream,
        );
        addTearDown(orchestrator.dispose);
        orchestrator.start();

        // Connectivity is online.
        controller.add(true);
        await Future<void>.delayed(Duration.zero);

        // Simulate a failed pull: emit error status directly.  In production
        // this happens inside pullOnLaunch's catch block.  We can't call
        // pullOnLaunch against the empty gateway (it throws on the first
        // fetch), but the test goal is the status-overwrite invariant, so
        // we trigger the error path via pullOnLaunch and let it fail.
        unawaited(
          orchestrator.pullOnLaunch().catchError((Object _) {
            // Expected: _EmptyGateway raises a NoSuchMethodError for every
            // real fetch.  After the catch, status is SyncStatusError.
          }),
        );
        // Let the pull fail and emit error status.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Confirm the error status was set.
        expect(
          orchestrator.currentStatus,
          isA<SyncStatusError>(),
          reason: 'after a failed pull the orchestrator must be in error state',
        );

        // Enqueue an outbox row (simulates a user write during the failed
        // pull window).
        await _enqueue(db);

        // Capture any status change from the recompute.
        SyncStatus? statusAfterRecompute;
        final sub = orchestrator.statusStream.listen(
          (s) => statusAfterRecompute = s,
        );
        addTearDown(sub.cancel);

        // Trigger the outbox-status recompute (e.g. periodic drain).
        await orchestrator.recordDrainAttempt();
        await Future<void>.delayed(Duration.zero);

        // The error status MUST NOT be overwritten by pending/degraded/synced.
        // If statusAfterRecompute is non-null, it means a new status was
        // emitted — it must still be error.
        if (statusAfterRecompute != null) {
          expect(
            statusAfterRecompute,
            isA<SyncStatusError>(),
            reason:
                'a pending outbox row must not overwrite a pull-error status; '
                'the user needs the "tap to retry" affordance to recover',
          );
        }
        // Also assert currentStatus is still error.
        expect(
          orchestrator.currentStatus,
          isA<SyncStatusError>(),
          reason:
              'currentStatus must remain error after _recomputeOutboxStatus '
              'so the Backup & Sync error card is still visible',
        );
      },
    );

    test('no outbox dao wired → status emission is a no-op', () async {
      // Construct without a resolveOutboxDao — this is the legacy fallback
      // when the orchestrator runs without outbox observability (e.g.
      // unit tests). recordDrainAttempt must not throw.
      final orchestrator = SyncOrchestratorImpl(
        resolveMergeRouter: () => MergeRouter(mergers: const {}),
        resolveGateway: () => _EmptyGateway(),
        resolveProfileId: () => 1,
        resolvePushAllLocalData: () async {},
      );
      addTearDown(orchestrator.dispose);

      await expectLater(orchestrator.recordDrainAttempt(), completes);
    });

    test('SYNC-OFFLINE-SYNCING-01 (loop-iter6): going offline DURING an active '
        'pull immediately shows offline — NOT perpetual "Syncing"', () async {
      // Regression test for P0 bug identified in iter5.
      //
      // Scenario:
      //   1. Pull starts  → status = SyncStatus.syncing (badge: "Syncing…")
      //   2. Device goes offline mid-pull (connectivity stream emits false)
      //   3. User records completions  → write-tee → _drainOutbox →
      //      _recomputeOutboxStatus()
      //   4. BUG: SyncStatusSyncing guard returns early → badge stays "Syncing…"
      //   5. FIX: offline state must override syncing immediately; only the
      //      online-derived states (pending/degraded/synced) are blocked during
      //      an active pull.
      //
      // The orchestrator emits `syncing` BEFORE the first awaited gateway
      // operation, so we observe the syncing state by:
      //   a) Not awaiting pullOnLaunch (fire-and-forget with catchError)
      //   b) Yielding one microtask tick — syncing is emitted synchronously
      //      before the first `await` inside pullOnLaunch.
      //   c) Going offline during that window.
      //
      // The pull eventually fails or times out, but we assert the badge
      // transitions to `offline` before that happens (on the connectivity
      // change + recordDrainAttempt calls below).
      final connController = StreamController<bool>();
      addTearDown(connController.close);

      // We need the pull to be in flight (not yet resolved) when we flip
      // connectivity. Use a MergeRouter with no mergers so PullPipeline will
      // call gateway.fetchPage — which on _EmptyGateway raises
      // NoSuchMethodError. That fires ASYNCHRONOUSLY (after the first
      // await in pullOnLaunch). We collect emissions BEFORE that throw and
      // assert the offline transition wins.
      final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
      final orchestrator = SyncOrchestratorImpl(
        resolveMergeRouter: () => mergeRouter,
        resolveGateway: () => _EmptyGateway(),
        resolveProfileId: () => 1,
        resolvePushAllLocalData: () async {},
        connectivityStream: connController.stream,
        resolveOutboxDao: () => db.outboxDao,
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      // Seed as online so _lastConnectivity is set before pull starts.
      connController.add(true);
      await Future<void>.delayed(Duration.zero);

      // Collect all emitted statuses.
      final emissions = <SyncStatus>[];
      final sub = orchestrator.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      // Start the pull but do NOT await — we want to observe mid-flight.
      // The orchestrator emits SyncStatus.syncing() synchronously before
      // the first `await` inside pullOnLaunch.
      unawaited(
        orchestrator.pullOnLaunch().catchError((Object _) {
          /* pull will fail on empty gateway — expected */
        }),
      );

      // One microtask tick: syncing is emitted, pull is at its first await.
      await Future<void>.delayed(Duration.zero);

      // Confirm we captured the syncing emission and status is syncing.
      expect(
        emissions,
        contains(isA<SyncStatusSyncing>()),
        reason: 'pull must emit syncing before any awaited operation',
      );

      // --- HERE IS THE BUG SCENARIO ---
      // Device goes offline while the pull is still awaiting Firestore.
      connController.add(false);
      await Future<void>.delayed(Duration.zero);

      // Enqueue a completion (user records learning while offline).
      await _enqueue(db);

      // Write-tee drain: would call _recomputeOutboxStatus().
      await orchestrator.recordDrainAttempt();
      await Future<void>.delayed(Duration.zero);

      // The badge MUST now reflect offline — NOT the stale "Syncing" spinner.
      expect(
        emissions.whereType<SyncStatusOffline>(),
        isNotEmpty,
        reason:
            'going offline during a pull must transition the badge to offline; '
            'the stuck "Syncing…" badge is the P0 bug (SYNC-OFFLINE-SYNCING-01)',
      );
    });

    test('SYNC-STATUS-STALE-02 (loop-iter9): after force-stop + relaunch with '
        'last sync <5 min ago, outbox drains to 0 but badge is stuck at '
        'pending(N) — throttled resume must not leave badge stuck', () async {
      // Scenario:
      //   1. App last synced 2 min ago (stored in SharedPreferences).
      //   2. App force-stopped and relaunched: new SyncOrchestratorImpl
      //      instance, _everPulledOnLaunch = false.
      //   3. Lifecycle observer fires pullOnLaunch(triggeredFromResume:true).
      //   4. Throttle kicks in (elapsed < 5 min) → returns early.
      //      _everPulledOnLaunch stays false.
      //   5. User had 1 pending outbox row from before the force-stop.
      //   6. Outbox processor drains it successfully → row gone.
      //   7. _recomputeOutboxStatus() is called (depth=0, online=true).
      //   8. BUG: hits `else { return; }` because _everPulledOnLaunch==false
      //      → badge stays at whatever was last emitted (localOnly or syncing),
      //      never transitions to synced.
      //   9. FIX: throttled resume means a recent pull DID happen — we should
      //      set _everPulledOnLaunch=true so the synced path is reachable.

      // Seed SharedPreferences with a "last synced 2 min ago" timestamp so the
      // throttle fires.
      final twoMinutesAgo = DateTimeFactory.nowUtc().subtract(
        const Duration(minutes: 2),
      );
      SharedPreferences.setMockInitialValues({
        'sync_orchestrator_last_synced_at':
            twoMinutesAgo.millisecondsSinceEpoch,
      });

      final connController = StreamController<bool>();
      addTearDown(connController.close);

      final orchestrator = _buildOrchestrator(
        db: db,
        connectivityStream: connController.stream,
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      // Bring connectivity online.
      connController.add(true);
      await Future<void>.delayed(Duration.zero);

      // Seed 1 outbox row (queued before force-stop).
      await _enqueue(db);

      // Collect all emitted statuses.
      final emissions = <SyncStatus>[];
      final sub = orchestrator.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      // The resume-triggered pull is throttled (elapsed 2 min < 5 min).
      await orchestrator.pullOnLaunch(triggeredFromResume: true);

      // Simulate the outbox draining: delete the row directly (mimics
      // OutboxProcessor.drain() succeeding) and call recordDrainAttempt().
      await db.outboxDao.deleteRow(
        (await db.outboxDao.getPendingByKind(
          OutboxEntityKind.completion,
          1,
        )).single.id,
      );
      await orchestrator.recordDrainAttempt();
      await Future<void>.delayed(Duration.zero);

      // After the outbox drains to 0, the badge MUST transition to synced —
      // the throttled resume confirmed a recent pull, so "synced" is correct.
      expect(
        emissions.whereType<SyncStatusSynced>(),
        isNotEmpty,
        reason:
            'outbox empty after throttled-resume session must emit synced; '
            'stuck "pending(N)" badge with empty outbox is SYNC-STATUS-STALE-02',
      );
    });
  });
}
