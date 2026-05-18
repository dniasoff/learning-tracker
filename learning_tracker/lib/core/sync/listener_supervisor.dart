import 'dart:async';

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

  /// The in-flight [restart] cycle, or null when no restart is running.
  ///
  /// Used to serialize restarts: a [restart] call that arrives while this is
  /// non-null does not start its own cycle — it sets [_rerunRequested] instead.
  Future<void>? _restartInFlight;

  /// Set by a [restart] call that arrives while a cycle is already running.
  /// The running cycle, on completion, consumes this flag and runs exactly one
  /// more cycle so the latest profile is picked up.
  bool _rerunRequested = false;

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
    final inFlight = _restartInFlight;
    if (inFlight != null) {
      // A cycle is already running. Do not start a second, overlapping
      // stop()/start() — request exactly one rerun after the current cycle.
      // openChannels() resolves the profile lazily, so the rerun rebinds to the
      // latest profile regardless of how many restart() calls were coalesced.
      _rerunRequested = true;
      return inFlight;
    }
    final cycle = _runRestartCycle();
    _restartInFlight = cycle;
    return cycle;
  }

  /// Runs `stop()`+`start()` cycles back-to-back until no rerun is pending,
  /// then clears [_restartInFlight]. Exactly one cycle is ever live at a time,
  /// so no two subscription sets coexist.
  Future<void> _runRestartCycle() async {
    try {
      do {
        _rerunRequested = false;
        await stop();
        await start();
        // A restart() that arrived during stop()/start() set _rerunRequested;
        // loop once more so the final cycle targets the latest profile.
      } while (_rerunRequested);
    } finally {
      _restartInFlight = null;
    }
  }
}
