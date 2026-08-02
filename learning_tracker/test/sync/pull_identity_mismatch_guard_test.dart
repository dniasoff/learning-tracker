// Identity-mismatch pull guard — pullOnLaunch must NOT attempt a Firestore pull
// when the live Firebase identity belongs to a different account than the active
// one. Every read would be PERMISSION_DENIED (rules require request.auth.uid ==
// path uid); pulling anyway would surface a misleading terminal-looking status,
// which can never resolve via retry because the identity (not the network) is
// wrong.
//
// Fix (sync_orchestrator.dart): pullOnLaunch consults resolveIdentityStatus()
// up front (mirroring the outbox drain's skip-on-mismatch) and, on mismatch,
// skips the pull — without consuming the once-per-launch guard, so a re-auth
// re-pulls.
//
// Story 1.5 / AD-11: the actionable `SyncStatus.degraded("sign in as
// <account>")` this test used to assert on no longer exists — the collapsed
// tri-state union has no distinct identity-mismatch case. The honest,
// total-function status for "connectivity is fine but there is unsettled
// work we can't push yet" is `syncing` (never falsely `synced`, never
// falsely `offline`).
//
// Test strategy:
//   * Mismatched identity → gateway.fetchPage() is NEVER called (would throw),
//     and the emitted status is `syncing` (unsettled, not a lie).
//   * Matched identity → the pull proceeds normally (gateway IS consulted).

@Tags(['unit', 'sync'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/sync_identity_status.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

/// Gateway whose pull path (`fetchPage`) throws if ever called — so a test that
/// expects the pull to be SKIPPED fails loudly if the guard regresses. Listener
/// streams are empty so `start()` initialises cleanly.
class _ExplodingPullGateway implements FirestoreGateway {
  bool fetchPageCalled = false;

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      const Stream.empty();

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    fetchPageCalled = true;
    return const FirestorePage(rows: []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SyncOrchestratorImpl _buildOrchestrator(
  FirestoreGateway gateway, {
  SyncIdentityStatus Function()? resolveIdentityStatus,
}) {
  final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
  return SyncOrchestratorImpl(
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => gateway,
    resolveProfileId: () => 1,
    resolvePushAllLocalData: () async {},
    resolveIdentityStatus: resolveIdentityStatus,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pullOnLaunch — identity-mismatch guard', () {
    test('mismatched identity → pull skipped, honest "syncing" emitted (no '
        'terminal-looking state)', () async {
      final gateway = _ExplodingPullGateway();
      final orchestrator = _buildOrchestrator(
        gateway,
        resolveIdentityStatus: () => const SyncIdentityStatus.mismatched(
          activeAccountEmail: 'family@example.com',
          signedInEmail: 'someone-else@example.com',
        ),
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      final statuses = <SyncStatus>[];
      final sub = orchestrator.statusStream.listen(statuses.add);
      await orchestrator.pullOnLaunch();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // The pull must have been skipped — the read path is never touched.
      expect(
        gateway.fetchPageCalled,
        isFalse,
        reason:
            'pullOnLaunch must NOT read from Firestore under an identity '
            'mismatch — every read would be permission-denied',
      );

      // AD-11 total-function honesty rule: connectivity is fine and there
      // is unsettled work, so the status is `syncing` — never a lie
      // (`synced`) and never `offline` (the network is fine).
      expect(statuses, isNotEmpty, reason: 'expected a status emission');
      expect(statuses.last, isA<SyncStatusSyncing>());
    });

    test('matched identity → pull proceeds (gateway is consulted)', () async {
      final gateway = _ExplodingPullGateway();
      final orchestrator = _buildOrchestrator(
        gateway,
        resolveIdentityStatus: () => const SyncIdentityStatus.matched(),
      );
      addTearDown(orchestrator.dispose);
      orchestrator.start();

      // The pull proceeds and reaches the gateway; downstream merge may throw
      // because this test wires an empty MergeRouter (no mergers) — that is
      // incidental. What matters is that the read path WAS entered (proving the
      // identity guard did not short-circuit a matched identity).
      try {
        await orchestrator.pullOnLaunch();
      } catch (_) {
        // Incidental merge error from the empty MergeRouter — irrelevant here.
      }
      await Future<void>.delayed(Duration.zero);

      expect(
        gateway.fetchPageCalled,
        isTrue,
        reason: 'with a matched identity the pull must run normally',
      );
    });
  });
}
