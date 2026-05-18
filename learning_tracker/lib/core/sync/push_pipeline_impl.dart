import 'dart:async';

import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';

/// Concrete [PushPipeline] that dispatches to a [FirestoreGateway].
///
/// **Single-flight per entity kind.** Concurrent `push*` calls for the same
/// kind (e.g. two `pushCompletion` invocations) are serialized via an
/// in-flight future map keyed by [OutboxEntityKind]. Different kinds run in
/// parallel — completions do not block streaks. The single-flight slot is
/// released whether the underlying push succeeds or throws, so a failure
/// does not deadlock subsequent pushes.
class OutboxPushPipeline implements PushPipeline {
  OutboxPushPipeline({required FirestoreGateway gateway}) : _gateway = gateway;

  final FirestoreGateway _gateway;

  /// Most-recent in-flight future per entity kind. New pushes await this
  /// before starting, then replace it with their own future.
  final Map<String, Future<void>> _inFlight = {};

  @override
  Future<void> pushCompletion({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) => _run(
    OutboxEntityKind.completion,
    // The completion doc ID is derived inside the gateway from the payload's
    // structured natural key — the outbox entityKey is a local-only dedup key
    // and is NOT threaded as the Firestore doc ID (H2).
    () => _gateway.pushCompletion(profileId: profileId, data: payload),
  );

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) => _runValue(
    OutboxEntityKind.completion,
    // Pass the (entityKey, payload) records straight through — the gateway
    // derives each doc ID from the payload and reports committed entityKeys.
    () => _gateway.pushCompletionsBatch(profileId: profileId, items: entries),
  );

  @override
  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) => _run(
    OutboxEntityKind.streak,
    () => _gateway.pushStreak(profileId: profileId, data: payload),
  );

  @override
  Future<void> pushSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) => _run(
    OutboxEntityKind.settings,
    () => _gateway.pushSettings(profileId: profileId, data: payload),
  );

  @override
  Future<void> pushTrack({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) => _run(
    OutboxEntityKind.track,
    () => _gateway.pushTrack(profileId: profileId, data: payload),
  );

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) => _run(
    OutboxEntityKind.learningOrder,
    () => _gateway.pushLearningOrder(profileId: profileId, data: payload),
  );

  @override
  Future<void> pushBookmark({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) => _run(
    OutboxEntityKind.bookmark,
    () => _gateway.pushBookmark(profileId: profileId, data: payload),
  );

  /// Serialize calls per [kind]: wait on any prior in-flight future, then
  /// run [action]. The slot is cleared after the action completes so
  /// failures don't deadlock the chain.
  Future<void> _run(String kind, Future<void> Function() action) =>
      _runValue<void>(kind, action);

  /// Value-returning variant of [_run]. Serializes per [kind] exactly like
  /// [_run] and propagates [action]'s return value to the caller.
  ///
  /// The [_inFlight] slot stores a `Future<void>` *shadow* of our value-future
  /// (so the map can hold every kind regardless of return type). We keep a
  /// reference to that exact shadow and only clear the slot when it is still
  /// the one we installed — guaranteeing a later call that chained ahead is
  /// not evicted.
  Future<T> _runValue<T>(String kind, Future<T> Function() action) {
    final prior = _inFlight[kind];
    late final Future<void> ourSlot;
    final result = () async {
      if (prior != null) {
        // Swallow prior error here — the original caller already saw it.
        await prior.then<void>((_) {}, onError: (Object _) {});
      }
      try {
        return await action();
      } finally {
        // Clear the slot only if no later call replaced it.
        if (identical(_inFlight[kind], ourSlot)) {
          final removed = _inFlight.remove(kind);
          if (removed != null) unawaited(removed.catchError((_) {}));
        }
      }
    }();
    ourSlot = result.then<void>((_) {}, onError: (Object _) {});
    _inFlight[kind] = ourSlot;
    return result;
  }
}
