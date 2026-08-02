/// Story 1.5 red-demo — AD-11's total-function honesty rule.
///
/// A listener channel that goes dead (errors, and every resubscribe attempt
/// errors again — the backoff-capped "retrying forever" resting state per
/// AD-9) while connectivity is up must surface the ambient [SyncStatus] as
/// `syncing` (in-flight/unsettled). It must NEVER read `synced` (the channel
/// is NOT actually delivering fresh data — that would be a lie) and NEVER
/// read `offline` (the network is fine; only Firestore's real-time channel is
/// stuck).
///
/// **Pre-fix status (RED):** before Story 1.5 wired
/// `ListenerSupervisor.deadChannelsChanges` into
/// `SyncOrchestratorImpl._recomputeOutboxStatus`, a dead-but-online channel
/// was invisible to the status layer entirely — the orchestrator believed
/// every channel was healthy (there was no dead-channel signal consumed at
/// all), so `currentStatus` stayed at whatever the pull path last left it
/// (typically `SyncStatus.synced` once a pull had completed, or exposed a
/// `pendingChanges`/`degraded` value from the old 7-case union depending on
/// outbox state) — silently claiming settled/healthy sync despite a
/// perpetually-dead real-time channel. This test asserts the honest
/// `syncing` state and would have failed against that pre-fix behaviour: the
/// old union had no way to express "channel dead but everything else fine"
/// other than falsely `synced`.
///
/// **Post-fix status (GREEN):** `SyncOrchestratorImpl.start()` subscribes to
/// `deadChannelsChanges` and recomputes status on every change; the dead
/// channel gates `_recomputeOutboxStatus()`'s `unsettled` boolean so the
/// status collapses to `syncing`, never `synced`/`offline`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

import '../helpers/drift_memory.dart';
import '../helpers/no_op_firestore_gateway.dart';

/// A gateway whose `completions` real-time channel is permanently broken —
/// every `listenToCollection('completions', ...)` call (the initial open AND
/// every subsequent backoff resubscribe attempt, since
/// [ListenerSource.openChannels] is re-invoked fresh each time) returns a
/// pre-errored stream. Every other channel (the other 12
/// `listenToCollection` collections, `listenToDocument` × 3,
/// `listenToTutorGrants`, `listenToLearnerProfiles`) stays healthy/empty —
/// this isolates the assertion to "one dead channel, otherwise healthy
/// fleet, connectivity up".
class _OneDeadChannelGateway extends NoOpFirestoreGateway {
  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int? limit = 500,
  }) => collection == 'completions'
      ? Stream<ListenerSnapshot>.error(
          Exception('UNAVAILABLE: completions channel down'),
        )
      : const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int? limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int? limit = 500}) =>
      const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dead-but-online channel surfaces as syncing — never a lying synced, '
      'never a falsely offline', () async {
    final db = inMemoryDb();
    await seedProfile(db);
    addTearDown(db.close);

    final orchestrator = SyncOrchestratorImpl(
      resolveMergeRouter: () => MergeRouter(mergers: const {}),
      resolveGateway: () => _OneDeadChannelGateway(),
      resolveProfileId: () => 1,
      resolvePushAllLocalData: () async {},
      // No connectivity stream override → `_lastConnectivity` stays null,
      // and `_recomputeOutboxStatus` treats null as online (the orchestrator
      // only ever exists in a cloud-born session — see its doc comment).
      // This is deliberately the "connectivity is fine" leg of the AC.
      connectivityStream: null,
      // REQUIRED: `_recomputeOutboxStatus` no-ops entirely without an
      // OutboxDao resolver — an in-memory one is wired so the recompute
      // triggered by `deadChannelsChanges` actually runs.
      resolveOutboxDao: () => db.outboxDao,
    );
    addTearDown(orchestrator.dispose);

    orchestrator.start();

    // The channel errors on the very first microtask after `start()`
    // opens it (ListenerSupervisor marks a channel dead synchronously in
    // its `onError` handler — no timer/backoff wait is needed to OBSERVE
    // the dead state, only to see a resubscribe attempt, which this test
    // does not need). One short delay lets that microtask — and the
    // `deadChannelsChanges` → `_recomputeOutboxStatus` recompute it
    // triggers — settle.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      orchestrator.currentStatus,
      isA<SyncStatusSyncing>(),
      reason:
          'a dead-but-online channel must surface as syncing (in-flight/'
          'unsettled) — the AD-11 total-function honesty rule',
    );
    // Explicitly rule out both dishonest alternatives the pre-fix code
    // could produce.
    expect(orchestrator.currentStatus, isNot(isA<SyncStatusSynced>()));
    expect(orchestrator.currentStatus, isNot(isA<SyncStatusOffline>()));

    // The union itself offers no pending/dead-letter field to fall back
    // on — this is a compile-time guarantee, not a runtime one, but is
    // restated here for readability: `SyncStatus.syncing` carries only
    // `startedAt`, never a channel count or dead-letter list.
    final syncing = orchestrator.currentStatus as SyncStatusSyncing;
    expect(syncing.startedAt, isNotNull);
  });

  test(
    'once the dead channel recovers, status can settle back to synced',
    () async {
      // Companion sanity check (not the red-demo itself): confirms the
      // `syncing` result above is genuinely driven by the dead channel, not
      // some unrelated always-syncing default — a fully healthy fleet + a
      // completed pull reaches `synced`.
      final db = inMemoryDb();
      await seedProfile(db);
      addTearDown(db.close);

      final orchestrator = SyncOrchestratorImpl(
        resolveMergeRouter: () => MergeRouter(mergers: const {}),
        resolveGateway: () => _AllHealthyGateway(),
        resolveProfileId: () => 1,
        resolvePushAllLocalData: () async {},
        connectivityStream: null,
        resolveOutboxDao: () => db.outboxDao,
      );
      addTearDown(orchestrator.dispose);

      orchestrator.start();
      await orchestrator.pullOnLaunch();
      // pullOnLaunch fires a trailing `unawaited(_recomputeOutboxStatus())`
      // after its own synced emit; let it settle before teardown closes the
      // DB out from under it.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(orchestrator.currentStatus, isA<SyncStatusSynced>());
    },
  );
}

/// Every channel healthy/empty — used only by the companion sanity test
/// above to confirm the dead-channel test's `syncing` result is genuinely
/// caused by the dead channel and not some unconditional default.
class _AllHealthyGateway extends NoOpFirestoreGateway {
  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int? limit = 500,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int? limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int? limit = 500}) =>
      const Stream.empty();

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
