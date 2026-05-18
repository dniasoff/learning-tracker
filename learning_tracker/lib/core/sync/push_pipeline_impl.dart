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
    // Thread the entityKey as the deterministic Firestore doc ID so every
    // re-push resolves to the same document (RC3 fix).  The entityKey format
    // is "<profileId>:<sefariaRef>:<stageId>:<trackType>" — sanitized inside
    // FirestoreGatewayImpl._completionDocId before use.
    () => _gateway.pushCompletion(
      profileId: profileId,
      data: payload,
      docId: entityKey,
    ),
  );

  @override
  Future<void> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) => _run(
    OutboxEntityKind.completion,
    () => _gateway.pushCompletionsBatch(
      profileId: profileId,
      items: entries.map((e) => {...e.payload, '_entityKey': e.entityKey}).toList(),
    ),
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
  Future<void> _run(String kind, Future<void> Function() action) {
    final prior = _inFlight[kind];
    late final Future<void> ours;
    ours = _chain(
      kind: kind,
      prior: prior,
      action: action,
      ourFuture: () => ours,
    );
    _inFlight[kind] = ours;
    return ours;
  }

  Future<void> _chain({
    required String kind,
    required Future<void>? prior,
    required Future<void> Function() action,
    required Future<void> Function() ourFuture,
  }) async {
    if (prior != null) {
      // Swallow prior error here — the original caller already saw it.
      await prior.then<void>((_) {}, onError: (Object _) {});
    }
    try {
      await action();
    } finally {
      // Only clear the slot if it still points at *our* future. Another
      // call may have already chained ahead and replaced it.
      if (identical(_inFlight[kind], ourFuture())) {
        final removed = _inFlight.remove(kind);
        if (removed != null) unawaited(removed.catchError((_) {}));
      }
    }
  }
}
