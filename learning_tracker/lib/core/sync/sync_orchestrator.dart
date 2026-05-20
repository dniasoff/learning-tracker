import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_listener_source.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/core/sync/lifecycle_observer.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
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
}

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

    /// Outbox-backed replacement for the legacy goals-backfill path.
    ///
    /// Idempotent, guarded by a SharedPreferences flag.  Called once after the
    /// first successful pull to catch up goals that were created before the
    /// outbox path was wired (DNI-334 cutover).
    required Future<int> Function() resolveBackfillGoals,

    /// W7.16: optional Crashlytics service — when provided, listener errors
    /// are forwarded as non-fatal crashes in addition to the structured log.
    CrashlyticsService? crashlytics,
  }) : _resolveMergeRouter = resolveMergeRouter,
       _resolveGateway = resolveGateway,
       _resolveProfileId = resolveProfileId,
       _logger = logger,
       _crashlytics = crashlytics,
       _onFirstSyncComplete = onFirstSyncComplete,
       _resolvePushAllLocalData = resolvePushAllLocalData,
       _resolveBackfillGoals = resolveBackfillGoals;

  /// Optional callback invoked the first time a full pull completes.  See
  /// constructor doc for [onFirstSyncComplete].
  final void Function()? _onFirstSyncComplete;

  /// Outbox-backed pushAllLocalData callback.
  final Future<void> Function() _resolvePushAllLocalData;

  /// Outbox-backed backfillGoalsForCloudCutover callback.
  final Future<int> Function() _resolveBackfillGoals;

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

  int get _profileId => _resolveProfileId();

  ListenerSupervisor? _listenerSupervisor;
  LifecycleObserver? _lifecycleObserver;

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
  /// Reset to false when a non-resume pull fails, so `DeviceRestoreService`'s
  /// retry path can genuinely re-pull after a failed restore (I4).
  bool _pullOnLaunchExecuted = false;

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
    );
    _listenerSupervisor = listenerSupervisor;

    final lifecycleObserver = LifecycleObserver(
      redetectTimezone: () async {
        // No-op until DNI-26.24 wires timezone redetection — seam exists.
      },
      invalidateSacredCache: () async {
        // No-op until DNI-26.24 wires persisted sacred-window cache — seam exists.
      },
      triggerPull: () => pullOnLaunch(triggeredFromResume: true),
    );
    _lifecycleObserver = lifecycleObserver;

    lifecycleObserver.start();
    listenerSupervisor.start();
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
            return;
          }
        }
      } catch (_) {
        // Swallow SharedPreferences errors — fall through to pull.
      }
    } else if (_pullOnLaunchExecuted) {
      // Once-per-launch guard (S8): a cold-start pull has already run. Any
      // additional non-resume call — e.g. the sign-in screen and the lifecycle
      // observer both firing on the same launch — is a no-op. The guard is
      // reset on failure below so DeviceRestoreService.retry() can re-pull.
      _logger?.info(event: 'sync_orchestrator_pull_skipped_already_executed');
      return;
    }

    if (!triggeredFromResume) {
      _pullOnLaunchExecuted = true;
    }

    _logger?.info(event: 'sync_orchestrator_pull_on_launch_start');

    // P5: announce the pull on the shared status stream. The previous
    // orchestrator delegated pulls to PullPipeline but never updated the
    // engine's SyncStatus — `pull_on_launch_complete` fired in the logs while
    // the UI sat on "Syncing…" forever. Emitting `syncing` here (and
    // `synced` / `error` below) makes the Backup & Sync card track reality.
    _safeEmitStatus(SyncStatus.syncing(startedAt: DateTimeFactory.nowUtc()));

    try {
      // Build the PullPipeline against the CURRENT gateway + MergeRouter so a
      // gateway rebuild (upgrade-to-cloud) or a router rebuild (DB swap) is
      // picked up — the orchestrator never pulls through a stale handle (I5).
      // PullPipeline is a trivial value holder, so per-pull construction is
      // cheap.
      final pullPipeline = PullPipeline(
        gateway: _resolveGateway(),
        dispatcher: _resolveMergeRouter(),
      );

      Future<void> step(String label, Future<void> Function() op) {
        return op().timeout(
          _perStepTimeout,
          onTimeout: () => throw TimeoutException(
            'sync_pull_step_timeout: $label',
            _perStepTimeout,
          ),
        );
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

      _safeEmitStatus(SyncStatus.synced(lastSyncedAt: syncedAt));
      _logger?.info(event: 'sync_orchestrator_pull_on_launch_complete');

      // One-time backfill of goals (DNI-334 cutover misrouted them through
      // `pushSettings` so they never reached the cloud — fixed 2026-05-19).
      // Idempotent + guarded by SharedPreferences flag; logs a no-op count
      // on every subsequent launch.  Best-effort: a throwing callback must not
      // fail the pull.
      try {
        await _resolveBackfillGoals();
      } catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_goal_backfill_failed',
          exception: e,
          stackTrace: stackTrace,
        );
      }
    } catch (e, stackTrace) {
      // Reset the once-per-launch guard so DeviceRestoreService.retry() (or
      // any other external retry) can re-run a cold-start pull after a
      // failed attempt (I4 / S8).
      if (!triggeredFromResume) _pullOnLaunchExecuted = false;
      _logger?.error(
        event: 'sync_orchestrator_pull_on_launch_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      final message = e is TimeoutException
          ? 'Sync timed out — tap to retry'
          : e.toString();
      _safeEmitStatus(
        SyncStatus.error(message: message, failedAt: DateTimeFactory.nowUtc()),
      );
      rethrow;
    }
  }

  @override
  Future<void> retryPull() async {
    _pullOnLaunchExecuted = false;
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

  /// Dispose listeners and unregister from [WidgetsBinding].
  ///
  /// Called by the Riverpod provider's `onDispose` callback. After disposal,
  /// no further pulls or listener events will be processed. A no-op when
  /// [start] was never called.
  void dispose() {
    if (!_started) return;
    _started = false;
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
  }

  static String? _channelToKind(String channel) => switch (channel) {
    'completions' => EntityKind.completion,
    'bookmarks' => EntityKind.bookmark,
    'settings' => EntityKind.settings,
    'streak' => EntityKind.streak,
    'curriculum_tracks' => EntityKind.trackConfig,
    _ => null,
  };
}
