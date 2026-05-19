import 'dart:async';

import 'package:flutter/widgets.dart';
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
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
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
    required SyncEngine Function() resolveEngine,
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
  }) : _resolveEngine = resolveEngine,
       _resolveMergeRouter = resolveMergeRouter,
       _resolveGateway = resolveGateway,
       _resolveProfileId = resolveProfileId,
       _logger = logger,
       _onFirstSyncComplete = onFirstSyncComplete;

  /// Resolves the current [SyncEngine] on demand.
  ///
  /// The orchestrator is a per-session singleton (S7); the [SyncEngine] it
  /// delegates push/status to may itself be rebuilt (e.g. after a DB swap),
  /// so the engine is resolved lazily rather than captured at construction.
  final SyncEngine Function() _resolveEngine;

  /// Optional callback invoked the first time a full pull completes.  See
  /// constructor doc for [onFirstSyncComplete].
  final void Function()? _onFirstSyncComplete;

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

  SyncEngine get _engine => _resolveEngine();

  int get _profileId => _resolveProfileId();

  ListenerSupervisor? _listenerSupervisor;
  LifecycleObserver? _lifecycleObserver;

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

  @override
  SyncStatus get currentStatus => _engine.currentStatus;

  @override
  Stream<SyncStatus> get statusStream => _engine.statusStream;

  @override
  Future<void> pushAllLocalData() => _engine.pushAllLocalData();

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

      // Pull each entity kind through the PullPipeline → MergeRouter path.
      // The MergeRouter dispatches each page to the appropriate EntityMerger.
      await pullPipeline.pullCompletions(profileId: _profileId);
      await pullPipeline.pullBookmarks(profileId: _profileId);
      await pullPipeline.pullSettings(profileId: _profileId);
      await pullPipeline.pullTracks(profileId: _profileId);
      await pullPipeline.pullLearnerProfiles(profileId: _profileId);
      await pullPipeline.pullLearningOrder(profileId: _profileId);

      // Record successful pull timestamp for resume-throttle.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _lastSyncKey,
          DateTimeFactory.nowUtc().millisecondsSinceEpoch,
        );
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

      _logger?.info(event: 'sync_orchestrator_pull_on_launch_complete');
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
      rethrow;
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
