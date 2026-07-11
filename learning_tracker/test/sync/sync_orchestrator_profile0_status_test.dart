/// D13: the sync-status recompute must mirror `_doDrain`'s two-profile sweep
/// (active profile AND profile 0). A wedged profile-0 outbox row (e.g. the
/// bootstrap `learner_profile` push that hit permission-denied) must surface as
/// `pending`/`degraded` — NOT a false `synced`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

import '../helpers/drift_memory.dart';

class _Gw extends Fake implements FirestoreGateway {}

class _Pipeline extends Fake implements PushPipeline {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserDatabase db;
  late SyncOrchestratorImpl orchestrator;

  setUp(() {
    db = inMemoryDb();
    // Constructed once and captured by the resolver closure below — a fresh
    // OutboxProcessor per call would reset its in-memory single-flight guard
    // on every drain, unlike the production wiring (which resolves the same
    // cached provider instance on every call).
    final processor = OutboxProcessor(
      outboxDao: db.outboxDao,
      pipeline: _Pipeline(),
      clock: FakeLocalDayClock(DateTime.utc(2026, 5, 31)),
    );
    orchestrator = SyncOrchestratorImpl(
      resolveMergeRouter: () =>
          MergeRouter(mergers: const <String, EntityMerger>{}),
      resolveGateway: _Gw.new,
      resolveProfileId: () => 1,
      resolvePushAllLocalData: () async {},
      resolveOutboxProcessor: () => processor,
      resolveOutboxDao: () => db.outboxDao,
    );
  });

  tearDown(() async {
    orchestrator.dispose();
    await db.close();
  });

  Future<void> enqueueProfile0Row({int attempts = 0}) async {
    final id = await db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: 0, // bootstrap learner_profile push lives under profile 0
        entityKind: OutboxEntityKind.learnerProfile,
        entityKey: 'p0',
        payload: '{"profile_id":0}',
        createdAt: DateTime.utc(2026, 5, 31),
      ),
    );
    if (attempts > 0) {
      await db.outboxDao.markAttempted(id);
      for (var i = 1; i < attempts; i++) {
        await db.outboxDao.markAttempted(id);
      }
    }
  }

  test(
    'a pending profile-0 row surfaces as pending (not a false synced)',
    () async {
      await enqueueProfile0Row();

      await orchestrator.recordDrainAttempt();

      expect(orchestrator.currentStatus, isA<SyncStatusPending>());
      expect(
        (orchestrator.currentStatus as SyncStatusPending).pendingChanges,
        1,
      );
    },
  );

  test('a stuck profile-0 row surfaces as degraded', () async {
    await enqueueProfile0Row(attempts: 5);

    await orchestrator.recordDrainAttempt();

    expect(orchestrator.currentStatus, isA<SyncStatusDegraded>());
  });

  test('no profile-0 rows + empty active profile → not pending', () async {
    // Sanity: with nothing wedged the profile-0 sweep must not invent backlog.
    await orchestrator.recordDrainAttempt();
    expect(orchestrator.currentStatus, isNot(isA<SyncStatusPending>()));
  });
}
