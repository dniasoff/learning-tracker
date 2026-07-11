import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/core/sync/providers/merge_router_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/resolve_profile_id_provider.dart';
import 'package:learning_tracker/core/sync/sync_identity_status.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/data/local_data_upload_service.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';

/// Provider for [SyncOrchestrator].
///
/// Returns null when the user is not cloud-born (or gateway not yet available).
/// Callers treat null as "sync not available".
///
/// DNI-334 AC4 + DNI-335 AC6: [PullPipeline] is wired with [MergeRouter] as
/// its [MergeDispatcher]; [ListenerSupervisor] and [LifecycleObserver] are
/// started inside [SyncOrchestratorImpl.start] and disposed via
/// [ref.onDispose].
///
/// S7 (singleton invariant): this provider is a `keepAlive` singleton — at
/// most one [SyncOrchestrator] exists per app session.
///
///   * It does NOT watch [firestoreGatewayProvider] / [mergeRouterProvider]
///     etc. Invalidating any of those — as the sign-in
///     and upgrade-to-cloud flows used to do — must NOT tear down and rebuild
///     the orchestrator, since a rebuild transiently produced duplicate
///     [LifecycleObserver]s and listener sets (Bug #1, quality crisis
///     2026-05-17). Those build-time dependencies are read once via
///     [ref.read].
///   * It still watches [authStateProvider] — but only to gate on the
///     cloud-born tier. That is a genuine once-per-session transition
///     (sign-in / sign-out / upgrade), not the volatile invalidation churn
///     the singleton guarantee protects against.
///   * R1 fix: it does NOT watch the active-profile provider directly. The
///     active profile is resolved lazily via [resolveProfileIdProvider].
///   * AUD-core-sync-10 (follow-on to R1): [resolveProfileId] is not only
///     used for the orchestrator's own `resolveProfileId` parameter — it is
///     ALSO threaded into [OutboxSyncWriteFacade] / [LocalDataUploadService]
///     (constructed below) and reused as the resolver every subsequent write
///     of theirs consults. Before this fix those two collaborators took a
///     one-time `int profileId` snapshot at orchestrator-build time; since
///     the orchestrator singleton survives a profile switch without
///     rebuilding (see the bullet above), every write of the entity kinds
///     they own got permanently stamped with the STALE boot-time profile id
///     after a switch — silently orphaning that data (the outbox drain only
///     sweeps the active profile + account-level 0). The `ref.listen` below
///     also re-runs [PointsBalanceDao.reEnqueueUnsyncedLedgerRows] on every
///     switch (not just once at build) for the same reason; re-wiring
///     `syncSink` itself is unnecessary because it is the SAME `uploadFacade`
///     instance for the singleton's whole lifetime and its resolver-based
///     profile lookups are already live.
///
final syncOrchestratorProvider = Provider<SyncOrchestrator?>((ref) {
  // keepAlive: the orchestrator owns a WidgetsBinding observer and a set of
  // Firestore listeners — it must survive transient unmounts of any widget
  // that reads it, and there must be exactly one per session (S7).
  ref.keepAlive();

  // Tier gate only. Reads (not watches) the volatile build-time dependencies
  // below so that invalidating them does not rebuild the orchestrator.
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  // Gate on the gateway being available at build time, but do NOT capture it:
  // firestoreGatewayProvider watches the auth/Firestore providers and can
  // rebuild (e.g. across upgrade-to-cloud), so the orchestrator resolves it
  // lazily instead of freezing a stale handle (I5).
  final gateway = ref.read(firestoreGatewayProvider);
  if (gateway == null) return null;

  final resolveProfileId = ref.read(resolveProfileIdProvider);
  final talker = ref.read(talkerProvider);
  // W7.16: read (not watch) so Crashlytics upgrades after bootstrap don't
  // rebuild the orchestrator singleton.
  final crashlytics = ref.read(crashlyticsServiceProvider);
  // W7.8/W7.9: read (not watch) so analytics upgrades don't rebuild singleton.
  final analytics = ref.read(analyticsServiceProvider);

  // W2.32 — build LocalDataUploadService so the orchestrator can route
  // pushAllLocalData through the outbox path.
  final database = ref.read(userDatabaseProvider);
  final clock = ref.read(localDayClockProvider);
  // AUD-core-sync-10: pass the SAME live resolver used above for the
  // orchestrator's own resolveProfileId — never a captured `int` snapshot —
  // so this facade keeps tracking the active profile across switches for the
  // rest of this singleton's lifetime.
  final uploadFacade = OutboxSyncWriteFacade(
    outboxDao: database.outboxDao,
    database: database,
    resolveProfileId: resolveProfileId,
    clock: clock,
    // AUD-sync-03 (EH-3): so a swallowed drain-tee failure is observable
    // instead of vanishing into a log-less catchError.
    logger: AppLogger(talker),
  );
  // WS9 Wave-B (C#2): register the points-sync sink at the sync-orchestrator
  // composition root so every PointsBalanceDao mutation (credit on completion,
  // redemption debit/refund, parent adjust) is pushed to the outbox regardless
  // of which UI path triggered it.
  database.pointsBalanceDao.syncSink = uploadFacade;
  // D14: recover any ledger rows written before the sink was wired (recovers
  // a cloud-born account's first credit, and any crash-window gap) by
  // re-enqueuing every row still lacking a sync marker. Fire-and-forget.
  unawaited(
    database.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(resolveProfileId()),
  );
  final uploadService = LocalDataUploadService(
    facade: uploadFacade,
    database: database,
    resolveProfileId: resolveProfileId,
    logger: AppLogger(talker),
  );

  // Connectivity stream: emits true on online, false on offline. The
  // orchestrator uses this to self-heal the Firestore gRPC channel on
  // reconnect (DNS wedging mid-session is the most common cause of the
  // "Syncing…" hang — see SyncOrchestratorImpl._onConnectivityChange).
  //
  // We construct the stream with an explicit `hasConnection` seed so the
  // first emission carries the current connectivity state. Without that
  // seed the orchestrator can't tell whether a missing `previous` value
  // means "fresh start, currently online" or "fresh start, currently
  // offline" — and an app that starts offline must fire the reset on its
  // first online transition. This mirrors `connectivityStreamProvider`'s
  // logic; we don't reuse that provider directly because StreamProvider
  // doesn't expose its underlying Stream via a synchronous getter in this
  // Riverpod version.
  final connectivityChecker = ref.read(internetConnectionCheckerProvider);
  final connectivityStream = () async* {
    yield await connectivityChecker.hasConnection;
    yield* connectivityChecker.onStatusChange.map(
      (status) => status == InternetConnectionStatus.connected,
    );
  }();

  final orchestrator = SyncOrchestratorImpl(
    // Every collaborator that can itself rebuild is handed in as a lazy
    // resolver, so a later rebuild of any of these providers is picked up
    // without recreating the orchestrator (which would duplicate the
    // LifecycleObserver — Bug #1):
    //   * mergeRouterProvider    — watches userDatabaseProvider (DB swap)
    //   * firestoreGatewayProvider — watches the auth/Firestore providers
    resolveMergeRouter: () => ref.read(mergeRouterProvider),
    resolveGateway: () => ref.read(firestoreGatewayProvider)!,
    resolveProfileId: resolveProfileId,
    logger: AppLogger(talker),
    connectivityStream: connectivityStream,
    // §10.2: invalidate initialSyncCompleteProvider the first time a full pull
    // completes so the dashboard re-evaluates its readiness check immediately.
    onFirstSyncComplete: () => ref.invalidate(initialSyncCompleteProvider),
    // W2.32: outbox-backed push path replaces legacy SyncEngine delegation.
    resolvePushAllLocalData: uploadService.pushAllLocalData,
    // Plan §F Phase 5 deliverable 9 — DNI-334 goals-cutover backfill was
    // removed (pre-launch, no live users). The orchestrator parameter is
    // kept optional for back-compat with the existing constructor shape.
    // W7.16: forward listener errors to Crashlytics as non-fatal.
    crashlytics: crashlytics,
    // W7.8/W7.9: analytics for listener_error + sync_pull_* events.
    analytics: analytics,
    // Phase 0 — drain triggers and single-flight: the orchestrator owns
    // the five drain triggers (write-tee, pull-complete, connectivity
    // online, lifecycle resume, periodic safety net).
    //
    // AUD-core-sync-23: resolved lazily via ref.read, matching
    // resolveMergeRouter/resolveGateway/resolveOutboxDao, so the orchestrator
    // singleton is not rebuilt when the underlying processor changes AND a
    // later drain always uses the CURRENT processor — outboxProcessorProvider
    // itself watches userDatabaseProvider, so capturing it once at build time
    // (the pre-fix shape) could leave the orchestrator draining through a
    // processor still bound to a pre-DB-swap outboxDao while
    // resolveOutboxDao/resolveMergeRouter (already lazy) had moved on.
    resolveOutboxProcessor: () => ref.read(outboxProcessorProvider),
    // Phase 4 — outbox-driven sync-status emission + observability gauge.
    // Resolved lazily via ref.read so a DB swap (multi-account flow) is
    // picked up without rebuilding the orchestrator singleton.
    resolveOutboxDao: () => ref.read(userDatabaseProvider).outboxDao,
    // Identity guard: when the device is signed into Firebase as a different
    // account than the one active in the app, surface an actionable "sign in
    // as <email>" status instead of "rows stuck after N attempts" (the drain
    // is skipped at the processor layer so nothing actually retries).
    resolveIdentityStatus: () => ref.read(syncIdentityStatusProvider),
  );

  // Idempotent: registers the lifecycle observer + Firestore listeners once.
  orchestrator.start();

  // R1 / I3: the orchestrator must NOT ref.watch the active-profile provider
  // (a watch-dependency would rebuild the orchestrator on every profile
  // switch, duplicating the LifecycleObserver — Bug #1). Instead, listen for
  // profile changes and restart ONLY the Firestore listener set so the live
  // listeners track the active profile. ref.listen does not rebuild the
  // provider, so the singleton invariant (S7) is preserved.
  ref.listen<int>(activeProfileIdProvider, (previous, next) {
    if (previous == next) return;
    orchestrator.restartListeners();
    // AUD-core-sync-10: sweep any ledger rows for the NEWLY-active profile
    // that predate this session's syncSink wiring (D14) on every switch, not
    // just once at orchestrator build — matching the DAO's own contract
    // ("call right after wiring syncSink (cloud session start / profile
    // switch)"). `uploadFacade`/`syncSink` themselves do not need re-wiring:
    // it is the same facade instance for the singleton's whole lifetime and
    // its profile lookups are already live via [resolveProfileId].
    unawaited(database.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(next));
  });

  // SYNC-DRAIN-DELAY-01: on a device with multiple Firebase accounts, the
  // Firebase Auth SDK transiently restores the PREVIOUS account's token during
  // app launch.  The identity-mismatch guard in OutboxProcessor correctly skips
  // the drain during that window — but without this listener, rows queued while
  // the mismatch was active would be stuck until the next periodic drain fires
  // (up to 60 s).  Once the identity transitions from mismatched → matched, kick
  // the outbox processor immediately so queued writes reach Firestore within the
  // same network round as the token restoration. ref.listen does not rebuild
  // the provider so the singleton invariant (S7) is preserved.
  ref.listen<SyncIdentityStatus>(syncIdentityStatusProvider, (previous, next) {
    final wasUnmatched = previous?.isMismatch ?? false;
    if (wasUnmatched && !next.isMismatch) {
      final profileId = ref.read(activeProfileIdProvider);
      final processor = ref.read(outboxProcessorProvider);
      if (processor != null) {
        unawaited(processor.drain(profileId));
        unawaited(orchestrator.recordDrainAttempt());
      }
    }
  });

  ref.onDispose(orchestrator.dispose);

  return orchestrator;
});
