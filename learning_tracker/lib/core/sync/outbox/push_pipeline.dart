/// Abstract interface for pushing local mutations to Firestore.
///
/// Each method handles one entity kind. Implemented by [OutboxPushPipeline]
/// (Story 25.12 — SyncEngine decomp Part 1).
///
/// The [OutboxProcessor] calls these methods when draining the outbox table.
/// Each method receives the raw JSON [payload] stored in the outbox row and
/// the [profileId] that owns the mutation.
abstract class PushPipeline {
  Future<void> pushCompletion({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  /// Push multiple completions in a single batched operation.
  ///
  /// Each entry in [entries] is a record of `(entityKey, payload)` so the
  /// gateway can derive the deterministic Firestore doc ID from the natural
  /// key rather than from arbitrary payload fields.
  ///
  /// Implementations must:
  ///  1. Pass all entries to [FirestoreGateway.pushCompletionsBatch].
  ///  2. Never call [pushCompletion] in a loop — that defeats the batching.
  Future<void> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  });

  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  Future<void> pushSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  Future<void> pushTrack({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  Future<void> pushLearningOrder({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  Future<void> pushBookmark({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });
}
