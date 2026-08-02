/// Small, self-healing wrappers around Firestore listener streams —
/// [resilientDocStream] for a single document, [resilientQueryStream] for a
/// query's `QuerySnapshot`.
///
/// A Firestore listener stream (`DocumentReference.snapshots()` or
/// `Query.snapshots()`) is **terminal on error**: once it emits an error
/// event the stream is done and never emits again, silently leaving a
/// listening UI dark for the rest of the session. Both functions here wrap
/// the raw stream so an error instead schedules a fresh subscription after a
/// capped, jittered exponential-backoff delay — the small (tens-of-lines)
/// replacement for the deleted `ListenerSupervisor`. Deliberately NOT a
/// supervisor: no fleet of channels, no dead-channel registry, no recovery-
/// pull triggers — one stream in, one self-healing stream out. Every
/// repository with a "watch one document" or "watch a query" need should
/// call one of these rather than hand-roll its own resubscribe loop — see
/// `lib/data/repositories/firestore_bookmark_repository.dart` (doc) and
/// `lib/data/repositories/firestore_stage_definition_repository.dart`
/// (query) for the reference callers.
///
/// Both share the exact same backoff/lifecycle skeleton
/// ([_resilientStream]) — attempt counting, capped jittered delay,
/// lazy-subscribe-on-first-listen, teardown-on-last-cancel — parameterized
/// only by what happens to one incoming snapshot. Factored once they turned
/// out to be byte-for-byte identical outside that one piece; if a future
/// change makes them diverge further, split them back out rather than
/// bending the shared skeleton to fit a third shape.
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
///   transient failure), and a fresh subscription is scheduled after a
///   capped, jittered backoff delay. The attempt counter resets to zero
///   the moment a subsequent snapshot arrives successfully.
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
  return _resilientStream<T, DocumentSnapshot<Map<String, dynamic>>>(
    openStream: openStream,
    onSnapshot: (snapshot, emit, emitError) {
      try {
        emit(decode(snapshot));
      } catch (error, stackTrace) {
        emitError(error, stackTrace);
      }
    },
    backoffBase: backoffBase,
    backoffCap: backoffCap,
    jitter: jitter,
    random: random,
    onError: onError,
  );
}

/// Subscribes to the query-snapshot stream [openStream] returns, decoding
/// every document in each snapshot via [decode] into the returned broadcast
/// [Stream] of lists.
///
/// Same resubscribe-with-backoff contract as [resilientDocStream] for a
/// stream-level error — see that function's doc comment.
///
/// **Deliberately different from [resilientDocStream] on a decode failure.**
/// [resilientDocStream] wraps ONE document, so a decode failure means there
/// is nothing valid to emit for that event. A query snapshot wraps MANY
/// documents: dropping the whole list because one row is malformed would
/// blank an entire screen (e.g. every other stage definition, every other
/// goal) over a single corrupt document. Instead, each document is decoded
/// independently — a document whose [decode] throws is *skipped* (forwarded
/// via `addError` so a caller can still surface a "some items didn't load"
/// signal out-of-band) while every other document in the same snapshot
/// still decodes and is included in the emitted list. No resubscribe is
/// scheduled for a decode failure either way, for the same reason as
/// [resilientDocStream]: the subscription itself is healthy.
Stream<List<T>> resilientQueryStream<T>({
  required Stream<QuerySnapshot<Map<String, dynamic>>> Function() openStream,
  required T Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) decode,
  Duration backoffBase = const Duration(seconds: 1),
  Duration backoffCap = const Duration(seconds: 30),
  double jitter = 0.2,
  math.Random? random,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  return _resilientStream<List<T>, QuerySnapshot<Map<String, dynamic>>>(
    openStream: openStream,
    onSnapshot: (snapshot, emit, emitError) {
      final results = <T>[];
      for (final doc in snapshot.docs) {
        try {
          results.add(decode(doc));
        } catch (error, stackTrace) {
          emitError(error, stackTrace);
        }
      }
      emit(results);
    },
    backoffBase: backoffBase,
    backoffCap: backoffCap,
    jitter: jitter,
    random: random,
    onError: onError,
  );
}

/// The shared resubscribe-with-backoff skeleton behind both
/// [resilientDocStream] and [resilientQueryStream]. [S] is the raw snapshot
/// type (`DocumentSnapshot<Map<String, dynamic>>` or
/// `QuerySnapshot<Map<String, dynamic>>`); [T] is whatever the caller's
/// [onSnapshot] callback emits for one such snapshot (a single decoded value,
/// or a decoded list — [onSnapshot] owns that decision entirely; this
/// function only owns "is the subscription itself alive").
Stream<T> _resilientStream<T, S>({
  required Stream<S> Function() openStream,
  required void Function(
    S snapshot,
    void Function(T value) emit,
    void Function(Object error, StackTrace stackTrace) emitError,
  )
  onSnapshot,
  required Duration backoffBase,
  required Duration backoffCap,
  required double jitter,
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
  StreamSubscription<S>? subscription;
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
        onSnapshot(snapshot, controller.add, controller.addError);
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
