/// Regression test for: after a write-tee drain failure the sync-status badge
/// must update to reflect the unsettled outbox rather than remaining at a
/// stale `Synced`.
///
/// Root cause: `OutboxSyncWriteFacade.onEnqueueDrain` called
/// `outboxProcessor.drain()` directly, bypassing the orchestrator's
/// `_drainOutbox` wrapper which calls `_recomputeOutboxStatus()` afterward.
/// As a result, a row that stayed in the outbox after a failed push was
/// invisible to the status badge until the next periodic drain (~60 s).
///
/// Fix: expose `recordDrainAttempt()` on the [SyncOrchestrator] interface and
/// chain it after every write-tee drain so the badge reflects push
/// success/failure immediately.
///
/// Story 1.5 / AD-11: the badge used to distinguish `pending` (fresh rows)
/// from `degraded` (rows stuck past an attempt threshold), each carrying a
/// `pendingChanges` count. Both collapsed into the same honest `syncing`
/// state — no app-level "N pending / N stuck" bookkeeping survives; a
/// non-empty outbox while online is simply unsettled work in flight.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

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

/// Pipeline that always throws, simulating an offline / permission-denied push.
class _FailingPipeline extends Fake implements PushPipeline {
  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    throw Exception('network error');
  }

  @override
  Future<void> pushTrack({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    throw Exception('network error: pushTrack failed');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SyncOrchestratorImpl _buildOrchestrator(
  UserDatabase db, {
  OutboxProcessor? outboxProcessor,
}) {
  return SyncOrchestratorImpl(
    resolveMergeRouter: () =>
        MergeRouter(mergers: const <String, EntityMerger>{}),
    resolveGateway: _EmptyGateway.new,
    resolveProfileId: () => 1,
    resolvePushAllLocalData: () async {},
    resolveOutboxProcessor: () => outboxProcessor,
    resolveOutboxDao: () => db.outboxDao,
    // Disable periodic drain so it doesn't interfere with assertions.
    periodicDrainInterval: const Duration(hours: 24),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserDatabase db;
  late SyncOrchestratorImpl orchestrator;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    orchestrator.dispose();
    await db.close();
  });

  test('after a failed write-tee drain, recordDrainAttempt() updates status to '
      'syncing (not a false Synced)', () async {
    // Build a processor whose push always fails (simulates network-offline
    // or permission-denied). Use a backoff of 0 so the row is immediately
    // eligible to retry.
    final failingProcessor = OutboxProcessor(
      outboxDao: db.outboxDao,
      pipeline: _FailingPipeline(),
      clock: FakeLocalDayClock(DateTime.utc(2026, 6, 10)),
    );

    orchestrator = _buildOrchestrator(db, outboxProcessor: failingProcessor);

    // Simulate a successful pull so _everPulledOnLaunch = true, which is the
    // precondition for _recomputeOutboxStatus emitting `synced` vs returning early.
    // We do this by directly driving pullOnLaunch with the empty gateway.
    await orchestrator.pullOnLaunch();

    // After a successful pull with empty outbox → status is Synced.
    expect(
      orchestrator.currentStatus,
      isA<SyncStatusSynced>(),
      reason: 'baseline: pull succeeded + outbox empty → Synced',
    );

    // ── Simulate write-tee: enqueue a row, drain fails, then call
    //    recordDrainAttempt() (as the fixed write-tee path does).
    await db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: 1,
        entityKind: OutboxEntityKind.track,
        entityKey: 'test-track-1',
        payload: '{"curriculum_id":"mishnayos"}',
        createdAt: DateTime.utc(2026, 6, 10),
      ),
    );

    // The write-tee calls drain() — push fails, row stays in outbox.
    await failingProcessor.drain(1);

    // OLD BEHAVIOUR (bug): the write-tee only calls drain() without calling
    // recordDrainAttempt(). The status stays Synced even though there is an
    // unsettled (failed) row.
    //
    // NEW BEHAVIOUR (fix): the write-tee calls recordDrainAttempt() after
    // drain(), which calls _recomputeOutboxStatus() and emits the correct
    // status. Assert that calling recordDrainAttempt() moves status to
    // syncing.
    await orchestrator.recordDrainAttempt();

    expect(
      orchestrator.currentStatus,
      isA<SyncStatusSyncing>(),
      reason:
          'after a failed write-tee drain + recordDrainAttempt(), '
          'status must be syncing (unsettled, not stale Synced)',
    );
  });

  test('after a failed write-tee drain that reaches the retry-attempt '
      'ceiling, recordDrainAttempt() still updates status to syncing '
      '(no distinct "stuck" state)', () async {
    final failingProcessor = OutboxProcessor(
      outboxDao: db.outboxDao,
      pipeline: _FailingPipeline(),
      clock: FakeLocalDayClock(DateTime.utc(2026, 6, 10)),
    );

    orchestrator = _buildOrchestrator(db, outboxProcessor: failingProcessor);
    await orchestrator.pullOnLaunch();

    // Insert a row and mark it as having failed 3 times — under the old
    // model this crossed the "stuck" attempt threshold; under the collapsed
    // tri-state model attempt count no longer changes the derived status at
    // all (Story 1.5 / AD-11: no app-level pending/stuck bookkeeping).
    final rowId = await db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: 1,
        entityKind: OutboxEntityKind.track,
        entityKey: 'stuck-track-1',
        payload: '{"curriculum_id":"mishnayos"}',
        createdAt: DateTime.utc(2026, 6, 10),
      ),
    );
    await db.outboxDao.markAttempted(rowId);
    await db.outboxDao.markAttempted(rowId);
    await db.outboxDao.markAttempted(rowId);

    // The write-tee drains (row is in backoff window after 3 attempts,
    // drain no-ops for this row). Then calls recordDrainAttempt().
    await orchestrator.recordDrainAttempt();

    expect(
      orchestrator.currentStatus,
      isA<SyncStatusSyncing>(),
      reason:
          'a still-queued row — regardless of attempt count — is unsettled '
          'work while online → syncing, not a false Synced',
    );
  });
}
