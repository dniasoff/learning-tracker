// tutored_listener_supervisor.dart — D3/D5
//
// Owns the Firestore listener subscriptions for one tutored talmid session.
//
// Lifecycle contract:
//   attach(localProfileId, gateway, parentUid, remoteProfileId)
//     → opens streams for every child collection; routes payloads through
//       MergeDispatcher under the SYNTHETIC local profile id.
//   detach()
//     → cancels all subscriptions; safe to call when nothing is attached.
//
// Called by:
//   • Post-pull entry hook (attach after initial pull).
//   • ActiveTutoredProfileSelection.exit() → cascades to detach().
//   • TutoredMirrorWipeService.onWipe() → cascades to detach().
//   • AppShell auth-state observer → .exit() → detach().
//
// DATA ISOLATION:
//   Streams are opened via a parent-scoped gateway so they ONLY read from
//   `users/{parentUid}/learner_profiles/{remoteProfileId}/…`. The tutor's
//   own namespace is never subscribed to here; the own-data ListenerSupervisor
//   runs independently via SyncOrchestrator.

import 'dart:async';

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/tutored_listener_source.dart';

/// Manages the real-time Firestore listener set for the current tutored
/// talmid session.
///
/// Delegates subscription lifecycle to an inner [ListenerSupervisor]. All
/// incoming payloads are dispatched through [MergeDispatcher] under the
/// synthetic local profile id — never the remote child id.
///
/// The dispatcher is resolved lazily via [resolveDispatcher] so a DB swap
/// (multi-account flow) picks up the latest [MergeRouter] without recreating
/// this supervisor.
class TutoredListenerSupervisor {
  TutoredListenerSupervisor({
    MergeDispatcher? dispatcher,
    MergeDispatcher Function()? resolveDispatcher,
  }) : assert(
         dispatcher != null || resolveDispatcher != null,
         'Provide either dispatcher or resolveDispatcher',
       ),
       _resolveDispatcher = resolveDispatcher ?? (() => dispatcher!);

  final MergeDispatcher Function() _resolveDispatcher;

  /// Inner supervisor for this session. Replaced on each [attach].
  ListenerSupervisor? _supervisor;

  /// The synthetic local profile id currently active.
  int? _localProfileId;

  /// Whether listeners are currently attached.
  bool get isAttached => _supervisor?.isAttached ?? false;

  /// Number of channels open (test helper).
  ///
  /// Counted by [TutoredListenerSource.openChannels] — exposed so tests can
  /// verify that exactly N subscriptions are created on attach.
  static const int channelCount = 15;

  /// Attach listeners for a talmid entry.
  ///
  /// [localProfileId] — synthetic Drift profile id (from TutoredPullService).
  /// [gateway]        — parent-scoped FirestoreGatewayImpl.
  /// [parentUid]      — parent's Firebase UID.
  /// [remoteProfileId] — child's profile id in the parent's account.
  ///
  /// Idempotent: calling attach when already attached for the same session
  /// (same localProfileId) is a no-op. Calling for a NEW session detaches
  /// the old set first.
  Future<void> attach({
    required int localProfileId,
    required FirestoreGateway gateway,
    required String parentUid,
    required String remoteProfileId,
  }) async {
    if (_localProfileId == localProfileId && isAttached) return;
    await detach();

    _localProfileId = localProfileId;

    final source = TutoredListenerSource(
      gateway: gateway,
      parentUid: parentUid,
      remoteProfileId: remoteProfileId,
    );

    _supervisor = ListenerSupervisor(
      source: source,
      onEvent: (channel, payload) =>
          _onEvent(localProfileId, channel, payload),
    );

    await _supervisor!.start();
  }

  /// Detach all subscriptions. Safe to call when nothing is attached.
  Future<void> detach() async {
    _localProfileId = null;
    final sup = _supervisor;
    _supervisor = null;
    await sup?.stop();
  }

  // ── Channel → entity kind mapping (mirrors SyncOrchestratorImpl) ─────────

  static String? _channelToKind(String channel) => switch (channel) {
    'completions' => EntityKind.completion,
    'bookmarks' => EntityKind.bookmark,
    'settings' => EntityKind.settings,
    'streak_events' => EntityKind.streak,
    'curriculum_tracks' => EntityKind.trackConfig,
    'stage_definitions' => EntityKind.stageDefinition,
    'study_day_configs' => EntityKind.studyDayConfig,
    'goals' => EntityKind.goal,
    'learning_ledger' => EntityKind.learningLedger,
    'profile_programs' => EntityKind.profileProgram,
    'preferences/notification_settings' => EntityKind.notificationSettings,
    'preferences/gamification_settings' => EntityKind.gamificationSettings,
    'preferences/ui_preferences' => EntityKind.uiPreferences,
    'points_ledger' => EntityKind.pointsLedger,
    'reward_redemptions' => EntityKind.rewardRedemption,
    _ => null,
  };

  // ── Payload routing ──────────────────────────────────────────────────────

  void _onEvent(int localProfileId, String channel, Object? payload) {
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

    // R4-M1: fire-and-forget with error logging. Listeners are best-effort;
    // the initial pull is authoritative. Errors were previously silently
    // dropped — now logged so merge failures are observable.
    unawaited(
      _resolveDispatcher()
          .dispatch(profileId: localProfileId, kind: kind, rows: rows)
          .catchError((Object err, StackTrace st) {
        AppLogger.instance.warning(
          event: 'tutored_listener_merge_error',
          fields: {'kind': kind, 'profileId': localProfileId},
          exception: err,
          stackTrace: st,
        );
        return MergeOutcome.halt;
      }),
    );
  }
}
