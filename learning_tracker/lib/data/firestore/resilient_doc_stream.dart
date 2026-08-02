/// A small, self-healing wrapper around a single Firestore document's
/// `snapshots()` stream.
///
/// `DocumentReference.snapshots()` — like every Firestore listener stream —
/// is **terminal on error**: once it emits an error event the stream is
/// done and never emits again, silently leaving a listening UI dark for
/// the rest of the session. [resilientDocStream] wraps one document's
/// stream so an error instead schedules a fresh subscription after a
/// capped, jittered exponential-backoff delay — the small (tens-of-lines)
/// replacement for the deleted `ListenerSupervisor`. Deliberately NOT a
/// supervisor: no fleet of channels, no dead-channel registry, no recovery-
/// pull triggers — one document in, one self-healing stream out. Every
/// repository with a "watch one document" need should call this rather
/// than hand-roll its own resubscribe loop — see
/// `lib/data/repositories/firestore_bookmark_repository.dart` for the
/// reference caller.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscribes to the stream [openStream] returns, decoding each snapshot
/// via [decode] into the returned broadcast [Stream].
///
/// [openStream] is a factory (not a `DocumentReference` directly) so a
/// resubscribe attempt opens a genuinely fresh subscription, and so tests
/// can inject a stream that errors on its first call and succeeds on a
/// later one without needing a real flaky Firestore connection.
///
/// **Two different kinds of failure, handled differently:**
/// - A stream-level error (permission-denied, unavailable, the terminal
///   error `snapshots()` itself raises) means the *subscription* is dead:
///   [onError] (if given) is called, the error is forwarded to the
///   returned stream via `addError` (so a caller can still observe the
///   transient failure), and a fresh subscription is scheduled after
///   [nextBackoffDelay]. The attempt counter resets to zero the moment a
///   subsequent snapshot arrives successfully.
/// - A [decode] failure (a malformed document) does NOT indicate the
///   underlying subscription is unhealthy — resubscribing would just hit
///   the same bad document again — so it is forwarded via `addError` only,
///   with no resubscribe scheduled.
///
/// The underlying subscription is lazy: [openStream] is only called once
/// the returned stream gets its first listener
/// ([StreamController.onListen]), and is torn down — cancelling both the
/// live subscription and any pending backoff timer — once the last
/// listener cancels ([StreamController.onCancel]).
Stream<T> resilientDocStream<T>({
  required Stream<DocumentSnapshot<Map<String, dynamic>>> Function() openStream,
  required T Function(DocumentSnapshot<Map<String, dynamic>> snapshot) decode,
  Duration backoffBase = const Duration(seconds: 1),
  Duration backoffCap = const Duration(seconds: 30),
  double jitter = 0.2,
  math.Random? random,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  final rng = random ?? math.Random();
  // This controller is deliberately never `.close()`d. It models a "live
  // while listened to" stream, the same as `snapshots()` itself: the
  // resource that actually needs releasing on teardown is the upstream
  // subscription + pending backoff timer, both of which `onCancel` (below)
  // already tears down. There is no owning object with a lifecycle to hang
  // a `.close()` call off — this bare `StreamController` becomes eligible
  // for GC once its returned `Stream` has no more references, same as any
  // other hot/broadcast stream factory with no explicit "done" signal.
  // ignore: close_sinks
  late final StreamController<T> controller;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
  Timer? pendingResubscribe;
  var attempt = 0;

  Duration nextBackoffDelay() {
    // `attempt` is 1-indexed by the time this is called (incremented right
    // before scheduling) — mirrors `ListenerSupervisor.computeBackoffDelay`'s
    // `base * 2^(attempt - 1)` shape, so the first retry waits ~[backoffBase],
    // not ~2×it. Clamped well below where `2^exponent` could ever approach
    // overflow — the cap is reached in a handful of doublings regardless.
    final exponent = (attempt - 1).clamp(0, 20);
    final rawMs = backoffBase.inMilliseconds * math.pow(2, exponent);
    final cappedMs = math.min(
      rawMs.toDouble(),
      backoffCap.inMilliseconds.toDouble(),
    );
    final jitterFactor = 1 + (rng.nextDouble() * 2 - 1) * jitter;
    return Duration(milliseconds: (cappedMs * jitterFactor).round());
  }

  void subscribe() {
    subscription = openStream().listen(
      (snapshot) {
        attempt = 0;
        try {
          controller.add(decode(snapshot));
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        onError?.call(error, stackTrace);
        controller.addError(error, stackTrace);
        attempt += 1;
        pendingResubscribe = Timer(nextBackoffDelay(), subscribe);
      },
    );
  }

  controller = StreamController<T>.broadcast(
    onListen: subscribe,
    onCancel: () {
      pendingResubscribe?.cancel();
      pendingResubscribe = null;
      attempt = 0;
      unawaited(subscription?.cancel());
      subscription = null;
    },
  );

  return controller.stream;
}
