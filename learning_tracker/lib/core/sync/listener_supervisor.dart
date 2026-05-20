import 'dart:async';

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

/// Owns Firestore real-time listener subscriptions on behalf of the sync
/// subsystem (NFR20: extracted from `sync_engine.dart` so listener wiring is
/// testable in isolation).
///
/// Three public verbs:
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
  }) : _source = source,
       _onEvent = onEvent,
       _onError = onError;

  final ListenerSource _source;
  final ListenerEventHandler _onEvent;
  final ListenerErrorHandler? _onError;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _attached = false;

  /// Current restart-cycle state — idle, restarting, or restarting-with-pending.
  ///
  /// See [_RestartCycle] for the full state diagram. The sealed union replaces
  /// the two-field pattern (_restartInFlight: Future? + _rerunRequested: bool)
  /// that previously encoded the same three states as two independent booleans.
  _RestartCycle _restartCycle = const _RestartIdle();

  /// Whether the supervisor currently holds active subscriptions.
  bool get isAttached => _attached;

  Future<void> start() async {
    if (_attached) return;
    _attached = true;

    final channels = _source.openChannels();
    for (final entry in channels.entries) {
      final channel = entry.key;
      final sub = entry.value.listen(
        (payload) => _onEvent(channel, payload),
        onError: (Object error, StackTrace stackTrace) {
          _onError?.call(channel, error, stackTrace);
        },
      );
      _subscriptions.add(sub);
    }
  }

  Future<void> stop() async {
    if (!_attached && _subscriptions.isEmpty) return;
    _attached = false;
    final subs = List<StreamSubscription<Object?>>.from(_subscriptions);
    _subscriptions.clear();
    await Future.wait(subs.map((s) => s.cancel()));
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
}
