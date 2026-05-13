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

  Future<void> restart() async {
    await stop();
    await start();
  }
}
