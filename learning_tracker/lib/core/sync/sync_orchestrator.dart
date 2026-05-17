import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_listener_source.dart';
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
    required SyncEngine engine,
    required PullPipeline pullPipeline,
    required MergeRouter mergeRouter,
    required FirestoreGateway gateway,
    required int Function() resolveProfileId,
    AppLogger? logger,
  }) : _engine = engine,
       _pullPipeline = pullPipeline,
       _mergeRouter = mergeRouter,
       _gateway = gateway,
       _resolveProfileId = resolveProfileId,
       _logger = logger {
    _listenerSupervisor = ListenerSupervisor(
      source: FirestoreListenerSource(
        gateway: _gateway,
        profileId: _resolveProfileId(),
      ),
      onEvent: _onListenerEvent,
      onError: _onListenerError,
    );

    _lifecycleObserver = LifecycleObserver(
      redetectTimezone: () async {
        // No-op until DNI-26.24 wires timezone redetection — seam exists.
      },
      invalidateSacredCache: () async {
        // No-op until DNI-26.24 wires persisted sacred-window cache — seam exists.
      },
      triggerPull: () => pullOnLaunch(triggeredFromResume: true),
    );

    _lifecycleObserver.start();
    _listenerSupervisor.start();
  }

  final SyncEngine _engine;
  final PullPipeline _pullPipeline;
  final MergeRouter _mergeRouter;
  final FirestoreGateway _gateway;
  final int Function() _resolveProfileId;
  final AppLogger? _logger;

  int get _profileId => _resolveProfileId();

  late final ListenerSupervisor _listenerSupervisor;
  late final LifecycleObserver _lifecycleObserver;

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
    }

    _logger?.info(event: 'sync_orchestrator_pull_on_launch_start');

    try {
      // Pull each entity kind through the PullPipeline → MergeRouter path.
      // The MergeRouter dispatches each page to the appropriate EntityMerger.
      await _pullPipeline.pullCompletions(profileId: _profileId);
      await _pullPipeline.pullBookmarks(profileId: _profileId);
      await _pullPipeline.pullSettings(profileId: _profileId);
      await _pullPipeline.pullTracks(profileId: _profileId);
      await _pullPipeline.pullLearnerProfiles(profileId: _profileId);
      await _pullPipeline.pullLearningOrder(profileId: _profileId);

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

      _logger?.info(event: 'sync_orchestrator_pull_on_launch_complete');
    } catch (e, stackTrace) {
      _logger?.error(
        event: 'sync_orchestrator_pull_on_launch_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Dispose listeners and unregister from [WidgetsBinding].
  ///
  /// Called by the Riverpod provider's `onDispose` callback. After disposal,
  /// no further pulls or listener events will be processed.
  void dispose() {
    _lifecycleObserver.stop();
    _listenerSupervisor.stop();
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
    _mergeRouter
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
