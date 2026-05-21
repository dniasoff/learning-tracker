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
    await db.close();
  }
}

_Setup _buildSetup({Duration periodic = const Duration(seconds: 60)}) {
  final db = inMemoryDb();
  final pipeline = _CountingPipeline();
  final processor = OutboxProcessor(
    outboxDao: db.outboxDao,
    pipeline: pipeline,
    clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
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
    outboxProcessor: processor,
    periodicDrainInterval: periodic,
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
}
