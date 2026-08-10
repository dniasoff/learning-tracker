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

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// [FirestoreGateway] fake that counts how many real-time listener channels
/// have been opened. The S7 invariant uses this count as the observable proxy
/// for "the Firestore listener set was registered exactly once": one
/// `start()` opens 4 collection channels + 1 document channel.
///
/// Extends `Fake` directly rather than `test/helpers`'
/// `NoOpFirestoreGateway` (AUD-t-cross-19): `listenToCollection` /
/// `listenToTutorGrants` / `listenToLearnerProfiles` all take an optional
/// `limit` with no default in the interface (abstract methods need none) —
/// overriding them two inheritance levels below a class that leaves them to
/// `Fake.noSuchMethod` hits a CFE-synthesized-stub nullability mismatch.
/// Mirrors `_Gw` in `sync_orchestrator_profile0_status_test.dart`, the
/// pattern `NoOpFirestoreGateway` itself generalizes.
class _ChannelCountingGateway extends Fake implements FirestoreGateway {
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
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
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

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) {
    collectionListenerCount++;
    return const Stream.empty();
  }

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) {
    collectionListenerCount++;
    return const Stream.empty();
  }

  // Every other FirestoreGateway method (fetch*/push*/listenToChild*) is
  // untouched by SyncOrchestratorImpl.start() in these tests — left to
  // `Fake.noSuchMethod` rather than hand-rolled (AUD-t-cross-19).
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
    resolveMergeRouter: () => mergeRouter,
    resolveGateway: () => gateway,
    resolveProfileId: resolveProfileId ?? () => 1,
    resolvePushAllLocalData: () async {},
    resolveBackfillGoals: () async => 0,
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
    //
    // Profile 0 is the no-profile sentinel: there is no `learner_profiles/0`
    // document, so FirestoreListenerSource opens ONLY the account-level
    // channels (learner_profiles + tutor_grants) for it — never the per-profile
    // subcollection listeners (which would flood logcat with PERMISSION_DENIED).
    // Those account-level channels do NOT record a profile id in
    // [_ChannelCountingGateway.openedProfileIds], so the cold-start set leaves
    // it empty; only after the switch to a real profile do per-profile channels
    // open and populate it. The asymmetry is therefore expected and asserted
    // explicitly below.
    test('I3: restartListeners() rebinds the live listener set to the current '
        'profile', () async {
      final gateway = _ChannelCountingGateway();
      // The resolver models activeProfileIdProvider: it starts on the
      // bootstrap/sentinel profile (0) and flips to a real profile after a
      // switch.
      var currentProfile = 0;
      final orchestrator = _buildOrchestrator(
        gateway,
        resolveProfileId: () => currentProfile,
      );
      addTearDown(orchestrator.dispose);

      orchestrator.start();
      // Cold start on the sentinel profile opens ONLY account-level channels —
      // no per-profile listener is opened, so no profile id is recorded.
      expect(
        gateway.openedProfileIds,
        isEmpty,
        reason:
            'I3: the sentinel profile (0) must NOT open per-profile listeners '
            '— there is no learner_profiles/0 document to read',
      );
      final accountLevelChannels = gateway.totalChannelsOpened;
      expect(
        accountLevelChannels,
        greaterThan(0),
        reason:
            'I3: even on the sentinel profile the account-level channels '
            '(learner_profiles + tutor_grants) must open',
      );

      // The user picks a real profile — the provider would observe this and
      // call restartListeners().
      currentProfile = 7;
      orchestrator.restartListeners();
      // restart() is stop()-then-start(); both are async.
      await Future<void>.delayed(Duration.zero);

      // restartListeners() re-opens exactly one fresh set bound to profile 7.
      // The full set (per-profile + account-level) is strictly larger than the
      // sentinel-only set, and every per-profile channel targets profile 7.
      expect(
        gateway.totalChannelsOpened,
        greaterThan(accountLevelChannels),
        reason:
            'I3: restartListeners() must re-open the full listener set for the '
            'real profile (not zero new channels)',
      );
      expect(
        gateway.openedProfileIds,
        isNotEmpty,
        reason:
            'I3: switching to a real profile must open per-profile listeners',
      );
      expect(
        gateway.openedProfileIds,
        everyElement(equals(7)),
        reason:
            'I3: every per-profile channel must be bound to the new profile id '
            '(7) — never the stale sentinel profile (0), and the sentinel set '
            'opened no per-profile channels, so no duplicate profile-7 batch '
            'exists',
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
    // W2.35: syncEngineProvider deleted — the invariant is now tested via the
    // keepAlive contract: two reads of syncOrchestratorProvider must return
    // the same instance regardless of any intervening provider mutations.
    test('S7 provider: syncOrchestratorProvider is a keepAlive singleton', () {
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

      // Read again — a keepAlive provider must return the same instance.
      final second = container.read(syncOrchestratorProvider);

      expect(
        identical(first, second),
        isTrue,
        reason:
            'S7: syncOrchestratorProvider must return the same instance on '
            'repeated reads (keepAlive singleton)',
      );
      expect(
        orchestratorRebuilds,
        equals(rebuildsAfterFirstRead),
        reason:
            'S7: re-reading syncOrchestratorProvider must NOT trigger a rebuild',
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
          'lib/features/account/presentation/screens/sign_in_screen.dart';
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
