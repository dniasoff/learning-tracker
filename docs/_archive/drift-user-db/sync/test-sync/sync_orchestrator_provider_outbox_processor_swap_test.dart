/// Regression test for AUD-core-sync-23.
///
/// `syncOrchestratorProvider` wires the outbox processor into
/// `SyncOrchestratorImpl` via a lazy `resolveOutboxProcessor` resolver — see
/// that provider's composition root — so a `userDatabaseProvider` swap
/// (multi-account flow) is picked up by the NEXT drain without rebuilding
/// the orchestrator singleton (`authStateProvider`/R1 unchanged). Before
/// this fix, the processor was `ref.read` once at orchestrator-build time
/// and captured as a plain value: a later `userDatabaseProvider` swap would
/// leave the orchestrator draining through an `OutboxProcessor` still bound
/// to the PRE-swap database/outboxDao — a split-database state relative to
/// its already-lazy siblings (`resolveOutboxDao`/`resolveMergeRouter`, both
/// of which re-read `userDatabaseProvider` fresh on every call).
///
/// This test drives the REAL `outboxProcessorProvider` inside a
/// `ProviderContainer` — it `ref.watch`es `authStateProvider` and
/// `userDatabaseProvider` exactly as in production, and pushes through a
/// REAL `OutboxPushPipeline` + `FirestoreGatewayImpl` backed by
/// `fake_cloud_firestore` (only the Firebase SDK objects are faked — the
/// gateway/pipeline/processor code paths are the genuine production
/// classes). A `SyncOrchestratorImpl` is wired with
/// `resolveOutboxProcessor: () => container.read(outboxProcessorProvider)`
/// — the EXACT composition-root line from `syncOrchestratorProvider` — then
/// `userDatabaseProvider` is swapped mid-session (`authStateProvider` never
/// changes) and the next periodic drain must empty the NEW database's
/// pending row while a row seeded in the STALE database after the swap is
/// left untouched.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';

import '../helpers/drift_memory.dart';
import '../helpers/firestore_fake.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Empty gateway so `start()`'s listener registration has something to call
/// — the pull/listener path is not exercised by this test. Mirrors
/// `_EmptyGateway` in sync_orchestrator_drain_triggers_test.dart.
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

/// Minimal stub `AuthRepository` — `FirestoreGatewayImpl` reads only
/// `currentUser`. Mirrors `_StubAuthRepository` in sync_rework_push_test.dart.
class _StubAuthRepository implements AuthRepository {
  const _StubAuthRepository(this._uid);
  final String _uid;

  @override
  AppUser? get currentUser => AppUser(
    uid: _uid,
    email: 'test@example.com',
    displayName: 'Test User',
    emailVerified: true,
    providers: const ['password'],
  );

  @override
  Stream<AppUser?> onAuthStateChanged() => Stream.value(currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _seedPending(UserDatabase db, String sefariaRef) async {
  await db.outboxDao.insertOutboxRow(
    OutboxCompanion.insert(
      profileId: 1,
      entityKind: OutboxEntityKind.completion,
      entityKey: sefariaRef,
      payload:
          '{"profile_id":1,"sefaria_ref":"$sefariaRef","stage_id":1,'
          '"track_type":"personal","curriculum_id":"mishnayos"}',
      createdAt: DateTime.utc(2026, 7, 10),
    ),
  );
}

/// `currentUser.firebaseUid` is deliberately null: `syncIdentityStatusProvider`
/// short-circuits to `matched` in that case, so it never rebuilds
/// `authRepositoryProvider` — this test's `authRepositoryProvider` stays at
/// its (unused) real default, since the pipeline/gateway pair below is
/// injected directly rather than resolved through the provider graph.
const _cloudBornAuthState = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'parent@example.com',
    displayName: 'Parent',
  ),
  tier: Tier.cloudBorn,
);

void main() {
  // LifecycleObserver.start() registers a WidgetsBindingObserver.
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a drain triggered after a userDatabaseProvider swap (authState '
    'unchanged) operates against the NEW outboxDao, not the pre-swap one',
    () async {
      final dbA = inMemoryDb();
      final dbB = inMemoryDb();
      addTearDown(() async {
        await dbA.close();
        await dbB.close();
      });

      var activeDb = dbA;

      // Real production push path (FirestoreGatewayImpl + OutboxPushPipeline)
      // backed by an in-memory fake Firestore — only the Firebase SDK object
      // is faked, not learning_tracker's own code.
      final fakeFirestore = createFakeFirestore(authenticatedUid: 'uid_test');
      final gateway = FirestoreGatewayImpl(
        firestore: fakeFirestore,
        authRepository: const _StubAuthRepository('uid_test'),
        activeAccountUid: () => 'uid_test',
      );
      final pipeline = OutboxPushPipeline(gateway: gateway);

      // The REAL outboxProcessorProvider chain: only outboxPushPipelineProvider
      // is swapped (for the real pipeline above, sidestepping the need to also
      // wire firebaseFirestoreProvider/authRepositoryProvider into the
      // container) — authStateProvider and userDatabaseProvider are the two
      // dependencies outboxProcessorProvider itself watches, and both run
      // through this test's real overrides.
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWithValue(_cloudBornAuthState),
          outboxPushPipelineProvider.overrideWithValue(pipeline),
          userDatabaseProvider.overrideWith((ref) => activeDb),
        ],
      );
      addTearDown(container.dispose);

      final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);

      final orchestrator = SyncOrchestratorImpl(
        resolveMergeRouter: () => mergeRouter,
        resolveGateway: () => _EmptyGateway(),
        resolveProfileId: () => 1,
        resolvePushAllLocalData: () async {},
        connectivityStream: connectivity.stream,
        resetFirestoreNetworkOverride: () async {},
        // AUD-core-sync-23: the exact composition-root line under test —
        // matches syncOrchestratorProvider's
        // `resolveOutboxProcessor: () => ref.read(outboxProcessorProvider)`.
        resolveOutboxProcessor: () => container.read(outboxProcessorProvider),
        resolveOutboxDao: () => container.read(userDatabaseProvider).outboxDao,
        periodicDrainInterval: const Duration(milliseconds: 100),
      );
      addTearDown(orchestrator.dispose);

      orchestrator.start();
      // Mark connectivity as online so the periodic drain gate opens (mirrors
      // sync_orchestrator_drain_triggers_test.dart's periodic-timer tests).
      connectivity.add(false);
      connectivity.add(true);

      // Drain #1 — against dbA (the active database at orchestrator build).
      await _seedPending(dbA, 'Berakhot 1a');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        await dbA.outboxDao.getPendingByKind(OutboxEntityKind.completion, 1),
        isEmpty,
        reason: 'the periodic drain must have pushed dbA\'s pending row',
      );

      // The multi-account flow swaps the active database. authState (and
      // therefore the orchestrator singleton, per R1) does NOT change —
      // syncOrchestratorProvider is never rebuilt across this transition.
      activeDb = dbB;
      container.invalidate(userDatabaseProvider);

      // Quiesce before seeding. The periodic drain fires every 100ms, so a
      // drain started just BEFORE the swap can still be in flight here; if it
      // lands after the next line it consumes dbA's row and the final
      // assertion fails for a reason that has nothing to do with the fix under
      // test. That made this test flaky under host load (observed 2 failures
      // in 5 runs at load ~66, passing consistently when idle). Waiting a full
      // interval lets any pre-swap drain settle so the post-swap window below
      // measures only post-swap behaviour.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // Seed a row in BOTH databases: dbA's post-swap row is the one a
      // stale-captured processor (the pre-fix bug) would still drain; dbB's
      // row is the one that MUST drain if the fix works.
      await _seedPending(dbA, 'Berakhot 1b (stale-db)');
      await _seedPending(dbB, 'Shabbat 2a');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        await dbB.outboxDao.getPendingByKind(OutboxEntityKind.completion, 1),
        isEmpty,
        reason:
            'AUD-core-sync-23: the drain after the DB swap must operate '
            'against the NEW outboxDao (dbB) — a stale-captured processor '
            'would never see this row',
      );
      expect(
        await dbA.outboxDao.getPendingByKind(OutboxEntityKind.completion, 1),
        hasLength(1),
        reason:
            'the pre-swap database (dbA) must be left untouched by the '
            'post-swap drain — the resolver must not still be bound to it',
      );
    },
  );
}
