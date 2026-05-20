/// Wave 2 — S7: the SyncOrchestrator singleton invariant.
///
/// S7: exactly one SyncOrchestrator instance exists per app session, and the
/// wiring it owns (the WidgetsBinding lifecycle observer + the Firestore
/// real-time listener set) is registered exactly once.
///
/// Background (Bug #1, quality crisis 2026-05-17):
///
///   `syncOrchestratorProvider` was a plain `Provider<SyncOrchestrator?>` that
///   `ref.watch`ed `syncEngineProvider`. The sign-in / upgrade-to-cloud flows
///   called `ref.invalidate(syncEngineProvider)`, which forced the orchestrator
///   to rebuild — transiently constructing a second `SyncOrchestratorImpl`
///   (with a fresh `LifecycleObserver` and `ListenerSupervisor`) before the
///   old one's `onDispose` fired. The result: two lifecycle observers on
///   `WidgetsBinding` and two open Firestore listener sets.
///
/// The Wave-2 fix has two parts, both pinned below:
///
///   1. Provider: `syncOrchestratorProvider` is now a `keepAlive` singleton
///      that does NOT `ref.watch` `syncEngineProvider`. Invalidating the sync
///      engine therefore does not rebuild the orchestrator.
///      → verified by `S7 provider — invalidating syncEngineProvider does not
///        rebuild syncOrchestratorProvider`.
///
///   2. Orchestrator: `SyncOrchestratorImpl.start()` is idempotent — the
///      lifecycle observer and the listener set are registered exactly once,
///      even if `start()` is called repeatedly.
///      → verified by the `S7 — SyncOrchestratorImpl.start()` tests, which run
///        against the real `SyncOrchestratorImpl` (the class the bug lived in).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// [FirestoreGateway] fake that counts how many real-time listener channels
/// have been opened. The S7 invariant uses this count as the observable proxy
/// for "the Firestore listener set was registered exactly once": one
/// `start()` opens 4 collection channels + 1 document channel.
class _ChannelCountingGateway implements FirestoreGateway {
  int collectionListenerCount = 0;
  int documentListenerCount = 0;

  /// Every profile id a listener channel was opened against, in order. Used by
  /// the I3 profile-switch regression test to assert the live listener set
  /// rebinds to the current profile after a restart.
  final List<int> openedProfileIds = [];

  /// Total channels opened across every `start()` call.
  int get totalChannelsOpened =>
      collectionListenerCount + documentListenerCount;

  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  }) {
    collectionListenerCount++;
    openedProfileIds.add(profileId);
    return const Stream.empty();
  }

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) {
    documentListenerCount++;
    openedProfileIds.add(profileId);
    return const Stream.empty();
  }

  // ── Unused stubs ──────────────────────────────────────────────────────────
  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: []);
  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
    String? docId,
  }) async {}
  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> items,
  }) async => const [];
  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> deleteLearnerProfile(int profileId) async {}
  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {}
  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {}
  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => [];
  @override
  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> deleteGoal({
    required int profileId,
    required String firestoreId,
  }) async {}
  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> deleteUserData(String uid) async {}
  @override
  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
}

/// Builds a real [SyncOrchestratorImpl] wired against fakes.
///
/// `start()` and `dispose()` — the methods S7 exercises — never touch the
/// `SyncEngine`, so the engine resolver throws: that doubles as an assertion
/// that the singleton lifecycle path does not depend on the engine.
SyncOrchestratorImpl _buildOrchestrator(
  _ChannelCountingGateway gateway, {
  int Function()? resolveProfileId,
}) {
  final mergeRouter = MergeRouter(mergers: const <String, EntityMerger>{});
  return SyncOrchestratorImpl(
    resolveEngine: () =>
        throw StateError('S7: start()/dispose() must not touch the engine'),
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => gateway,
    resolveProfileId: resolveProfileId ?? () => 1,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // LifecycleObserver.start() registers a WidgetsBindingObserver, so a binding
  // must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('S7 — SyncOrchestrator singleton invariant', () {
    // ── S7.1 ────────────────────────────────────────────────────────────────
    //
    // Invariant: a single SyncOrchestratorImpl registers its Firestore
    // listener set exactly once, even when start() is called repeatedly.
    //
    // Pre-fix, the listener/observer wiring ran in the constructor, so the
    // only way to avoid duplicates was to avoid constructing twice. The fix
    // moved wiring into an idempotent start(): the orchestrator can now be a
    // genuine keepAlive singleton because start() is safe to call from any
    // number of entry points.
    test(
      'S7: start() is idempotent — the listener set is opened exactly once',
      () {
        final gateway = _ChannelCountingGateway();
        final orchestrator = _buildOrchestrator(gateway);
        addTearDown(orchestrator.dispose);

        orchestrator.start();
        final channelsAfterFirstStart = gateway.totalChannelsOpened;

        expect(
          channelsAfterFirstStart,
          greaterThan(0),
          reason: 'S7: the first start() must open the Firestore listener set',
        );

        // Repeated start() calls — as could happen now that start() is invoked
        // from the provider and is safe to call defensively elsewhere.
        orchestrator
          ..start()
          ..start();

        expect(
          gateway.totalChannelsOpened,
          equals(channelsAfterFirstStart),
          reason:
              'S7: a second/third start() must be a no-op — no duplicate '
              'Firestore listener set, no duplicate lifecycle observer',
        );
      },
    );

    // ── S7.2 ────────────────────────────────────────────────────────────────
    //
    // Regression guard for Bug #1: the duplicate-listener-set scenario.
    //
    // Pre-fix this was only reachable by constructing a second orchestrator.
    // Post-fix the orchestrator is a singleton AND start() is guarded, so a
    // re-trigger of start() can never produce a second listener set.
    test(
      'S7 regression: a second start() without dispose does not double-register',
      () {
        final gateway = _ChannelCountingGateway();
        final orchestrator = _buildOrchestrator(gateway);
        addTearDown(orchestrator.dispose);

        orchestrator.start();
        final firstCount = gateway.totalChannelsOpened;

        // Bug #1 shape: a second "start" while the first is still live.
        orchestrator.start();

        expect(
          gateway.totalChannelsOpened,
          equals(firstCount),
          reason:
              'S7 regression: two live listener sets must never coexist — '
              'the second start() is suppressed by the _started guard',
        );
      },
    );

    // ── S7.3 ────────────────────────────────────────────────────────────────
    //
    // After dispose(), the orchestrator can be started again cleanly (one
    // session ends, a fresh wiring begins) — still exactly one listener set.
    test(
      'S7: dispose() then start() rewires exactly one fresh listener set',
      () {
        final gateway = _ChannelCountingGateway();
        final orchestrator = _buildOrchestrator(gateway);

        orchestrator.start();
        final perStartCount = gateway.totalChannelsOpened;
        expect(perStartCount, greaterThan(0));

        orchestrator.dispose();
        // dispose() is also idempotent.
        orchestrator.dispose();

        orchestrator.start();
        addTearDown(orchestrator.dispose);

        expect(
          gateway.totalChannelsOpened,
          equals(perStartCount * 2),
          reason:
              'S7: a post-dispose start() opens exactly one new listener set '
              '(not zero, not two)',
        );
      },
    );

    // ── I3 ──────────────────────────────────────────────────────────────────
    //
    // Regression guard for I3 / R1: the live Firestore listener set must track
    // the CURRENT profile. Pre-fix, FirestoreListenerSource captured the
    // profile id at start() (cold start → bootstrap profile 0), and the
    // orchestrator never re-opened its listeners, so a profile switch left the
    // real-time listeners pinned to the stale profile forever.
    //
    // Post-fix, FirestoreListenerSource resolves the profile id lazily and
    // SyncOrchestratorImpl.restartListeners() re-opens the listener set. The
    // provider calls restartListeners() on every profile change.
    test('I3: restartListeners() rebinds the live listener set to the current '
        'profile', () async {
      final gateway = _ChannelCountingGateway();
      // The resolver models activeProfileIdProvider: it starts on the
      // bootstrap profile (0) and flips to a real profile after a switch.
      var currentProfile = 0;
      final orchestrator = _buildOrchestrator(
        gateway,
        resolveProfileId: () => currentProfile,
      );
      addTearDown(orchestrator.dispose);

      orchestrator.start();
      expect(
        gateway.openedProfileIds.every((id) => id == 0),
        isTrue,
        reason:
            'I3: the cold-start listener set must open against the '
            'bootstrap profile that was active at start()',
      );
      final channelsPerSet = gateway.totalChannelsOpened;

      // The user picks a real profile — the provider would observe this and
      // call restartListeners().
      currentProfile = 7;
      orchestrator.restartListeners();
      // restart() is stop()-then-start(); both are async.
      await Future<void>.delayed(Duration.zero);

      expect(
        gateway.totalChannelsOpened,
        equals(channelsPerSet * 2),
        reason:
            'I3: restartListeners() must re-open exactly one fresh listener '
            'set (not zero, not a duplicate)',
      );
      expect(
        gateway.openedProfileIds.sublist(channelsPerSet),
        everyElement(equals(7)),
        reason:
            'I3: every channel opened after the profile switch must be '
            'bound to the new profile id — not the stale bootstrap profile',
      );
    });

    // ── S7.4 ────────────────────────────────────────────────────────────────
    //
    // Provider-level invariant on the REAL syncOrchestratorProvider:
    // invalidating syncEngineProvider must NOT rebuild it. This is the root
    // cause of Bug #1 — the sign-in flow called
    // ref.invalidate(syncEngineProvider), which used to tear down and
    // recreate the orchestrator (a fresh LifecycleObserver + listener set).
    //
    // The test drives the production provider in a ProviderContainer. It runs
    // on the signed-out path (authStateProvider overridden to signedOut) so
    // no Firebase is required: the production provider short-circuits at its
    // cloud-born tier gate and returns null. What is being verified is the
    // Riverpod wiring contract — keepAlive + the absence of any
    // ref.watch(syncEngineProvider) — so the provider's build closure runs
    // exactly once and an unrelated invalidation does not re-run it.
    test('S7 provider: invalidating syncEngineProvider does not rebuild '
        'syncOrchestratorProvider', () {
      var orchestratorRebuilds = 0;

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWithValue(const AuthState.signedOut()),
        ],
      );
      addTearDown(container.dispose);

      // Subscribe so the provider stays mounted; count every rebuild.
      container.listen<SyncOrchestrator?>(
        syncOrchestratorProvider,
        (_, _) => orchestratorRebuilds++,
        fireImmediately: true,
      );

      final first = container.read(syncOrchestratorProvider);
      final rebuildsAfterFirstRead = orchestratorRebuilds;

      // Invalidate the engine — the Bug #1 trigger from the sign-in flow.
      container.invalidate(syncEngineProvider);
      // Force the engine provider to rebuild so the invalidation is real.
      container.read(syncEngineProvider);

      final second = container.read(syncOrchestratorProvider);

      expect(
        identical(first, second),
        isTrue,
        reason:
            'S7: reading syncOrchestratorProvider before and after a '
            'syncEngineProvider invalidation must yield the same instance',
      );
      expect(
        orchestratorRebuilds,
        equals(rebuildsAfterFirstRead),
        reason:
            'S7: invalidating syncEngineProvider must NOT rebuild '
            'syncOrchestratorProvider — exactly one orchestrator per session',
      );
    });

    // ── S7.5 ────────────────────────────────────────────────────────────────
    //
    // Source-level guard: the production syncOrchestratorProvider must keep
    // itself alive and must NOT watch syncEngineProvider. This pins the
    // mechanism that S7.4 exercises against accidental regression.
    test('S7 provider: production source is keepAlive and does not watch the '
        'sync engine', () {
      const srcPath =
          'lib/core/sync/providers/sync_orchestrator_providers.dart';
      final source = _readSource(srcPath);

      expect(
        source,
        contains('ref.keepAlive()'),
        reason:
            'S7: syncOrchestratorProvider must call ref.keepAlive() so a '
            'transient unmount of any reader cannot dispose the singleton',
      );
      expect(
        source,
        isNot(contains('ref.watch(syncEngineProvider)')),
        reason:
            'S7: syncOrchestratorProvider must NOT ref.watch '
            'syncEngineProvider — invalidating the engine would otherwise '
            'rebuild the orchestrator (Bug #1)',
      );
      expect(
        source,
        contains('orchestrator.start()'),
        reason:
            'S7: the provider must call the idempotent start() so the '
            'lifecycle observer + listener set are registered exactly once',
      );
    });

    // ── S7.6 ────────────────────────────────────────────────────────────────
    //
    // The sign-in and upgrade-to-cloud flows must no longer invalidate
    // syncEngineProvider — that invalidation was the call that recreated the
    // orchestrator. Pinned at the source level so a future edit re-introducing
    // it fails loudly.
    test('S7 call-sites: sign-in and upgrade flows no longer invalidate '
        'syncEngineProvider', () {
      const signInPath =
          'lib/features/auth/presentation/screens/sign_in_screen.dart';
      const upgradePath =
          'lib/features/settings/presentation/screens/'
          'upgrade_to_cloud_screen.dart';

      for (final path in [signInPath, upgradePath]) {
        final source = _readSource(path);
        expect(
          source,
          isNot(contains('invalidate(syncEngineProvider)')),
          reason:
              'S7: $path must not call ref.invalidate(syncEngineProvider) — '
              'it rebuilt the SyncOrchestrator singleton. Pulls are now '
              'triggered directly via orchestrator.pullOnLaunch().',
        );
      }
    });
  });
}

/// Reads a file relative to the package root, regardless of the CWD the test
/// runner is launched from.
String _readSource(String relativePath) {
  for (final candidate in [relativePath, 'learning_tracker/$relativePath']) {
    final file = File(candidate);
    if (file.existsSync()) return file.readAsStringSync();
  }
  fail('S7: source file not found: $relativePath');
}
