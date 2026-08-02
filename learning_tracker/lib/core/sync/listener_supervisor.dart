import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
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
/// called — the supervisor uses this on `restart()` (and, per Story 1.1, on a
/// single-channel resubscribe-on-error) to make sure stale subscriptions
/// cannot survive across reconnects.
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
///
/// ### Per-channel resubscribe-on-error (Story 1.1 / AD-9 / R-1)
///
/// A Firestore `.snapshots()` stream is terminal on error: once a channel's
/// `onError` fires, that channel's underlying stream will never emit again.
/// [ListenerSupervisor] therefore treats a channel error as a **per-channel**
/// event, not a whole-supervisor one:
///
/// * The failed channel is marked dead ([deadChannels]) and its subscription
///   is dropped. Every sibling channel's subscription is left completely
///   untouched — one channel's failure never tears down the fleet.
/// * A bounded-exponential-backoff, jittered resubscribe of ONLY that channel
///   is scheduled (see [computeBackoffDelay]). At the backoff cap the
///   supervisor keeps retrying forever — there is no permanent give-up and no
///   resting "exhausted" state (AD-9).
/// * While a channel is dead, it is exposed via [deadChannels] /
///   [deadChannelsChanges] as an in-flight/unsettled signal the sync status
///   layer (Story 1.5) can read so a still-dead channel is never reported as
///   settled/`synced`.
/// * A channel that errors while the supervisor is [park]ed (or already
///   [stop]ped) is marked dead but does **not** schedule a resubscribe timer;
///   the next [unpark]/[start] reopens every channel, including it.
/// * Double-attach guard: every full-fleet operation ([start], [stop],
///   [park], and therefore [restart]) bumps an internal generation counter
///   and synchronously cancels any pending per-channel resubscribe timers
///   *before* tearing down subscriptions. A resubscribe timer that is racing
///   a concurrent `restart()`/`unpark()` is therefore either cancelled
///   outright or, if it already fired, discovers a stale generation and
///   becomes a no-op — so a burst of "channel error" + "restart()" never
///   produces two live subscriptions for the same channel (reusing the same
///   coalescing discipline as [restart]'s [_RestartCycle] state machine).
class ListenerSupervisor {
  ListenerSupervisor({
    required ListenerSource source,
    required ListenerEventHandler onEvent,
    ListenerErrorHandler? onError,
    Map<String, RecoveryPullTrigger>? recoveryPullTriggers,
    SnapshotTelemetry? snapshotTelemetry,
    // Story 1.1 — per-channel resubscribe-on-error backoff schedule.
    // Overridable so tests can shrink real-time waits to milliseconds; the
    // production defaults keep a dead channel retrying at a human-scale
    // cadence without hammering the backend.
    Duration resubscribeBackoffBase = const Duration(seconds: 1),
    Duration resubscribeBackoffCap = const Duration(seconds: 30),
    double resubscribeBackoffJitter = 0.2,
    math.Random? random,
  }) : _source = source,
       _onEvent = onEvent,
       _onError = onError,
       _recoveryPullTriggers = recoveryPullTriggers ?? const {},
       _snapshotTelemetry = snapshotTelemetry,
       _resubscribeBackoffBase = resubscribeBackoffBase,
       _resubscribeBackoffCap = resubscribeBackoffCap,
       _resubscribeBackoffJitter = resubscribeBackoffJitter,
       _random = random ?? math.Random();

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

  /// Live subscriptions keyed by channel name. A Map (rather than a bare
  /// List) lets a per-channel error/resubscribe replace exactly one entry
  /// without disturbing the rest of the fleet.
  final Map<String, StreamSubscription<Object?>> _subscriptions = {};
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

  // ── Story 1.1 — per-channel resubscribe-on-error state ───────────────────

  /// Base delay for a channel's first backoff resubscribe attempt.
  final Duration _resubscribeBackoffBase;

  /// Hard ceiling on the per-channel backoff delay. AD-9: the supervisor
  /// never permanently gives up on a dead channel while connectivity is up —
  /// it degrades to "retrying at the cap" forever, and this is the cap.
  final Duration _resubscribeBackoffCap;

  /// Jitter fraction applied to the computed backoff delay (e.g. 0.2 == ±20%)
  /// so a fleet of devices that all errored at once (a shared App-Check
  /// outage) do not all retry in lockstep.
  final double _resubscribeBackoffJitter;

  /// Source of randomness for the backoff jitter. Injectable so tests can
  /// pin a seeded [math.Random] and assert exact bounds deterministically.
  final math.Random _random;

  /// Channels currently dead — errored and either awaiting their next backoff
  /// resubscribe attempt or (while parked/stopped) awaiting the next
  /// [unpark]/[start]. Sibling channels not in this set are unaffected by any
  /// one channel's failure.
  final Set<String> _deadChannels = {};

  /// Consecutive resubscribe attempts per channel, used to compute the next
  /// backoff delay. Reset to "no entry" the moment a channel resubscribes
  /// successfully or the whole fleet is rebuilt via [start]/[stop]/[park].
  final Map<String, int> _resubscribeAttempts = {};

  /// The in-flight backoff [Timer] per dead channel, if any. Tracked so a
  /// concurrent full-fleet operation ([start], [stop], [park]) can cancel it
  /// outright instead of relying solely on the generation check — this is
  /// the primary double-attach guard (Dart timers only fire on a later event
  /// loop turn, so cancelling synchronously here means a superseded timer
  /// never runs at all).
  final Map<String, Timer> _pendingResubscribeTimers = {};

  /// Bumped on every [start], [stop], and [park] call. A per-channel
  /// resubscribe timer captures the generation at schedule time and no-ops if
  /// the generation has since moved on — belt-and-suspenders alongside the
  /// timer cancellation above.
  int _generation = 0;

  /// Broadcasts the updated [deadChannels] set whenever a channel goes dead
  /// or recovers. Consumed by the sync-status layer (Story 1.5) so a
  /// still-dead, still-retrying channel can be surfaced as `syncing`
  /// (in-flight/unsettled) rather than falsely `synced`.
  final StreamController<Set<String>> _deadChannelsController =
      StreamController<Set<String>>.broadcast();

  /// Whether the supervisor currently holds active subscriptions.
  bool get isAttached => _attached;

  /// Whether the supervisor is in the "parked" state (no active subscriptions
  /// but a subsequent [unpark] should re-open them).
  bool get isParked => _parked;

  /// Channels that are currently dead — errored and mid-backoff (or, while
  /// parked/stopped, awaiting the next [unpark]/[start]). Empty when every
  /// channel is healthy. Exposed for the orchestrator/status layer (Story
  /// 1.5); this supervisor does not interpret the set itself.
  Set<String> get deadChannels => Set.unmodifiable(_deadChannels);

  /// Emits the updated [deadChannels] set every time it changes. Broadcast —
  /// safe for multiple subscribers.
  Stream<Set<String>> get deadChannelsChanges => _deadChannelsController.stream;

  Future<void> start() async {
    if (_attached) return;
    _attached = true;
    _parked = false;
    _generation += 1;
    final generation = _generation;
    // A fresh start supersedes any earlier per-channel backoff bookkeeping —
    // every channel below gets a brand-new subscription, so nothing is dead
    // and no channel-specific timer/attempt-count should survive.
    _cancelPendingResubscribes();
    _resubscribeAttempts.clear();
    _clearDeadChannels();

    final channels = _source.openChannels();
    for (final entry in channels.entries) {
      _attachChannel(entry.key, entry.value, generation);
    }
  }

  Future<void> stop() async {
    _parked = false;
    _generation += 1;
    _cancelPendingResubscribes();
    _resubscribeAttempts.clear();
    _clearDeadChannels();
    if (!_attached && _subscriptions.isEmpty) return;
    _attached = false;
    final subs = List<StreamSubscription<Object?>>.from(_subscriptions.values);
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
  ///
  /// Story 1.1: any pending per-channel backoff timer is cancelled too — a
  /// channel that errored and is mid-backoff must NOT resubscribe while
  /// parked. It stays in [deadChannels]; the next [unpark] (via [start])
  /// reopens it along with every other channel.
  Future<void> park() async {
    _generation += 1;
    _cancelPendingResubscribes();
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
    final subs = List<StreamSubscription<Object?>>.from(_subscriptions.values);
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

  // ── Story 1.1 — per-channel resubscribe-on-error ──────────────────────────

  /// Subscribe to [stream] for [channel], wiring both the normal payload path
  /// and the per-channel error handler. Used by both [start] (bulk, one call
  /// per channel in the freshly-opened set) and [_resubscribeChannel] (a
  /// single channel healing after backoff).
  ///
  /// The analyzer's `cancel_subscriptions` check cannot see that [sub] is
  /// stored into `_subscriptions` (an instance field) and cancelled from
  /// [stop]/[park]/[_markChannelDead] once this local variable's scope ends
  /// — it is a false positive, same class of finding the test doubles in
  /// `test/sync/*.dart` already suppress file-wide for the same reason.
  void _attachChannel(String channel, Stream<Object?> stream, int generation) {
    // ignore: cancel_subscriptions
    final sub = stream.listen(
      (payload) => _handlePayload(channel, payload),
      onError: (Object error, StackTrace stackTrace) {
        _handleChannelError(channel, error, stackTrace, generation);
      },
    );
    _subscriptions[channel] = sub;
  }

  /// A single channel's `.snapshots()` stream emitted an error. Firestore
  /// streams are terminal-on-error, so this channel will never emit again on
  /// its own — mark it dead and, unless the supervisor is parked/stopped,
  /// schedule a bounded-exponential-backoff resubscribe of ONLY this channel.
  /// Sibling channels are never touched.
  void _handleChannelError(
    String channel,
    Object error,
    StackTrace stackTrace,
    int generation,
  ) {
    _onError?.call(channel, error, stackTrace);
    if (generation != _generation) {
      // A full-fleet start()/stop()/park() has already superseded the
      // subscription this error came from; that operation's own bookkeeping
      // owns this channel now.
      return;
    }
    _markChannelDead(channel);
    if (!_attached || _parked) {
      // Parked or stopped: do not schedule a resubscribe timer. The next
      // unpark()/start() reopens every channel, including this one.
      return;
    }
    _scheduleResubscribe(channel, generation);
  }

  void _markChannelDead(String channel) {
    _subscriptions.remove(channel);
    final added = _deadChannels.add(channel);
    if (added) _notifyDeadChannelsChanged();
  }

  void _scheduleResubscribe(String channel, int generation) {
    _pendingResubscribeTimers.remove(channel)?.cancel();
    final attempt = (_resubscribeAttempts[channel] ?? 0) + 1;
    _resubscribeAttempts[channel] = attempt;
    final delay = computeBackoffDelay(attempt);
    _pendingResubscribeTimers[channel] = Timer(delay, () {
      _pendingResubscribeTimers.remove(channel);
      _resubscribeChannel(channel, generation);
    });
  }

  /// Compute the delay before the [attempt]-th resubscribe try for a dead
  /// channel.
  ///
  /// Uses capped, jittered exponential backoff — the same shape as the
  /// outbox's write-retry backoff (`OutboxProcessor._nextAttemptAt`), scaled
  /// for listener reconnects rather than write retries:
  ///   raw   = [_resubscribeBackoffBase] * 2^(attempt - 1)
  ///   delay = min(raw, [_resubscribeBackoffCap]) perturbed by
  ///           ±[_resubscribeBackoffJitter]
  ///
  /// The cap is AD-9's "no permanent give-up, no unbounded growth" rule made
  /// concrete: past the cap, every further attempt computes the same capped
  /// (jittered) delay forever — there is no resting "exhausted" state.
  ///
  /// `@visibleForTesting` so the backoff/jitter math is pinnable as a pure
  /// AD-29-tier-1 unit test without waiting on real timers.
  @visibleForTesting
  Duration computeBackoffDelay(int attempt) {
    // Clamp the exponent before computing 2^exponent. A dead channel that
    // keeps retrying at the cap for days/weeks (AD-9: no permanent give-up)
    // can drive [attempt] arbitrarily high — `math.pow(int, int)` computes in
    // fixed-width integer arithmetic and silently WRAPS on overflow (2^64 ≡ 0
    // in a 64-bit int), which would corrupt the delay back down to ~0 instead
    // of staying at the cap. Clamping to 62 keeps the exponentiation (done in
    // double precision via the `2.0` base) comfortably below any overflow
    // while `rawMs` already vastly exceeds any realistic cap, so the `min`
    // below always selects the cap regardless of how large [attempt] gets.
    final exponent = math.min(attempt - 1, 62);
    final multiplier = math.pow(2.0, exponent);
    final rawMs = _resubscribeBackoffBase.inMilliseconds * multiplier;
    // Cap before applying jitter so the jittered value never exceeds the
    // ceiling by more than the jitter band.
    final cappedMs = math.min(
      rawMs,
      _resubscribeBackoffCap.inMilliseconds.toDouble(),
    );
    // Jitter factor in [1 - jitter, 1 + jitter].
    final jitterFactor =
        1.0 + (_random.nextDouble() * 2 - 1) * _resubscribeBackoffJitter;
    final ms = (cappedMs * jitterFactor).round();
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  /// Fires when a dead channel's backoff timer elapses. Re-opens ONLY this
  /// channel (siblings' subscriptions are untouched) and, on success, clears
  /// it from [deadChannels]. If the source cannot currently open the channel
  /// (e.g. the active profile is still the "no profile" sentinel), keeps
  /// retrying at the backoff schedule rather than giving up.
  void _resubscribeChannel(String channel, int generation) {
    if (generation != _generation || !_attached || _parked) {
      // Superseded by a full start()/stop()/park() in the meantime — that
      // operation already reopened (or intentionally left closed) every
      // channel, including this one.
      return;
    }
    final channels = _source.openChannels();
    final stream = channels[channel];
    if (stream == null) {
      _scheduleResubscribe(channel, generation);
      return;
    }
    _attachChannel(channel, stream, generation);
    _resubscribeAttempts.remove(channel);
    final removed = _deadChannels.remove(channel);
    if (removed) _notifyDeadChannelsChanged();
  }

  void _cancelPendingResubscribes() {
    if (_pendingResubscribeTimers.isEmpty) return;
    for (final timer in _pendingResubscribeTimers.values) {
      timer.cancel();
    }
    _pendingResubscribeTimers.clear();
  }

  void _clearDeadChannels() {
    if (_deadChannels.isEmpty) return;
    _deadChannels.clear();
    _notifyDeadChannelsChanged();
  }

  void _notifyDeadChannelsChanged() {
    if (_deadChannelsController.isClosed) return;
    _deadChannelsController.add(Set.unmodifiable(_deadChannels));
  }

  /// Release resources held for the lifetime of this supervisor: cancels any
  /// pending backoff timer and closes [deadChannelsChanges]. Does NOT cancel
  /// live subscriptions — call [stop] first if the supervisor is still
  /// attached. Safe to call at most once; the supervisor is unusable
  /// afterwards.
  void dispose() {
    _cancelPendingResubscribes();
    if (!_deadChannelsController.isClosed) {
      unawaited(_deadChannelsController.close());
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
