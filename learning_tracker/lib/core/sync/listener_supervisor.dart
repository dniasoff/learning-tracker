import 'dart:async';

import 'package:learning_tracker/core/sync/firestore_gateway.dart'
    show ListenerSnapshot;
import 'package:learning_tracker/core/utils/date_utils.dart';

// ---------------------------------------------------------------------------
// Sealed restart-cycle state machine (W5.9).
//
// Replaces _restartInFlight: Future<void>? + _rerunRequested: bool — two
// independent fields that together encode three states:
//
//   idle              — no restart cycle is running; all callers get a fresh
//                       cycle when they call restart()
//   restarting        — one stop()+start() cycle is in flight; additional
//                       restart() calls coalesce and wait for it
//   restartingPending — cycle in flight AND ≥1 restart() arrived mid-cycle;
//                       the cycle runs one more iteration on completion so the
//                       final subscription set targets the latest profile
//
// The [future] field on the non-idle states carries the Future returned to
// coalesced callers so they can await the actual completion of their request.
// ---------------------------------------------------------------------------
sealed class _RestartCycle {
  const _RestartCycle();
}

/// No restart is currently in progress.
final class _RestartIdle extends _RestartCycle {
  const _RestartIdle();
}

/// A restart cycle is in flight; no additional restart is queued.
final class _Restarting extends _RestartCycle {
  const _Restarting({required this.future});

  /// The in-flight Future — returned to coalesced restart() callers so they
  /// await the same cycle rather than starting a second one.
  final Future<void> future;
}

/// A restart cycle is in flight AND at least one more restart() arrived
/// mid-cycle. The running cycle will perform an extra iteration on completion
/// to rebind to the latest profile.
final class _RestartingPending extends _RestartCycle {
  const _RestartingPending({required this.future});

  /// Same as [_Restarting.future] — the in-flight cycle's Future.
  final Future<void> future;
}

// ---------------------------------------------------------------------------

/// Source of named real-time streams that [ListenerSupervisor] supervises.
///
/// A concrete implementation wraps the legacy `FirestoreDataSource.listenTo*`
/// streams (or, post-DNI-336, the gateway's `listenPage`/`listenDoc` shape)
/// and returns a `channel name → broadcast stream` map.
///
/// Implementations MUST return brand-new streams each time [openChannels] is
/// called — the supervisor uses this on `restart()` to make sure stale
/// subscriptions cannot survive across reconnects.
abstract class ListenerSource {
  Map<String, Stream<Object?>> openChannels();
}

typedef ListenerEventHandler = void Function(String channel, Object? payload);

typedef ListenerErrorHandler =
    void Function(String channel, Object error, StackTrace stackTrace);

/// Triggered when a listener snapshot saturates its page-size limit.
///
/// The orchestrator wires one [RecoveryPullTrigger] per collection into the
/// supervisor; on an at-limit snapshot the supervisor invokes the matching
/// trigger (throttled to one call per minute per collection) so the pull
/// pipeline reconciles any older changes the listener window did not cover.
typedef RecoveryPullTrigger = Future<void> Function();

/// Hook fired for the first 10 snapshots per supervisor lifetime so the
/// orchestrator can log [LogEvents.sync.listenerSnapshotSize] without the
/// supervisor needing to know about logging. Receives the channel name, the
/// emitted row count, and whether the snapshot was at-limit.
typedef SnapshotTelemetry =
    void Function(String channel, int size, bool isAtLimit);

/// Owns Firestore real-time listener subscriptions on behalf of the sync
/// subsystem (NFR20: extracted from `sync_engine.dart` so listener wiring is
/// testable in isolation).
///
/// Public verbs:
///
/// * [start]   — open every channel exposed by the [ListenerSource] and pipe
///               each event to [onEvent]. Idempotent: calling `start()` twice
///               does not double-subscribe.
/// * [stop]    — cancel every active subscription and clear internal state.
///               Safe to call when nothing is attached.
/// * [restart] — equivalent to `stop()` followed by `start()`, but awaits the
///               full cancellation before reattaching. This is the critical
///               correctness contract for the "device went offline and back
///               online" path: a single upstream emission still produces
///               exactly one delivery to [onEvent], never two (DNI-335 AC4).
/// * [park]    — Phase 2 sync-architecture-plan: cancel every active
///               subscription but remember that the supervisor was "live"
///               (so a subsequent [unpark] re-opens the channels). Used by
///               the lifecycle observer after 60 s in background: detaches
///               every gRPC stream while the app sleeps, eliminating the
///               idle-listener Firestore read bill (B.5 / B.6 targets).
/// * [unpark]  — reopen channels after a [park]. Idempotent if the supervisor
///               is already attached.
///
/// ### Restart serialization guarantee (L1)
///
/// [restart] is **serialized and coalesced**. Concurrent or rapidly-repeated
/// `restart()` calls never produce overlapping `stop()`/`start()` cycles:
///
/// * If no restart is running, the call performs one `stop()`+`start()` cycle.
/// * If a restart is already running, the call does **not** start a second
///   cycle — it sets a "rerun requested" flag and the in-flight cycle, on
///   completion, runs exactly one more cycle to pick up the latest state.
///
/// A burst of `restart()` calls therefore collapses to: the current cycle, then
/// at most one final cycle. Because [ListenerSource.openChannels] resolves the
/// active profile and gateway lazily, that final cycle always rebinds to the
/// LATEST profile — intermediate profiles need not be opened. The post-condition
/// after any burst settles: exactly ONE subscription set is live, it targets the
/// latest profile, and no subscription is leaked or stranded on a stale profile.
class ListenerSupervisor {
  ListenerSupervisor({
    required ListenerSource source,
    required ListenerEventHandler onEvent,
    ListenerErrorHandler? onError,
    Map<String, RecoveryPullTrigger>? recoveryPullTriggers,
    SnapshotTelemetry? snapshotTelemetry,
  }) : _source = source,
       _onEvent = onEvent,
       _onError = onError,
       _recoveryPullTriggers = recoveryPullTriggers ?? const {},
       _snapshotTelemetry = snapshotTelemetry;

  final ListenerSource _source;
  final ListenerEventHandler _onEvent;
  final ListenerErrorHandler? _onError;

  /// Per-collection recovery-pull triggers. The supervisor invokes the
  /// matching trigger when a snapshot returns `isAtLimit == true`, throttled
  /// to at most one invocation per minute per collection.
  final Map<String, RecoveryPullTrigger> _recoveryPullTriggers;

  /// Optional snapshot-size telemetry callback. Invoked for the first 10
  /// snapshots per supervisor lifetime; afterwards becomes a no-op to avoid
  /// log spam.
  final SnapshotTelemetry? _snapshotTelemetry;

  /// Last time a recovery pull fired for each collection. Throttle window =
  /// 1 minute; a second at-limit snapshot inside the window is ignored.
  final Map<String, DateTime> _lastRecoveryPull = {};

  /// Total snapshots seen so far in this supervisor lifetime. Used to gate
  /// telemetry to the first 10 snapshots.
  int _telemetryCounter = 0;

  /// Maximum snapshots to fire telemetry for, per supervisor lifetime.
  static const int maxTelemetrySnapshots = 10;

  /// Throttle window for per-collection recovery pulls. A second at-limit
  /// snapshot inside this window is dropped.
  static const Duration recoveryPullThrottle = Duration(minutes: 1);

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _attached = false;

  /// True after [park] is called — the supervisor remembers it should be
  /// alive (so a subsequent [unpark] reopens channels). False after [stop]
  /// or before [start].
  bool _parked = false;

  /// Current restart-cycle state — idle, restarting, or restarting-with-pending.
  ///
  /// See [_RestartCycle] for the full state diagram. The sealed union replaces
  /// the two-field pattern (_restartInFlight: Future? + _rerunRequested: bool)
  /// that previously encoded the same three states as two independent booleans.
  _RestartCycle _restartCycle = const _RestartIdle();

  /// Whether the supervisor currently holds active subscriptions.
  bool get isAttached => _attached;

  /// Whether the supervisor is in the "parked" state (no active subscriptions
  /// but a subsequent [unpark] should re-open them).
  bool get isParked => _parked;

  Future<void> start() async {
    if (_attached) return;
    _attached = true;
    _parked = false;

    final channels = _source.openChannels();
    for (final entry in channels.entries) {
      final channel = entry.key;
      final sub = entry.value.listen(
        (payload) => _handlePayload(channel, payload),
        onError: (Object error, StackTrace stackTrace) {
          _onError?.call(channel, error, stackTrace);
        },
      );
      _subscriptions.add(sub);
    }
  }

  Future<void> stop() async {
    _parked = false;
    if (!_attached && _subscriptions.isEmpty) return;
    _attached = false;
    final subs = List<StreamSubscription<Object?>>.from(_subscriptions);
    _subscriptions.clear();
    await Future.wait(subs.map((s) => s.cancel()));
  }

  /// Cancel every subscription but remember the supervisor was "live" so
  /// [unpark] can re-open the channels.
  ///
  /// Phase 2 sync-architecture-plan: paired with the lifecycle observer's
  /// 60 s background timer. Detaching gRPC streams while backgrounded
  /// eliminates the idle-listener Firestore read bill and avoids keeping
  /// the network channel alive past Doze maintenance windows.
  ///
  /// Idempotent: calling [park] twice without an intervening [unpark] is a
  /// no-op the second time.
  Future<void> park() async {
    if (!_attached) {
      // Either never started, already stopped, or already parked. Set the
      // parked flag so a future unpark() still re-opens — but only if the
      // supervisor was actually started at some point in this lifetime.
      // If _attached is false and _parked is false, the supervisor was never
      // started; park() is a no-op.
      if (_subscriptions.isEmpty && !_parked) return;
      // Already parked.
      return;
    }
    _attached = false;
    _parked = true;
    final subs = List<StreamSubscription<Object?>>.from(_subscriptions);
    _subscriptions.clear();
    await Future.wait(subs.map((s) => s.cancel()));
  }

  /// Re-open channels after a [park]. No-op when the supervisor is already
  /// attached. If the supervisor was [stop]ped (not parked), this is also a
  /// no-op — the caller must use [start] for a fresh start.
  Future<void> unpark() async {
    if (_attached) return;
    if (!_parked) return;
    // start() flips _parked → false on a clean start.
    await start();
  }

  /// Re-open the supervised channels, serialized and coalesced (L1).
  ///
  /// See the class doc comment for the full guarantee. The returned future
  /// completes once the restart this call is responsible for has finished: when
  /// no cycle is running, that is this call's own cycle; when a cycle is already
  /// running, this call is coalesced into the running cycle's mandatory rerun,
  /// so the returned future completes once that rerun has finished.
  Future<void> restart() {
    final cycle = _restartCycle;
    switch (cycle) {
      case _Restarting(:final future):
        // A cycle is already running. Do not start a second, overlapping
        // stop()/start() — upgrade the state to signal that an extra iteration
        // is needed. openChannels() resolves the profile lazily, so the extra
        // iteration rebinds to the latest profile regardless of how many
        // restart() calls were coalesced.
        _restartCycle = _RestartingPending(future: future);
        return future;
      case _RestartingPending(:final future):
        // Already queued for a rerun — no further action needed; coalesce.
        return future;
      case _RestartIdle():
        // No cycle running — start one now and record the Future so concurrent
        // calls coalesce onto it.
        final newFuture = _runRestartCycle();
        _restartCycle = _Restarting(future: newFuture);
        return newFuture;
    }
  }

  /// Runs `stop()`+`start()` cycles back-to-back until no extra rerun is
  /// pending, then transitions [_restartCycle] back to [_RestartIdle]. Exactly
  /// one cycle is ever live at a time, so no two subscription sets coexist.
  Future<void> _runRestartCycle() async {
    try {
      do {
        // Demote from _RestartingPending → _Restarting (with same future) to
        // consume the pending flag. Any restart() that arrives during this
        // stop()+start() will re-upgrade to _RestartingPending, causing the
        // loop to run one more iteration.
        if (_restartCycle case _RestartingPending(:final future)) {
          _restartCycle = _Restarting(future: future);
        }
        await stop();
        await start();
        // If another restart() arrived during stop()/start() the state is now
        // _RestartingPending — loop once more to serve the latest profile.
      } while (_restartCycle is _RestartingPending);
    } finally {
      _restartCycle = const _RestartIdle();
    }
  }

  // ── Payload handling ──────────────────────────────────────────────────────

  /// Process a single payload from one of the source channels.
  ///
  /// The gateway emits two payload shapes:
  /// 1. [ListenerSnapshot] from `listenToCollection` / `listenToLearnerProfiles`
  ///    / `listenToTutorGrants` — carries `rows` and `isAtLimit`.
  /// 2. `Map<String, dynamic>?` from `listenToDocument` — single-doc updates
  ///    for preference docs.
  ///
  /// For [ListenerSnapshot] payloads, the supervisor:
  ///   - forwards `rows` to [_onEvent],
  ///   - fires the optional [_snapshotTelemetry] callback for the first
  ///     [maxTelemetrySnapshots] snapshots per lifetime,
  ///   - triggers the matching recovery-pull when `isAtLimit == true`
  ///     (throttled to at most once per [recoveryPullThrottle] per channel).
  ///
  /// For document payloads, the supervisor forwards the raw map unchanged
  /// (no at-limit signal applies to single docs).
  void _handlePayload(String channel, Object? payload) {
    if (payload is ListenerSnapshot) {
      // Telemetry — first 10 snapshots per supervisor lifetime only.
      if (_telemetryCounter < maxTelemetrySnapshots) {
        _telemetryCounter += 1;
        _snapshotTelemetry?.call(
          channel,
          payload.rows.length,
          payload.isAtLimit,
        );
      }
      // Forward rows to the orchestrator.
      _onEvent(channel, payload.rows);
      // Recovery pull on overflow — throttled per channel.
      if (payload.isAtLimit) {
        _maybeTriggerRecoveryPull(channel);
      }
      return;
    }
    // listenToDocument payloads (single doc or null) — pass through.
    _onEvent(channel, payload);
  }

  /// Fire the recovery-pull trigger for [channel], if one is wired AND the
  /// per-channel throttle window has elapsed.
  void _maybeTriggerRecoveryPull(String channel) {
    final trigger = _recoveryPullTriggers[channel];
    if (trigger == null) return;
    final now = DateTimeFactory.nowUtc();
    final last = _lastRecoveryPull[channel];
    if (last != null && now.difference(last) < recoveryPullThrottle) {
      return;
    }
    _lastRecoveryPull[channel] = now;
    // Fire-and-forget; the trigger logs its own errors.
    unawaited(trigger());
  }
}
