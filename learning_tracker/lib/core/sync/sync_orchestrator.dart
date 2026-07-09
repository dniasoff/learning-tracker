import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_listener_source.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/core/sync/lifecycle_observer.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart'
    show resetFirestoreNetwork;
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/sync_identity_status.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinates pull-on-launch and push operations using the new core/sync/
/// subsystem.
///
/// Replaces the equivalent methods on [SyncEngine] so call-sites can migrate
/// to this leaner interface without depending on the monolithic [SyncEngine].
///
/// Phase 3: pullOnLaunch.
/// Phase 4: pushAllLocalData.
/// Phase 5: statusStream / currentStatus — SyncStatus consumers switch here.
/// Phase 6: ListenerSupervisor + LifecycleObserver initialized here (DNI-335).
///
/// Future phases will remove the internal delegation to [SyncEngine] as
/// individual merge paths are decomposed into [PullPipeline] + [MergeRouter].
abstract class SyncOrchestrator {
  /// Replicate SyncEngine.pullOnLaunch().
  ///
  /// When [triggeredFromResume] is true, the pull is skipped when the last
  /// successful pull was within [SyncOrchestratorImpl.pullOnResumeMinInterval].
  Future<void> pullOnLaunch({bool triggeredFromResume = false});

  /// Bypass the once-per-launch guard and re-run a cold-start pull.
  ///
  /// Wired to the tap-to-retry affordance on the Backup & Sync error card so
  /// the user can recover from a stuck or failed sync without restarting the
  /// app. Implementations should reset the in-flight guard before delegating
  /// back to [pullOnLaunch].
  Future<void> retryPull();

  /// Push all locally-stored data to Firestore.
  ///
  /// Called once after a local-born account is upgraded to cloud (story 19.7)
  /// so that the user's offline learning history is immediately available in
  /// the cloud. A no-op when the user is not authenticated.
  Future<void> pushAllLocalData();

  /// The current sync status — delegates to the underlying engine.
  ///
  /// Exposed so callers that previously read [SyncEngine.currentStatus] after a
  /// pull (e.g. [DeviceRestoreService]) can switch to this interface without
  /// needing a direct [SyncEngine] reference.
  SyncStatus get currentStatus;

  /// Broadcast stream of sync-status changes — delegates to the underlying
  /// engine. Consumers subscribe here instead of holding a direct
  /// [SyncEngine] reference.
  Stream<SyncStatus> get statusStream;

  /// Tear down the account-level + per-profile Firestore real-time listener
  /// set WITHOUT disposing the orchestrator (the [LifecycleObserver] and the
  /// status stream survive).
  ///
  /// Called by the account-switch flow BEFORE it re-authenticates Firebase to
  /// the target account's identity. The device holds a single
  /// [FirebaseAuth.currentUser] slot, so once `signInWithGoogle()` flips the
  /// live uid, any still-subscribed listener bound to the PREVIOUS uid
  /// (`users/<oldUid>/learner_profiles`, the `tutor_grants` OR-queries scoped
  /// to the old uid) is re-evaluated against the new auth context and denied —
  /// flooding logcat with `PERMISSION_DENIED` for the old uid and leaving the
  /// parent's "Manage Tutors" stuck on "Pending" because the `tutor_grants`
  /// listen was killed by the denial. Stopping the set first guarantees no
  /// stale-uid listen fires across the auth flip; the orchestrator's
  /// active-profile listener re-opens the set against the new identity once the
  /// switch completes.
  Future<void> stopListeners();

  /// Re-open the Firestore real-time listener set against the current profile
  /// and uid. Paired with [stopListeners] by the account-switch flow so the
  /// listener set is deterministically rebound to the new identity once the
  /// switch completes — even when the new account's active profile id happens
  /// to collide with the previous one (per-account autoincrement ids), where
  /// the orchestrator's active-profile change listener would not fire. A no-op
  /// when [start] was never called.
  void restartListeners();

  /// Recompute and emit the outbox-derived sync-status badge.
  ///
  /// Call this after every outbox drain — including the write-tee drain
  /// triggered by [OutboxSyncWriteFacade._enqueue] — so the UI status badge
  /// reflects push success or failure immediately rather than waiting up to
  /// 60 s for the next periodic drain.
  ///
  /// A no-op when:
  ///   * no [OutboxDao] resolver was wired (local-born / legacy tests)
  ///   * the orchestrator is disposed
  ///   * a pull is actively in progress AND the device is online
  ///     ([SyncStatusSyncing] + online) — the pull owns the syncing→synced
  ///     window; [SyncStatus.offline] still wins immediately mid-pull when
  ///     the device goes offline (SYNC-OFFLINE-SYNCING-01)
  ///   * a pull error is displayed ([SyncStatusError]) — the error card must
  ///     remain visible until the user explicitly retries
  Future<void> recordDrainAttempt();
}

// ---------------------------------------------------------------------------
// Sealed pull-guard state machine (W5.8).
//
// Replaces the `_pullOnLaunchExecuted: bool` flag that encoded three semantic
// states as two boolean values, making the `neverRun` and `failed` states
// indistinguishable at a glance.
//
//   neverRun  — initial state; cold-start pull has not run yet this session
//   completed — a cold-start pull finished successfully; further non-resume
//               calls are skipped (once-per-launch guard S8)
//   failed    — the last cold-start pull threw; retry is allowed
// ---------------------------------------------------------------------------
sealed class _PullGuard {
  const _PullGuard();
}

/// Cold-start pull has not been attempted yet this session.
final class _PullNeverRun extends _PullGuard {
  const _PullNeverRun();
}

/// Cold-start pull completed successfully — guard is up; skip further calls.
final class _PullCompleted extends _PullGuard {
  const _PullCompleted();
}

/// Cold-start pull failed — guard is down; a retry is permitted.
final class _PullFailed extends _PullGuard {
  const _PullFailed();
}

// ---------------------------------------------------------------------------

/// Concrete implementation that drives [PullPipeline] + [MergeRouter] directly
/// for the 7 known entity kinds (DNI-334 AC2) and delegates to [SyncEngine]
/// for push operations and status tracking until full decomposition is done.
///
/// DNI-335 AC6: [ListenerSupervisor] and [LifecycleObserver] are initialized
/// and active — listeners start on construction and the observer is attached to
/// [WidgetsBinding] so resume-time pulls are triggered automatically.
class SyncOrchestratorImpl implements SyncOrchestrator {
  SyncOrchestratorImpl({
    required MergeRouter Function() resolveMergeRouter,
    required FirestoreGateway Function() resolveGateway,
    required int Function() resolveProfileId,
    AppLogger? logger,

    /// Optional stream of connectivity transitions (`true` = online,
    /// `false` = offline). When supplied, the orchestrator subscribes on
    /// [start] and, on every offline→online transition, triggers a
    /// Firestore network reset after a short debounce. This complements
    /// the lifecycle-observer reset (which only fires on background→
    /// foreground transitions): if Android wedges the DNS resolver mid-
    /// session (Doze maintenance, WiFi↔cell handoff with the app still
    /// foregrounded) the lifecycle observer never sees a non-resumed state,
    /// so connectivity-driven recovery is the only signal we have.
    ///
    /// **Must seed an initial value.** The transition logic looks at the
    /// previous emission to detect offline→online; without an initial
    /// seed, the first transition is misclassified as "no previous state".
    /// Wire via `connectivityStreamProvider.stream`, which seeds from
    /// `InternetConnectionChecker.hasConnection`.
    Stream<bool>? connectivityStream,

    /// Test seam: override the Firestore network reset call (used by both
    /// the lifecycle observer and the connectivity-driven path). Production
    /// callers pass `null`; the orchestrator falls through to the top-level
    /// `resetFirestoreNetwork()` from `firestore_instance_provider`.
    Future<void> Function()? resetFirestoreNetworkOverride,

    /// Called once — the first time a full pull completes successfully.
    ///
    /// Wired by [syncOrchestratorProvider] to invalidate
    /// [initialSyncCompleteProvider] so the dashboard re-evaluates its
    /// readiness check immediately after the first pull finishes.  Optional so
    /// tests that do not need the Riverpod notification can omit it.
    void Function()? onFirstSyncComplete,

    /// Outbox-backed replacement for the legacy push-all-local-data path.
    ///
    /// Routes all locally-stored data through the outbox so it is flushed to
    /// Firestore on the next outbox-processor cycle.
    required Future<void> Function() resolvePushAllLocalData,

    /// Deprecated: no-op since Plan §F Phase 5 deliverable 9 deleted
    /// `LocalDataUploadService.backfillGoalsForCloudCutover`. The parameter
    /// is kept (with a default no-op) so the construction site doesn't have
    /// to ripple-change in lockstep, but a non-null override is harmless.
    Future<int> Function()? resolveBackfillGoals,

    /// W7.16: optional Crashlytics service — when provided, listener errors
    /// are forwarded as non-fatal crashes in addition to the structured log.
    CrashlyticsService? crashlytics,

    /// W7.8/W7.9: optional analytics service — fires sync_pull_*/listener_error
    /// events for dashboards.
    AnalyticsService? analytics,

    /// Phase 0 sync-architecture-plan: outbox processor used by the five
    /// drain triggers (write-tee, pull-complete, connectivity-online,
    /// lifecycle-resume, periodic safety net). Cloud-born accounts must
    /// provide it; tests that only exercise the pull path can omit it
    /// (drain calls become no-ops).
    OutboxProcessor? outboxProcessor,

    /// Phase 0 sync-architecture-plan: interval between periodic drain
    /// attempts while the orchestrator is started AND online. Exposed for
    /// tests so they can run the periodic loop in milliseconds instead of
    /// waiting a full minute.
    Duration periodicDrainInterval = const Duration(seconds: 60),

    /// Phase 2 sync-architecture-plan: minimum time in background before the
    /// listener supervisor parks. Defaults to 60 s; configurable so tests
    /// can drive a much shorter window without sleeping.
    Duration? parkAfterBackgroundDuration,

    /// Phase 4 sync-architecture-plan: resolver for the active-profile's
    /// [OutboxDao]. Optional — when absent (e.g. local-born sessions, unit
    /// tests that don't exercise outbox status) status emission falls back
    /// to the pull-driven `syncing` / `synced` / `error` states.
    ///
    /// Resolved lazily so a DB swap (multi-account flow) is picked up
    /// without rebuilding the orchestrator. Used by [recordDrainAttempt] to
    /// compute pending/offline/degraded status and to log the
    /// `outbox_depth` observability gauge.
    OutboxDao Function()? resolveOutboxDao,

    /// Reports whether the live Firebase auth identity matches the active
    /// account. When it returns a mismatched [SyncIdentityStatus], the
    /// outbox-derived status surfaces an actionable "sign in as <email>"
    /// `degraded` state instead of the misleading "rows stuck after N
    /// attempts" — the drain itself is skipped at the [OutboxProcessor] layer
    /// so no retries accrue. Optional: when null (tests / legacy wiring) the
    /// status path behaves exactly as before.
    SyncIdentityStatus Function()? resolveIdentityStatus,
  }) : _resolveMergeRouter = resolveMergeRouter,
       _resolveGateway = resolveGateway,
       _resolveProfileId = resolveProfileId,
       _logger = logger,
       _crashlytics = crashlytics,
       _analytics = analytics,
       _onFirstSyncComplete = onFirstSyncComplete,
       _resolvePushAllLocalData = resolvePushAllLocalData,
       _resolveBackfillGoals = resolveBackfillGoals,
       _connectivityStream = connectivityStream,
       _resetFirestoreNetworkOverride = resetFirestoreNetworkOverride,
       _outboxProcessor = outboxProcessor,
       _periodicDrainInterval = periodicDrainInterval,
       _resolveOutboxDao = resolveOutboxDao,
       _resolveIdentityStatus = resolveIdentityStatus,
       parkAfterBackgroundDuration =
           parkAfterBackgroundDuration ?? const Duration(seconds: 60);

  /// Phase 2 sync-architecture-plan: how long the app must spend in
  /// `paused`/`hidden`/`detached` before the listener supervisor parks.
  final Duration parkAfterBackgroundDuration;

  /// Phase 4 sync-architecture-plan: lazy resolver for the [OutboxDao] used
  /// to compute pending / degraded / offline sync-status counts. See
  /// constructor doc.
  final OutboxDao Function()? _resolveOutboxDao;

  /// Resolves the live-vs-active identity match — see constructor doc.
  final SyncIdentityStatus Function()? _resolveIdentityStatus;

  /// Minimum attempt count before a stuck outbox row pushes the orchestrator
  /// into the [SyncStatus.degraded] state. Matches Plan §F Phase 4.
  static const int _degradedAttemptThreshold = 3;

  /// `true` once a `pull-on-launch` completes successfully at least once
  /// this session — the `synced` precondition per Plan §F Phase 4
  /// deliverable 2. Computed-status emission only flips to `synced` after
  /// this is set.
  bool _everPulledOnLaunch = false;

  /// Optional callback invoked the first time a full pull completes.  See
  /// constructor doc for [onFirstSyncComplete].
  final void Function()? _onFirstSyncComplete;

  /// Outbox-backed pushAllLocalData callback.
  final Future<void> Function() _resolvePushAllLocalData;

  /// Deprecated: no-op since the DNI-334 cutover backfill was deleted. See
  /// the constructor doc for the rationale.
  final Future<int> Function()? _resolveBackfillGoals;

  /// Resolves the current [MergeRouter] on demand.
  ///
  /// `mergeRouterProvider` watches `userDatabaseProvider`, so a DB swap
  /// rebuilds it. Resolving lazily means the orchestrator dispatches listener
  /// payloads to the live router, never a stale one (I5).
  final MergeRouter Function() _resolveMergeRouter;

  /// Resolves the current [FirestoreGateway] on demand.
  ///
  /// `firestoreGatewayProvider` watches the auth + Firestore providers, so it
  /// rebuilds across the upgrade-to-cloud transition. Resolving lazily means
  /// the orchestrator never holds a dead gateway handle (I5).
  final FirestoreGateway Function() _resolveGateway;

  final int Function() _resolveProfileId;
  final AppLogger? _logger;
  // W7.16: forwards listener errors to Crashlytics as non-fatal.
  final CrashlyticsService? _crashlytics;
  // W7.8/W7.9: analytics for listener_error + sync_pull_* events.
  final AnalyticsService? _analytics;

  int get _profileId => _resolveProfileId();

  ListenerSupervisor? _listenerSupervisor;
  LifecycleObserver? _lifecycleObserver;

  /// Optional connectivity stream injected by the provider. Subscribed in
  /// [start], cancelled in [dispose]. See constructor doc.
  final Stream<bool>? _connectivityStream;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Test seam — see constructor doc.
  final Future<void> Function()? _resetFirestoreNetworkOverride;

  /// Phase 0 — outbox processor that drains queued mutations to Firestore.
  /// Null when not cloud-born (the wired triggers all bail early in that case).
  final OutboxProcessor? _outboxProcessor;

  /// Phase 0 — cadence for the periodic drain timer. Defaults to 60 s in
  /// production; tests override to a short interval to exercise the trigger.
  final Duration _periodicDrainInterval;

  /// Phase 0 — periodic drain timer started in [start] and cancelled in
  /// [dispose]. Fires only when [_lastConnectivity] is true so a backgrounded
  /// or offline app does not burn cycles on no-op drains.
  Timer? _periodicDrainTimer;

  /// Invoke the configured Firestore network reset (override in tests, the
  /// top-level production function otherwise). Centralised so both the
  /// lifecycle and connectivity paths route through the same call.
  Future<void> _doFirestoreNetworkReset() {
    final override = _resetFirestoreNetworkOverride;
    if (override != null) return override();
    return resetFirestoreNetwork();
  }

  /// Phase 0 — drain the outbox for the active profile, logging start /
  /// completion / failure with the [trigger] tag.
  ///
  /// Trigger tags: `'pull'`, `'connectivity'`, `'lifecycle'`, `'periodic'`,
  /// `'write_tee'`. A no-op when no [OutboxProcessor] is configured (i.e.
  /// the user is not cloud-born or tests omitted the dependency). The
  /// outbox processor itself owns the single-flight guard so this method is
  /// safe to call from multiple triggers near-simultaneously.
  Future<void> _drainOutbox(String trigger) async {
    final processor = _outboxProcessor;
    if (processor == null) return;
    // One-shot per launch: give rows that dead-lettered under a since-resolved
    // condition (wrong account signed in, or Firestore rules not yet deployed)
    // one fresh attempt under the now-current identity — otherwise they remain
    // stranded forever and the Backup & Sync banner shows a permanent "stuck"
    // even after the underlying problem is fixed.
    await _maybeReviveIdentityDeadLetters();
    final profileId = _profileId;
    _logger?.info(
      event: LogEvents.sync.outboxDrainStarted,
      fields: {'trigger': trigger},
    );
    try {
      final pushed = await processor.drain(profileId);
      _logger?.info(
        event: LogEvents.sync.outboxDrainCompleted,
        fields: {'trigger': trigger, 'rows_pushed': pushed},
      );
    } catch (e, st) {
      _logger?.warning(
        event: LogEvents.sync.outboxDrainFailed,
        fields: {'trigger': trigger},
        exception: e,
        stackTrace: st,
      );
    } finally {
      // Recompute the sync-status badge after every drain so the pending count
      // reflects the now-current outbox depth. Without this, a periodic drain
      // empties the outbox but leaves the status stuck at its last value (e.g.
      // "1 change pending") until an unrelated connectivity change forces a
      // recompute. A failed push (e.g. Firestore unreachable while the
      // connectivity checker reports online) likewise resolves to a truthful
      // pending/offline state instead of a perpetual "syncing". No-op during an
      // active pull (the pull owns the syncing→synced window).
      await _recomputeOutboxStatus();
    }
  }

  /// Last observed connectivity value. We only trigger a Firestore reset on
  /// a transition into the online state — single-shot subscribers (and
  /// rapid duplicate emissions of the same value) must not loop the reset.
  bool? _lastConnectivity;

  /// Debounce timer for the connectivity-driven reset. Network state can
  /// flap (especially on WiFi↔cell handoffs); coalesce rapid transitions
  /// into a single reset by deferring the call ~1.5 s.
  Timer? _connectivityResetDebounce;
  static const Duration _connectivityResetDebounceDuration = Duration(
    milliseconds: 1500,
  );

  // W2.33 — own StatusStream + currentStatus ─────────────────────────────────

  /// Broadcast stream of [SyncStatus] changes owned by the orchestrator.
  ///
  /// Previously this delegated to [SyncEngine.statusStream]. Moving ownership
  /// here decouples status from the engine so W2.35 can delete [SyncEngine]
  /// without disrupting the status stream consumed by UI providers.
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus _currentStatus = const SyncStatus.localOnly();

  /// Guards [start] / [dispose] so the lifecycle observer and listener set are
  /// registered exactly once per session (S7). A second [start] is a no-op.
  bool _started = false;

  /// Guards [pullOnLaunch] so the cold-start pull runs at most once per app
  /// launch (S8). Resume-triggered pulls bypass this guard and are governed by
  /// the [pullOnResumeMinInterval] throttle instead.
  ///
  /// This is the once-per-launch guard that protects the REAL production
  /// pull path: every production caller of [pullOnLaunch] — the sign-in /
  /// upgrade-to-cloud screens, the lifecycle observer, and
  /// `DeviceRestoreService` — goes through this class, not through
  /// `SyncEngine.pullOnLaunch` directly.
  ///
  /// Transitions to [_PullFailed] when a non-resume pull throws so that
  /// `DeviceRestoreService.retry()` can genuinely re-pull after a failed
  /// restore (I4).  [retryPull] resets it to [_PullNeverRun] before calling
  /// [pullOnLaunch] again.
  _PullGuard _pullGuard = const _PullNeverRun();

  /// Begin lifecycle observation and open Firestore real-time listeners.
  ///
  /// Idempotent: a second [start] call without an intervening [dispose] is a
  /// no-op. The orchestrator is a per-session singleton (S7), so [start] is
  /// safe to call from multiple entry points without registering duplicate
  /// [WidgetsBinding] observers or listener subscriptions.
  ///
  /// Declared on the concrete class (not the [SyncOrchestrator] interface) so
  /// lightweight test stubs that `implements SyncOrchestrator` are unaffected;
  /// only the real provider, which constructs a [SyncOrchestratorImpl]
  /// directly, calls [start].
  void start() {
    if (_started) return;
    _started = true;

    final listenerSupervisor = ListenerSupervisor(
      // The source resolves the active profile and gateway lazily on each
      // openChannels() call, so a restart() after a profile switch (or a
      // gateway rebuild) rebinds the live listener set to the current
      // profile and gateway (I3 / I5 / R1).
      source: FirestoreListenerSource(
        resolveGateway: _resolveGateway,
        resolveProfileId: _resolveProfileId,
      ),
      onEvent: _onListenerEvent,
      onError: _onListenerError,
      // Phase 2 sync-architecture-plan: each at-limit snapshot triggers a
      // collection-scoped recovery pull (not a full re-pull of every kind).
      // The supervisor throttles to one invocation per minute per channel.
      recoveryPullTriggers: _buildRecoveryPullTriggers(),
      // Phase 2: log the first 10 snapshot sizes per session so we can
      // validate `.limit(500)` is keeping the delivered page size bounded.
      // After 10 the supervisor stops calling this callback.
      snapshotTelemetry: _onListenerSnapshot,
    );
    _listenerSupervisor = listenerSupervisor;

    final lifecycleObserver = LifecycleObserver(
      // Self-heal the Firestore gRPC channel on resume from background.
      // grpc-java sometimes pins a stale DNS answer or a half-open channel
      // across a network handoff (WiFi↔cell, VPN reconnect) — the symptom is
      // `Unable to resolve host firestore.googleapis.com` flooding the log
      // even though the device is online. disable/enable forces the SDK to
      // rebuild its channel. Cold-start resumes skip this (the observer
      // guards on having seen a non-resumed state first) so we don't tear
      // down a freshly-built channel at app launch.
      resetFirestoreNetwork: () async {
        try {
          await _doFirestoreNetworkReset();
        } catch (e, st) {
          _logger?.warning(
            event: 'firestore_network_reset_failed',
            exception: e,
            stackTrace: st,
          );
        }
      },
      redetectTimezone: () async {
        // No-op until DNI-26.24 wires timezone redetection — seam exists.
      },
      invalidateSacredCache: () async {
        // No-op until DNI-26.24 wires persisted sacred-window cache — seam exists.
      },
      triggerPull: () => pullOnLaunch(triggeredFromResume: true),
      // Phase 2 sync-architecture-plan: after 60 s in background, detach
      // every Firestore real-time listener to eliminate idle-listener Firestore
      // reads and avoid keeping the gRPC channel alive past Doze maintenance.
      // unpark fires after the resume pull-delta completes, so the local DB
      // is current before the listener stream resumes.
      parkListeners: () async {
        final supervisor = _listenerSupervisor;
        if (supervisor == null) return;
        try {
          await supervisor.park();
          _logger?.info(event: LogEvents.sync.listenersParked);
        } catch (e, st) {
          _logger?.warning(
            event: 'sync_listeners_park_failed',
            exception: e,
            stackTrace: st,
          );
        }
      },
      unparkListeners: () async {
        final supervisor = _listenerSupervisor;
        if (supervisor == null) return;
        try {
          await supervisor.unpark();
          _logger?.info(event: LogEvents.sync.listenersUnparked);
        } catch (e, st) {
          _logger?.warning(
            event: 'sync_listeners_unpark_failed',
            exception: e,
            stackTrace: st,
          );
        }
      },
      parkAfterBackgroundDuration: parkAfterBackgroundDuration,
    );
    _lifecycleObserver = lifecycleObserver;

    lifecycleObserver.start();
    listenerSupervisor.start();

    // Subscribe to connectivity transitions so we can self-heal the
    // Firestore channel mid-session (not just on background→foreground).
    // See [_connectivityStream] doc for the rationale.
    final stream = _connectivityStream;
    if (stream != null) {
      _connectivitySubscription = stream.listen(_onConnectivityChange);
    }

    // Phase 0 (trigger 5) — periodic outbox drain. Catches anything missed
    // by the four event-driven triggers (e.g. a write-tee dropped during a
    // process suspension). Gates on connectivity inside the callback so a
    // backgrounded or offline app does no work; the OutboxProcessor's
    // single-flight guard collapses races with other triggers.
    _periodicDrainTimer = Timer.periodic(_periodicDrainInterval, (_) {
      if (_lastConnectivity != true) return;
      unawaited(_drainOutbox('periodic'));
    });
  }

  /// Handler for [connectivityStream] emissions. Triggers a debounced
  /// `resetFirestoreNetwork()` on a transition into the online state.
  void _onConnectivityChange(bool isOnline) {
    final previous = _lastConnectivity;
    _lastConnectivity = isOnline;

    // Phase 4 — recompute sync-status whenever connectivity changes so
    // `offline` lights up on a real transition and `pending`/`synced`
    // returns when the user comes back. Idempotent and no-op when
    // outbox-status emission is not wired (no [resolveOutboxDao]).
    if (previous != isOnline) {
      unawaited(_recomputeOutboxStatus());
    }

    // Only act on a genuine offline→online transition.
    //   - We require `previous == false` so the seeded first emission
    //     (which carries the current connectivity state, not a change)
    //     doesn't trigger a wasted reset on a fresh online channel.
    //   - Duplicate "still online" emissions are ignored.
    //   - The provider seeds an initial value from `hasConnection`, so
    //     `previous` is non-null for the second-onward emission — the
    //     first real transition (after the seed) lights this path.
    if (!isOnline) return;
    if (previous == null || previous) return;

    _connectivityResetDebounce?.cancel();
    _connectivityResetDebounce = Timer(
      _connectivityResetDebounceDuration,
      () async {
        // The network state may have flipped back to offline during the
        // debounce window. Skip the reset if we're not currently online —
        // disable/enable on an offline channel is a no-op, but it produces
        // misleading "reset on reconnect" log lines.
        if (_lastConnectivity != true) return;
        try {
          await _doFirestoreNetworkReset();
          _logger?.info(
            event: 'firestore_network_reset_on_reconnect',
            fields: const {'trigger': 'connectivity'},
          );
          // Phase 0 (trigger 3) — drain the outbox after the channel
          // recovers. Anything queued while offline rides the freshly-reset
          // channel up to Firestore.
          await _drainOutbox('connectivity');
        } catch (e, st) {
          _logger?.warning(
            event: 'firestore_network_reset_on_reconnect_failed',
            exception: e,
            stackTrace: st,
          );
        }
      },
    );
  }

  /// Minimum time between full pull-on-launch runs when triggered from resume
  /// (foreground listeners still deliver real-time updates during this window).
  static const Duration pullOnResumeMinInterval = Duration(minutes: 5);
  static const _lastSyncKey = 'sync_orchestrator_last_synced_at';

  /// Cap each individual pull step (one entity kind). If a single Firestore
  /// fetch or merge hangs longer than this, the step throws and the whole
  /// pull surfaces as an error rather than wedging the UI on "Syncing…".
  ///
  /// Tuned for normal mobile networks (4G/LTE). On a 100-item Firestore page
  /// a healthy fetch returns in <2 s; 30 s tolerates a slow round trip plus
  /// a couple of retries inside the SDK. If users on flaky 2G/3G regularly
  /// trip the per-step timeout, raise this — the cost is a longer "Syncing…"
  /// state, not a worse error state, since the UI still flips to a tappable
  /// "tap to retry" card.
  static const Duration _perStepTimeout = Duration(seconds: 30);

  /// Hard ceiling on the whole pull-on-launch. Defence-in-depth in case the
  /// per-step timeout is bypassed (e.g. by a never-resolving Future not
  /// driven by Firestore). 90 s comfortably covers all 7 sequential steps
  /// even with one slow fetch; tune up if a real account legitimately needs
  /// longer.
  static const Duration _overallTimeout = Duration(seconds: 90);

  /// W2.33: status is now owned by the orchestrator (not the engine).
  @override
  SyncStatus get currentStatus => _currentStatus;

  /// W2.33: status stream is now owned by the orchestrator (not the engine).
  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;

  @override
  Future<void> pushAllLocalData() => _resolvePushAllLocalData();

  @override
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) async {
    // Identity guard (mirrors the outbox drain's skip-on-mismatch): when the
    // live Firebase token belongs to a DIFFERENT account than the active one,
    // every Firestore read is denied by the rules (request.auth.uid != path
    // uid). Pulling anyway throws FirestorePermissionDeniedException and emits
    // the misleading generic "Cloud backup is temporarily unavailable — tap to
    // retry" (which can NEVER succeed via retry — the identity is wrong, not the
    // network). Instead, surface the actionable "sign in as <account>" status
    // and skip the pull. The once-per-launch guard is intentionally NOT consumed
    // so a subsequent re-auth (matched identity) re-runs the pull normally.
    if (await _skipPullOnIdentityMismatch()) return;

    if (triggeredFromResume) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final ms = prefs.getInt(_lastSyncKey);
        if (ms != null) {
          final last = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
          final elapsed = DateTimeFactory.nowUtc().difference(last);
          if (elapsed < pullOnResumeMinInterval) {
            _logger?.info(
              event: 'sync_orchestrator_pull_skipped_resume_throttle',
              fields: {'elapsedSeconds': elapsed.inSeconds},
            );
            // SYNC-STATUS-STALE-02 (loop-iter9): the throttle fires because a
            // real pull completed recently — mark the session as having pulled
            // so _recomputeOutboxStatus() can reach the `synced` branch once
            // the outbox empties. Without this, the badge stays stuck at
            // "pending(N)" with an empty outbox (the else-return is hit because
            // _everPulledOnLaunch is false). Chain a drain so any rows queued
            // while the app was backgrounded are flushed immediately.
            _everPulledOnLaunch = true;
            await _drainOutbox('resume_throttled');
            return;
          }
        }
      } catch (_) {
        // Swallow SharedPreferences errors — fall through to pull.
      }
    } else if (_pullGuard is _PullCompleted) {
      // Once-per-launch guard (S8): a cold-start pull has already completed
      // successfully. Any additional non-resume call — e.g. the sign-in screen
      // and the lifecycle observer both firing on the same launch — is a no-op.
      // A failed pull transitions the guard to [_PullFailed], which allows
      // DeviceRestoreService.retry() to re-pull after a failed restore (I4).
      _logger?.info(event: 'sync_orchestrator_pull_skipped_already_executed');
      return;
    }

    if (!triggeredFromResume) {
      // Mark as completed optimistically so that concurrent non-resume callers
      // are skipped. The guard is reset to [_PullFailed] in the catch block if
      // this attempt throws.
      _pullGuard = const _PullCompleted();
    }

    _logger?.info(event: 'sync_orchestrator_pull_on_launch_start');

    // P5: announce the pull immediately so the UI exits localOnly before any
    // network or analytics work. Moving this before the analytics logEvent
    // prevents a hung analytics call from leaving the status stuck at
    // localOnly — analytics is fire-and-forget from the status perspective.
    _safeEmitStatus(SyncStatus.syncing(startedAt: DateTimeFactory.nowUtc()));

    // W7.9: fire analytics pull_started. Wrapped in a short timeout so a
    // flaky analytics service can't delay the pull itself (the status has
    // already transitioned above).
    try {
      await _analytics
          ?.logEvent(
            AnalyticsEvent.syncPullStarted,
            parameters: {'triggered_from_resume': triggeredFromResume},
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Analytics is non-critical; swallow timeout or any other error.
    }

    try {
      // Build the PullPipeline against the CURRENT gateway + MergeRouter so a
      // gateway rebuild (upgrade-to-cloud) or a router rebuild (DB swap) is
      // picked up — the orchestrator never pulls through a stale handle (I5).
      // PullPipeline is a trivial value holder, so per-pull construction is
      // cheap.
      // W7.6: pass analytics so PullPipeline fires merge_router_halt events.
      final pullPipeline = PullPipeline(
        gateway: _resolveGateway(),
        dispatcher: _resolveMergeRouter(),
        analytics: _analytics,
      );

      Future<void> step(String label, Future<void> Function() op) async {
        try {
          await op().timeout(
            _perStepTimeout,
            onTimeout: () => throw TimeoutException(
              'sync_pull_step_timeout: $label',
              _perStepTimeout,
            ),
          );
        } catch (e, stackTrace) {
          // Bug 1 resilience (defence-in-depth): a single collection's local
          // DATABASE error — most importantly a SqliteException(787) FK
          // violation while merging one row (e.g. a learner_profiles row
          // referencing a missing account) — must NEVER abort the launch pull
          // or tear down the session / active profile (which bounced the user
          // to the first-launch splash). The per-row merger try/catch is the
          // primary guard; this catches anything that still escapes a merger.
          //
          // Network / gateway / rules / timeout failures are NOT swallowed —
          // those are genuine pull failures that must surface as an error
          // status so the UI can offer a retry.
          if (_isLocalDatabaseError(e)) {
            _logger?.warning(
              event: 'sync_pull_step_db_error_nonfatal',
              fields: {'step': label},
              exception: e,
              stackTrace: stackTrace,
            );
            return;
          }
          rethrow;
        }
      }

      await Future<void>(() async {
        // Pull each entity kind through the PullPipeline → MergeRouter path.
        // The MergeRouter dispatches each page to the appropriate EntityMerger.
        await step(
          'completions',
          () => pullPipeline.pullCompletions(profileId: _profileId),
        );
        await step(
          'bookmarks',
          () => pullPipeline.pullBookmarks(profileId: _profileId),
        );
        await step(
          'settings',
          () => pullPipeline.pullSettings(profileId: _profileId),
        );
        await step(
          'tracks',
          () => pullPipeline.pullTracks(profileId: _profileId),
        );
        await step(
          'learner_profiles',
          () => pullPipeline.pullLearnerProfiles(profileId: _profileId),
        );
        await step(
          'learning_order',
          () => pullPipeline.pullLearningOrder(profileId: _profileId),
        );
        await step(
          'profile_programs',
          () => pullPipeline.pullProfilePrograms(profileId: _profileId),
        );
        // W2.29 — stage definitions pull (closes H4).
        await step(
          'stage_definitions',
          () => pullPipeline.pullStageDefinitions(profileId: _profileId),
        );
        // W2.28 — streak events pull (closes M4).
        await step(
          'streak_events',
          () => pullPipeline.pullStreak(profileId: _profileId),
        );
        // W2.27 — goals + ledger + settings pulls (closes M1).
        await step(
          'goals',
          () => pullPipeline.pullGoals(profileId: _profileId),
        );
        await step(
          'learning_ledger',
          () => pullPipeline.pullLearningLedger(profileId: _profileId),
        );
        await step(
          'notification_settings',
          () => pullPipeline.pullNotificationSettings(profileId: _profileId),
        );
        await step(
          'gamification_settings',
          () => pullPipeline.pullGamificationSettings(profileId: _profileId),
        );
        await step(
          'ui_preferences',
          () => pullPipeline.pullUiPreferences(profileId: _profileId),
        );
        // Phase 1 — study_day_configs pull (closes the study-day sync gap).
        await step(
          'study_day_configs',
          () => pullPipeline.pullStudyDayConfigs(profileId: _profileId),
        );
        // WS9 Wave-B (C#2) — points spend economy. Pull the ledger BEFORE
        // redemptions so the balance re-derivation reflects every merged delta;
        // redemption status is reconciled independently.
        await step(
          'points_ledger',
          () => pullPipeline.pullPointsLedger(profileId: _profileId),
        );
        await step(
          'reward_redemptions',
          () => pullPipeline.pullRewardRedemptions(profileId: _profileId),
        );
      }).timeout(
        _overallTimeout,
        onTimeout: () => throw TimeoutException(
          'sync_pull_overall_timeout',
          _overallTimeout,
        ),
      );

      final syncedAt = DateTimeFactory.nowUtc();

      // Record successful pull timestamp for resume-throttle.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, syncedAt.millisecondsSinceEpoch);
      } catch (_) {
        // Non-fatal: resume throttle degrades gracefully.
      }

      // Set the "initial sync complete" flag the first time a full pull
      // finishes (idempotent — only writes once; callback is only invoked on
      // the transition from unset → true).
      //
      // An offline-skip (triggeredFromResume with throttle active) never
      // reaches here — that path returns early above — so the flag is only
      // ever set after an actual Firestore pull completes.
      try {
        await markInitialSyncComplete(onComplete: _onFirstSyncComplete);
      } catch (_) {
        // Non-fatal: dashboard gate will remain in "syncing" state until
        // the next successful pull, which will retry the write.
      }

      _everPulledOnLaunch = true;
      // Phase 0 (triggers 2 + 4) — drain the outbox after every successful
      // pull. Cold-start and resume-triggered pulls both chain a drain so
      // anything queued while the pull was in flight (or, for resume, while
      // the app was backgrounded) lands in Firestore in the same network
      // round. The drain is awaited before the success status emit so the
      // UI's "Synced" state genuinely reflects an empty outbox.
      await _drainOutbox('pull');
      _safeEmitStatus(SyncStatus.synced(lastSyncedAt: syncedAt));
      _logger?.info(event: 'sync_orchestrator_pull_on_launch_complete');
      // After a successful pull, reflect any outbox backlog that arrived
      // mid-pull (or was queued before the cloud session became authenticated).
      unawaited(_recomputeOutboxStatus());
      // W7.9: fire analytics pull_completed at the exit boundary.
      await _analytics?.logEvent(
        AnalyticsEvent.syncPullCompleted,
        parameters: {'triggered_from_resume': triggeredFromResume},
      );

      // Plan §F Phase 5 deliverable 9 — the DNI-334 goals-cutover backfill
      // was deleted (we're pre-launch, no live users, the SharedPrefs flag
      // was never set in production). The callback is kept on the
      // constructor for back-compat but is now optional; if a host still
      // wires one we run it best-effort.
      final backfill = _resolveBackfillGoals;
      if (backfill != null) {
        try {
          await backfill();
        } catch (e, stackTrace) {
          _logger?.warning(
            event: 'sync_goal_backfill_failed',
            exception: e,
            stackTrace: stackTrace,
          );
        }
      }
    } catch (e, stackTrace) {
      // Reset the pull guard so DeviceRestoreService.retry() (or any other
      // external retry) can re-run a cold-start pull after a failed attempt
      // (I4 / S8). Transitions to [_PullFailed] (not [_PullNeverRun]) so the
      // code path is distinguishable in telemetry / tests.
      if (!triggeredFromResume) _pullGuard = const _PullFailed();
      _logger?.error(
        event: 'sync_orchestrator_pull_on_launch_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      // W7.10: fire permission_denied analytics event when the pull fails due
      // to a Firestore rules rejection (distinct from the general pull_failed
      // event so dashboards can track auth/rules issues separately).
      if (e is FirestorePermissionDeniedException) {
        await _analytics?.logEvent(
          AnalyticsEvent.syncPermissionDenied,
          parameters: {
            'collection': e.collection ?? 'unknown',
            'operation': e.operation ?? 'read',
          },
        );
      }
      // W7.9: fire analytics pull_failed at the error boundary.
      // AUD-core-analytics-01 (PV-1): the raw `e.toString()` is dropped —
      // for Firestore permission/not-found errors it routinely embeds the
      // full document resource path (profiles/{id}/completions/{ref}).
      // `_analyticsErrorKind` gives a coarse, low-cardinality category
      // instead, matching the SY-3 friendly-message classification below.
      await _analytics?.logEvent(
        AnalyticsEvent.syncPullFailed,
        parameters: {
          'triggered_from_resume': triggeredFromResume,
          'error_kind': _analyticsErrorKind(e),
        },
      );
      // SY-3: map known exception types to friendly, user-facing messages.
      // Never pass e.toString() for exceptions whose toString() exposes
      // internal class names, collection paths, or SDK error codes.
      final message = switch (e) {
        // Timeout: existing friendly message — keep as-is.
        TimeoutException() => 'Sync timed out — tap to retry',
        // PERMISSION_DENIED: friendly message instead of leaking the
        // class name, collection path, and [cloud_firestore/permission-denied].
        FirestorePermissionDeniedException() =>
          'Cloud backup is temporarily unavailable. Tap to retry.',
        // All other exceptions: fall back to a generic message rather than
        // surfacing the raw exception toString(), which may contain internal
        // class names or SDK internals that are meaningless to the user.
        _ => 'Sync failed — tap to retry',
      };
      _safeEmitStatus(
        SyncStatus.error(message: message, failedAt: DateTimeFactory.nowUtc()),
      );
      rethrow;
    }
  }

  @override
  Future<void> retryPull() async {
    _pullGuard = const _PullNeverRun();
    return pullOnLaunch();
  }

  /// Emit a [SyncStatus] on the orchestrator's own stream.
  ///
  /// W2.33: status is owned by the orchestrator — the [SyncEngine] delegate
  /// is no longer involved. If the controller is already closed (e.g. the
  /// orchestrator was disposed between a pull starting and completing) the
  /// emit is a safe no-op.
  void _safeEmitStatus(SyncStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  // ── Phase 4 — outbox-derived sync-status emission ───────────────────────────

  /// Record one outbox-drain attempt and emit the appropriate sync-status.
  ///
  /// Call this after every drain in the orchestrator (write-tee path,
  /// pull-complete path, connectivity-online path, lifecycle-resume path,
  /// periodic timer). The method queries the outbox once and emits the
  /// derived [SyncStatus] per Plan §F Phase 4 deliverable 2:
  ///
  ///   * `offline`   — `_lastConnectivity == false` (regardless of outbox).
  ///   * `degraded`  — outbox has rows whose `attempts ≥ 3`.
  ///   * `pending`   — online + outbox not empty + no stuck rows.
  ///   * `synced`    — online + outbox empty + a pull has completed.
  ///
  /// While a pull is actively running ([SyncStatusSyncing]) the method is a
  /// no-op so the pull's `syncing` indicator is not overwritten with a
  /// `pending` flicker on every transient drain. Mid-pull writes are still
  /// reconciled by the post-pull recompute (see [pullOnLaunch]).
  ///
  /// Side effect: logs the `sync_outbox_depth` observability gauge so
  /// dashboards can graph backlog age. Safe to call after [dispose] —
  /// the status-controller closed-check guards against use-after-dispose.
  @override
  Future<void> recordDrainAttempt() => _recomputeOutboxStatus();

  /// One-shot guard for [_maybeReviveIdentityDeadLetters]. Lives on the
  /// orchestrator singleton (NOT the outbox processor, which is rebuilt on
  /// every account switch / sign-in — i.e. across the very transition we care
  /// about), so the revive fires exactly once per app launch.
  bool _identityDeadLettersRevived = false;

  /// Give identity/permission dead-letters one fresh attempt under the current
  /// identity — once per launch, and only while the identity matches (when it
  /// does NOT, the processor guard skips the drain anyway, so reviving would be
  /// pointless and we leave the flag unset to retry once it matches).
  Future<void> _maybeReviveIdentityDeadLetters() async {
    if (_identityDeadLettersRevived) return;

    final identity = _resolveIdentityStatus?.call();
    if (identity != null && identity.isMismatch) return; // wait until matched

    final resolveDao = _resolveOutboxDao;
    if (resolveDao == null) return;

    OutboxDao dao;
    try {
      dao = resolveDao();
    } catch (_) {
      return; // DB swap mid-flight — try again on the next drain.
    }

    _identityDeadLettersRevived = true;
    try {
      var revived = await dao.reviveIdentityDeadLetters(_profileId);
      if (_profileId != 0) {
        revived += await dao.reviveIdentityDeadLetters(0);
      }
      if (revived > 0) {
        _logger?.info(
          event: 'sync_outbox_identity_deadletters_revived',
          fields: {'count': revived},
        );
      }
    } catch (e, st) {
      // Reset the flag so a transient DB error doesn't permanently skip the
      // one-shot revive for this launch.
      _identityDeadLettersRevived = false;
      _logger?.warning(
        event: 'sync_outbox_identity_deadletters_revive_failed',
        exception: e,
        stackTrace: st,
      );
    }
  }

  /// Returns true (and emits an actionable identity-mismatch status) when the
  /// live Firebase identity does not match the active account — in which case
  /// the caller must NOT attempt a Firestore pull (every read would be denied).
  ///
  /// Best-effort outbox depth is read for the `pendingChanges` count; any DB
  /// error there is swallowed (depth defaults to 0) since the actionable
  /// re-auth message — not the count — is the point.
  Future<bool> _skipPullOnIdentityMismatch() async {
    final identity = _resolveIdentityStatus?.call();
    if (identity == null || !identity.isMismatch) return false;

    var depth = 0;
    try {
      final dao = _resolveOutboxDao?.call();
      if (dao != null) {
        depth = await dao.depth(_profileId);
        if (_profileId != 0) depth += await dao.depth(0);
      }
    } catch (_) {
      // Best-effort — the message matters more than an exact pending count.
    }

    final activeEmail = identity.activeAccountEmail;
    _logger?.info(
      event: 'sync_orchestrator_pull_skipped_identity_mismatch',
      fields: {
        'activeAccountEmail': activeEmail,
        'signedInEmail': identity.signedInEmail,
        'pendingChanges': depth,
      },
    );
    _safeEmitStatus(
      SyncStatus.degraded(
        pendingChanges: depth,
        reason: activeEmail != null
            ? 'Signed in as ${identity.signedInEmail ?? 'a different account'}'
                  ' — sign in as $activeEmail to back up this account.'
            : 'Signed in as the wrong account — sign in again to back up.',
      ),
    );
    return true;
  }

  Future<void> _recomputeOutboxStatus() async {
    if (_statusController.isClosed) return;

    final resolveDao = _resolveOutboxDao;
    if (resolveDao == null) {
      // No outbox wired — keep the existing pull-driven status.
      return;
    }

    OutboxDao dao;
    try {
      dao = resolveDao();
    } catch (e, st) {
      // DB swap mid-flight: log and bail; the next drain attempt will retry.
      _logger?.warning(
        event: 'sync_outbox_status_resolver_failed',
        exception: e,
        stackTrace: st,
      );
      return;
    }

    int depth;
    DateTime? oldest;
    int stuck;
    try {
      depth = await dao.depth(_profileId);
      oldest = await dao.oldestPendingAt(_profileId);
      stuck = await dao.stuckCount(
        _profileId,
        minAttempts: _degradedAttemptThreshold,
      );
      // D13: `_doDrain` sweeps the active profile AND profile 0 (the bootstrap
      // `learner_profile` push and any account-level row is enqueued under
      // profile 0 before a profile is active). The status MUST mirror that
      // two-profile sweep — otherwise a wedged profile-0 row (e.g.
      // permission-denied) is invisible here, depth reads 0, and the indicator
      // shows a false 'Synced' while the bootstrap push never reaches the cloud.
      if (_profileId != 0) {
        depth += await dao.depth(0);
        stuck += await dao.stuckCount(
          0,
          minAttempts: _degradedAttemptThreshold,
        );
        final oldest0 = await dao.oldestPendingAt(0);
        if (oldest0 != null && (oldest == null || oldest0.isBefore(oldest))) {
          oldest = oldest0;
        }
      }
    } catch (e, st) {
      // Drift errors during shutdown / DB swap — degrade gracefully.
      _logger?.warning(
        event: 'sync_outbox_status_query_failed',
        exception: e,
        stackTrace: st,
      );
      return;
    }

    // Treat unknown connectivity (null) as online — the orchestrator only
    // ever exists in a cloud-born session, so the seed/transition logic in
    // [_onConnectivityChange] will correct this on the next emission.
    final isOnline = _lastConnectivity ?? true;

    final oldestAgeSeconds = oldest == null
        ? 0
        : DateTimeFactory.nowUtc().difference(oldest).inSeconds;
    _logger?.info(
      event: LogEvents.sync.outboxDepth,
      fields: {
        'count': depth,
        'oldest_age_seconds': oldestAgeSeconds,
        'stuck_count': stuck,
        'is_online': isOnline,
      },
    );

    // Don't overwrite a fresh `syncing` (active pull in progress) with an
    // online-derived state — the pull's own _safeEmitStatus(syncing→synced)
    // chain owns that window.
    //
    // EXCEPTION: if the device is offline, the `offline` state must win
    // immediately even while a pull is in flight. Without this exception
    // the badge stays stuck on "Syncing…" for the full pull-timeout window
    // (up to 30 s × steps) after the user goes offline and records
    // completions — the write-tee and connectivity-change recomputes both
    // hit this guard and silently return. (SYNC-OFFLINE-SYNCING-01)
    if (_currentStatus is SyncStatusSyncing && isOnline) return;

    // Don't overwrite a pull error — the error card in Backup & Sync shows
    // an actionable "tap to retry" affordance that the user needs to recover.
    // Outbox-derived status (pending/degraded) is about PUSH health; a pull
    // failure is a separate condition that must remain visible until the user
    // explicitly retries or a successful pull supersedes it.  Without this
    // guard a periodic drain or write-tee recompute would replace the error
    // banner with "N changes pending", silently removing the retry option.
    if (_currentStatus is SyncStatusError) return;

    // Identity mismatch takes precedence over the generic stuck/pending states
    // whenever there is queued data and the device is online: the rows are not
    // "stuck after N attempts" (the drain is skipped before they ever retry) —
    // they are blocked on the wrong Firebase identity. Surface the actionable
    // "sign in as <email>" message so the user can resolve it.
    final identity = _resolveIdentityStatus?.call();

    final SyncStatus next;
    if (!isOnline) {
      next = SyncStatus.offline(pendingChanges: depth);
    } else if (identity != null && identity.isMismatch && depth > 0) {
      final activeEmail = identity.activeAccountEmail;
      next = SyncStatus.degraded(
        pendingChanges: depth,
        reason: activeEmail != null
            ? 'Signed in as ${identity.signedInEmail ?? 'a different account'}'
                  ' — sign in as $activeEmail to back up this account.'
            : 'Signed in as the wrong account — sign in again to back up.',
      );
    } else if (stuck > 0) {
      next = SyncStatus.degraded(
        pendingChanges: depth,
        reason:
            'outbox has $stuck row(s) stuck after '
            '$_degradedAttemptThreshold+ attempts',
      );
    } else if (depth > 0) {
      next = SyncStatus.pending(pendingChanges: depth);
    } else if (_everPulledOnLaunch) {
      next = SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowUtc());
    } else {
      // Outbox empty but no pull yet this session — leave whatever the
      // pull path most-recently emitted (typically `localOnly` or an
      // in-flight `syncing` that was already filtered above).
      return;
    }

    _safeEmitStatus(next);
  }

  /// Re-open the Firestore real-time listener set against the current profile.
  ///
  /// Called when the active profile changes (I3 / R1). The live listener set
  /// is bound to a concrete profile id at the moment each channel stream is
  /// opened, so a profile switch requires the supervisor to `restart()`:
  /// [FirestoreListenerSource.openChannels] then resolves the new profile id
  /// and the supervisor re-subscribes to the correct subcollections.
  ///
  /// Only the [ListenerSupervisor] is restarted — the [LifecycleObserver] (and
  /// its single [WidgetsBinding] registration) is left untouched, so no
  /// duplicate lifecycle observer is ever created (the Bug #1 failure mode).
  ///
  /// A no-op when [start] was never called.
  @override
  void restartListeners() {
    final supervisor = _listenerSupervisor;
    if (supervisor == null) return;
    _logger?.info(event: 'sync_orchestrator_listeners_restart_for_profile');
    // Fire-and-forget, but never silently: if restart() throws (e.g. the
    // gateway resolver returns null mid-upgrade), log it so the failure is
    // observable and the supervisor is not left silently detached (L2).
    unawaited(
      supervisor.restart().catchError((Object e, StackTrace stackTrace) {
        _logger?.error(
          event: 'sync_orchestrator_listeners_restart_failed',
          exception: e,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  /// Stop the Firestore real-time listener set without disposing the
  /// orchestrator. See [SyncOrchestrator.stopListeners] for the account-switch
  /// rationale (tear down before the uid flips so no stale-uid listen is
  /// denied). A no-op when [start] was never called.
  ///
  /// The [LifecycleObserver] and the status stream are intentionally left
  /// untouched — only the listener subscriptions are cancelled. A later
  /// [restartListeners] (fired by the active-profile listener once the new
  /// identity resolves) re-opens the channel set against the current uid.
  @override
  Future<void> stopListeners() async {
    final supervisor = _listenerSupervisor;
    if (supervisor == null) return;
    _logger?.info(event: 'sync_orchestrator_listeners_stop_for_switch');
    try {
      await supervisor.stop();
    } catch (e, stackTrace) {
      _logger?.warning(
        event: 'sync_orchestrator_listeners_stop_failed',
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Dispose listeners and unregister from [WidgetsBinding].
  ///
  /// Called by the Riverpod provider's `onDispose` callback. After disposal,
  /// no further pulls or listener events will be processed. A no-op when
  /// [start] was never called.
  void dispose() {
    if (!_started) return;
    _started = false;
    _connectivityResetDebounce?.cancel();
    _connectivityResetDebounce = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    // Phase 0 — cancel the periodic drain timer started in [start] so the
    // disposed orchestrator does not keep firing background work.
    _periodicDrainTimer?.cancel();
    _periodicDrainTimer = null;
    _lifecycleObserver?.stop();
    _listenerSupervisor?.stop();
    _lifecycleObserver = null;
    _listenerSupervisor = null;
    // W2.33: close the owned status stream.
    _statusController.close();
  }

  // ── Listener event handling ─────────────────────────────────────────────────

  void _onListenerEvent(String channel, Object? payload) {
    // Real-time listener payload: forward to the MergeRouter for the
    // appropriate kind. The payload from FirestoreGateway.listenToCollection
    // is a `List<Map<String, dynamic>>`.
    if (payload == null) return;

    final kind = _channelToKind(channel);
    if (kind == null) return;

    List<Map<String, dynamic>> rows;
    if (payload is List) {
      rows = payload.cast<Map<String, dynamic>>();
    } else if (payload is Map<String, dynamic>) {
      rows = [payload];
    } else {
      return;
    }

    if (rows.isEmpty) return;

    // Fire-and-forget merge — errors are logged but not surfaced to the UI
    // since listeners are best-effort (the pull-on-launch path is authoritative).
    // Resolve the MergeRouter lazily so a router rebuild is picked up (I5).
    _resolveMergeRouter()
        .dispatch(profileId: _profileId, kind: kind, rows: rows)
        .catchError((Object e, StackTrace st) {
          _logger?.error(
            event: 'sync_orchestrator_listener_merge_failed',
            fields: {'channel': channel, 'kind': kind},
            exception: e,
            stackTrace: st,
          );
          return MergeOutcome.halt;
        });
  }

  void _onListenerError(String channel, Object error, StackTrace stackTrace) {
    _logger?.error(
      event: 'sync_orchestrator_listener_error',
      fields: {'channel': channel},
      exception: error,
      stackTrace: stackTrace,
    );
    // W7.16: forward listener errors to Crashlytics as non-fatal so they
    // appear in the crash dashboard without needing a structured log viewer.
    _crashlytics?.recordError(error, stackTrace, fatal: false);
    // W7.8: fire analytics listener_error event for dashboards (in addition
    // to the Crashlytics non-fatal above — both are needed: Crashlytics for
    // developer triage, Analytics for trend detection).
    // AUD-core-analytics-01 (PV-1): the raw `error.toString()` is dropped —
    // see `_analyticsErrorKind` for why a coarse category replaces it.
    final future = _analytics?.logEvent(
      AnalyticsEvent.syncListenerError,
      parameters: {
        'channel': channel,
        'error_kind': _analyticsErrorKind(error),
      },
    );
    if (future != null) unawaited(future);
  }

  /// Coarse, low-cardinality classification of a sync error for analytics
  /// parameters (PV-1). Mirrors the SY-3 friendly-message switch above —
  /// never pass a raw exception `.toString()` to an analytics event, since
  /// Firestore exceptions routinely embed document resource paths
  /// (`profiles/{id}/completions/{ref}`) that identify a specific child and
  /// the content they studied.
  static String _analyticsErrorKind(Object error) => switch (error) {
    TimeoutException() => 'timeout',
    FirestorePermissionDeniedException() => 'permission_denied',
    _ => 'other',
  };

  static String? _channelToKind(String channel) => switch (channel) {
    'completions' => EntityKind.completion,
    'bookmarks' => EntityKind.bookmark,
    'settings' => EntityKind.settings,
    // W3.37: streak channel renamed from 'streak' to 'streak_events' to match
    // the new per-event collection. Keep 'streak' as a no-op fallback so that
    // any in-flight listener restart during upgrade doesn't crash on an unknown
    // channel.
    'streak_events' => EntityKind.streak,
    'curriculum_tracks' => EntityKind.trackConfig,
    // W2.29 — route real-time stage_definitions events through the
    // StageDefinitionMerger (registered in merge_router.dart).
    'stage_definitions' => EntityKind.stageDefinition,
    // Phase 1 — route real-time study_day_configs events through the
    // StudyDayConfigMerger.
    'study_day_configs' => EntityKind.studyDayConfig,
    // Phase 2 (sync-architecture-plan 2026-05-21) — every Phase 2 listener
    // routes its rows through MergeRouter via the appropriate EntityKind.
    'goals' => EntityKind.goal,
    'learning_ledger' => EntityKind.learningLedger,
    'learning_order' => EntityKind.learningOrder,
    'profile_programs' => EntityKind.profileProgram,
    'learner_profiles' => EntityKind.learnerProfile,
    'preferences/notification_settings' => EntityKind.notificationSettings,
    'preferences/gamification_settings' => EntityKind.gamificationSettings,
    'preferences/ui_preferences' => EntityKind.uiPreferences,
    'tutor_grants' => EntityKind.tutorGrant,
    // WS9 Wave-B (C#2) — points spend economy.
    'points_ledger' => EntityKind.pointsLedger,
    'reward_redemptions' => EntityKind.rewardRedemption,
    _ => null,
  };

  // ── Phase 2 — recovery-pull triggers ──────────────────────────────────────

  /// Build the per-channel recovery-pull map handed to the
  /// [ListenerSupervisor]. When a listener snapshot returns
  /// `isAtLimit == true` (signal: there may be older docs the listener window
  /// did not cover) the supervisor invokes the matching trigger so the
  /// pull-pipeline reconciles the collection. Each trigger calls the
  /// PullPipeline method for its kind only — NOT a full re-pull of every
  /// kind.
  Map<String, RecoveryPullTrigger> _buildRecoveryPullTriggers() {
    Future<void> log(String channel, Future<void> Function() op) async {
      _logger?.info(
        event: LogEvents.sync.listenerRecoveryPull,
        fields: {'channel': channel},
      );
      try {
        await op();
      } catch (e, st) {
        _logger?.warning(
          event: 'sync_listener_recovery_pull_failed',
          fields: {'channel': channel},
          exception: e,
          stackTrace: st,
        );
      }
    }

    PullPipeline pipeline() => PullPipeline(
      gateway: _resolveGateway(),
      dispatcher: _resolveMergeRouter(),
      analytics: _analytics,
    );

    return {
      'completions': () => log(
        'completions',
        () => pipeline().pullCompletions(profileId: _profileId),
      ),
      'bookmarks': () => log(
        'bookmarks',
        () => pipeline().pullBookmarks(profileId: _profileId),
      ),
      'settings': () =>
          log('settings', () => pipeline().pullSettings(profileId: _profileId)),
      'streak_events': () => log(
        'streak_events',
        () => pipeline().pullStreak(profileId: _profileId),
      ),
      'curriculum_tracks': () => log(
        'curriculum_tracks',
        () => pipeline().pullTracks(profileId: _profileId),
      ),
      'stage_definitions': () => log(
        'stage_definitions',
        () => pipeline().pullStageDefinitions(profileId: _profileId),
      ),
      'goals': () =>
          log('goals', () => pipeline().pullGoals(profileId: _profileId)),
      'learning_ledger': () => log(
        'learning_ledger',
        () => pipeline().pullLearningLedger(profileId: _profileId),
      ),
      'learning_order': () => log(
        'learning_order',
        () => pipeline().pullLearningOrder(profileId: _profileId),
      ),
      'profile_programs': () => log(
        'profile_programs',
        () => pipeline().pullProfilePrograms(profileId: _profileId),
      ),
      'learner_profiles': () => log(
        'learner_profiles',
        () => pipeline().pullLearnerProfiles(profileId: _profileId),
      ),
      // WS9 Wave-B (C#2) — points spend economy recovery pulls.
      'points_ledger': () => log(
        'points_ledger',
        () => pipeline().pullPointsLedger(profileId: _profileId),
      ),
      'reward_redemptions': () => log(
        'reward_redemptions',
        () => pipeline().pullRewardRedemptions(profileId: _profileId),
      ),
      // tutor_grants has no PullPipeline method (server-driven, no local DB
      // row). At-limit there would only fire if the user has > 500 active
      // grants which is well outside the practical envelope.
    };
  }

  // ── Phase 2 — snapshot-size telemetry ─────────────────────────────────────

  /// Log [LogEvents.sync.listenerSnapshotSize] for the first 10 snapshots
  /// per session. The supervisor stops invoking this callback after
  /// [ListenerSupervisor.maxTelemetrySnapshots] events.
  void _onListenerSnapshot(String channel, int size, bool isAtLimit) {
    _logger?.info(
      event: LogEvents.sync.listenerSnapshotSize,
      fields: {'collection': channel, 'size': size, 'is_at_limit': isAtLimit},
    );
  }
}

/// True when [error] originated in the local SQLite / Drift layer (e.g. an FK
/// constraint violation during a merge upsert), as opposed to a network /
/// gateway / rules failure.
///
/// Detected by runtime type name so the orchestrator does not have to import
/// the `drift` / `sqlite3` packages (and so it is robust across the whole Drift
/// exception hierarchy — `SqliteException`, `DriftWrappedException`,
/// `DriftRemoteException`, …). Used by the launch-pull step guard so a single
/// row's DB error cannot tear down the session (Bug 1).
bool _isLocalDatabaseError(Object error) {
  final name = error.runtimeType.toString();
  if (name.contains('Sqlite') || name.contains('Drift')) return true;
  // Some drift builds surface FK violations as a plain message string.
  final msg = error.toString().toLowerCase();
  return msg.contains('foreign key constraint failed') ||
      msg.contains('sqliteexception');
}
