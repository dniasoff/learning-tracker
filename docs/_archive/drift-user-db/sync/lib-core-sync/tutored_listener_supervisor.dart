// tutored_listener_supervisor.dart — D3/D5
//
// Owns the Firestore listener subscriptions for one tutored talmid session.
//
// Lifecycle contract:
//   attach(localProfileId, gateway, parentUid, remoteProfileId)
//     → opens streams for every child collection; routes payloads through
//       MergeDispatcher under the SYNTHETIC local profile id.
//   park() / unpark()
//     → Story 1.2 (AD-9, AD-22): delegate to the inner ListenerSupervisor's
//       park()/unpark() with the SAME semantics as the own-account fleet —
//       park cancels all subscriptions but remembers the session was live;
//       unpark reopens every channel. The lifecycle wiring that CALLS these
//       (background timer, resume hook) is Story 1.3's job; this class only
//       exposes the verbs.
//   detach()
//     → cancels all subscriptions (and any pending per-channel resubscribe
//       backoff timer — see [ListenerSupervisor.stop]); safe to call when
//       nothing is attached.
//
// Called by:
//   • Post-pull entry hook (attach after initial pull).
//   • ActiveTutoredProfileSelection.exit() → cascades to detach().
//   • TutoredMirrorWipeService.onWipe() → cascades to detach().
//   • AppShell auth-state observer → .exit() → detach().
//   • (Story 1.3) LifecycleObserver's parkListeners/unparkListeners hooks →
//     park()/unpark(), mirroring how SyncOrchestratorImpl wires the
//     own-account ListenerSupervisor today.
//
// DATA ISOLATION:
//   Streams are opened via a parent-scoped gateway so they ONLY read from
//   `users/{parentUid}/learner_profiles/{remoteProfileId}/…`. The tutor's
//   own namespace is never subscribed to here; the own-data ListenerSupervisor
//   runs independently via SyncOrchestrator.
//
// RESUBSCRIBE-ON-ERROR PARITY (Story 1.2 / AD-9):
//   The inner ListenerSupervisor is the SAME class the own-account fleet
//   uses (Story 1.1), so per-channel mark-dead + bounded-exponential-backoff
//   resubscribe is inherited for free — no per-fleet reimplementation. A
//   genuinely permanent permission-denied (e.g. a revoked tutor_active_access
//   grant) degrades to retrying-at-the-cap forever (AD-9's "no permanent
//   give-up while connectivity is up" rule), never a tight loop and never a
//   resting "exhausted" state. The backoff schedule is configurable via this
//   class's constructor (forwarded to the inner ListenerSupervisor) purely
//   so tests can shrink real-time waits — production always uses the
//   ListenerSupervisor defaults unless overridden.

import 'dart:async';
import 'dart:math' as math;

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
    // Story 1.2 — forwarded verbatim to the inner ListenerSupervisor on each
    // [attach]. Overridable so tests can shrink real-time backoff waits to
    // milliseconds; production keeps the ListenerSupervisor defaults.
    Duration resubscribeBackoffBase = const Duration(seconds: 1),
    Duration resubscribeBackoffCap = const Duration(seconds: 30),
    double resubscribeBackoffJitter = 0.2,
    math.Random? random,
  }) : assert(
         dispatcher != null || resolveDispatcher != null,
         'Provide either dispatcher or resolveDispatcher',
       ),
       _resolveDispatcher = resolveDispatcher ?? (() => dispatcher!),
       _resubscribeBackoffBase = resubscribeBackoffBase,
       _resubscribeBackoffCap = resubscribeBackoffCap,
       _resubscribeBackoffJitter = resubscribeBackoffJitter,
       _random = random;

  final MergeDispatcher Function() _resolveDispatcher;

  /// Story 1.2 — backoff schedule forwarded to the inner ListenerSupervisor.
  /// See the constructor doc: only ever overridden by tests.
  final Duration _resubscribeBackoffBase;
  final Duration _resubscribeBackoffCap;
  final double _resubscribeBackoffJitter;
  final math.Random? _random;

  /// Inner supervisor for this session. Replaced on each [attach].
  ListenerSupervisor? _supervisor;

  /// The synthetic local profile id currently active.
  int? _localProfileId;

  /// Whether listeners are currently attached.
  bool get isAttached => _supervisor?.isAttached ?? false;

  /// Whether the current session is [park]ed — subscriptions cancelled but
  /// remembered as "should be live" so [unpark] reopens them. Mirrors
  /// [ListenerSupervisor.isParked]; false when nothing has ever been
  /// attached in this session.
  bool get isParked => _supervisor?.isParked ?? false;

  /// Channels currently dead — errored and mid-backoff (or, while parked,
  /// awaiting the next [unpark]). Empty when every channel is healthy or
  /// nothing is attached. Mirrors [ListenerSupervisor.deadChannels] — see
  /// its doc for the full AD-9 resubscribe contract this class inherits.
  Set<String> get deadChannels => _supervisor?.deadChannels ?? const <String>{};

  /// Number of channels open (test helper).
  ///
  /// Counted by [TutoredListenerSource.openChannels] — exposed so tests can
  /// verify that exactly N subscriptions are created on attach. 16 = 13
  /// collection channels + 3 preference document channels (AUD-core-sync-18
  /// added `learning_order`, bringing the collection count from 12 to 13).
  static const int channelCount = 16;

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
      onEvent: (channel, payload) => _onEvent(localProfileId, channel, payload),
      onError: (channel, error, stackTrace) =>
          _onError(localProfileId, channel, error, stackTrace),
      // Story 1.2 — resubscribe-on-error parity (AD-9): reusing Story 1.1's
      // ListenerSupervisor gives the tutored fleet the same per-channel
      // mark-dead + bounded-exponential-backoff resubscribe as the
      // own-account fleet, with no per-fleet exception.
      resubscribeBackoffBase: _resubscribeBackoffBase,
      resubscribeBackoffCap: _resubscribeBackoffCap,
      resubscribeBackoffJitter: _resubscribeBackoffJitter,
      random: _random,
    );

    await _supervisor!.start();
  }

  /// Detach all subscriptions. Safe to call when nothing is attached.
  ///
  /// Cancels every live subscription AND any pending per-channel resubscribe
  /// backoff timer (via [ListenerSupervisor.stop] — Story 1.1's
  /// `_cancelPendingResubscribes`), so a channel that errored moments before
  /// session exit / mirror wipe cannot fire a resubscribe after detach.
  Future<void> detach() async {
    _localProfileId = null;
    final sup = _supervisor;
    _supervisor = null;
    await sup?.stop();
  }

  /// Park the current session's subscriptions: cancel every active
  /// gRPC stream but remember the session was live so [unpark] reopens it.
  ///
  /// Delegates to the inner [ListenerSupervisor.park] — SAME semantics as
  /// the own-account fleet (Phase 2 sync-architecture-plan / AD-22): every
  /// pending per-channel resubscribe backoff timer is cancelled too, and a
  /// channel that errors while parked is marked dead without scheduling a
  /// resubscribe (the next [unpark] reopens it along with every other
  /// channel).
  ///
  /// A no-op when nothing is currently attached (no session, or already
  /// parked/detached) — mirrors [ListenerSupervisor.park]'s own idempotence.
  ///
  /// Story 1.3 wires this into the lifecycle observer's background-window
  /// hook exactly the way `SyncOrchestratorImpl.start` wires the
  /// own-account `ListenerSupervisor.park` today; this class only exposes
  /// the verb.
  Future<void> park() async {
    await _supervisor?.park();
  }

  /// Reopen every channel after a [park]. No-op if nothing is attached, if
  /// the session was never parked, or if it was fully [detach]ed instead
  /// (use [attach] for a fresh session in that case).
  ///
  /// Delegates to the inner [ListenerSupervisor.unpark] — SAME semantics as
  /// the own-account fleet.
  Future<void> unpark() async {
    await _supervisor?.unpark();
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
    'learning_order' => EntityKind.learningOrder, // AUD-core-sync-18
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
          .catchError(
            (Object err, StackTrace st) {
              AppLogger.instance.warning(
                event: 'tutored_listener_merge_error',
                fields: {'kind': kind, 'profileId': localProfileId},
                exception: err,
                stackTrace: st,
              );
              return MergeOutcome.halt;
            },
            // AUD-core-sync-26 (EH-4): only Exception subtypes are logged and
            // swallowed here — a programming-error Error subtype escaping the
            // merger must propagate instead of being folded into an ordinary
            // "tutored listener merge error" warning.
            test: (err) => err is Exception,
          ),
    );
  }

  // ── Error routing (AUD-core-sync-12) ─────────────────────────────────────

  /// Surfaces a tutored-channel stream error via [AppLogger] instead of
  /// letting it vanish silently.
  ///
  /// The inner [ListenerSupervisor] no-ops a stream error when its `onError`
  /// callback is null (`_onError?.call(...)`) — before this fix, `attach()`
  /// never passed one. Firestore terminates a `.snapshots()` stream on error
  /// (e.g. permission-denied when a parent revokes the grant while the
  /// tutor's 15 tutored channels are live, or any transient stream fault),
  /// so that one channel would go permanently dark for the rest of the
  /// session — zero AppLogger entry, zero Crashlytics record, no
  /// resubscription — while sibling channels kept working. Mirrors (at
  /// minimum) the logging half of the own-profile path's `onError` wiring
  /// in `SyncOrchestratorImpl.start` / `_onListenerError`.
  void _onError(
    int localProfileId,
    String channel,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.instance.warning(
      event: 'tutored_listener_stream_error',
      fields: {'channel': channel, 'profileId': localProfileId},
      exception: error,
      stackTrace: stackTrace,
    );
  }
}
