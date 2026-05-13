/// Abstract interface for pushing local mutations to Firestore.
///
/// Each method handles one entity kind. Implementations will be wired up
/// in DNI-333 (Story 25.12 — SyncEngine decomp Part 1).
///
/// The [OutboxProcessor] calls these methods when draining the outbox table.
/// Each method receives the raw JSON [payload] stored in the outbox row and
/// the [profileId] that owns the mutation.
abstract class PushPipeline {
  /// Push a completion event to Firestore.
  // TODO(25.12): implement in FirestoreGateway
  Future<void> pushCompletion({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  /// Push a streak update to Firestore.
  // TODO(25.12): implement in FirestoreGateway
  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  /// Push a settings mutation to Firestore.
  // TODO(25.12): implement in FirestoreGateway
  Future<void> pushSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  /// Push a curriculum track change to Firestore.
  // TODO(25.12): implement in FirestoreGateway
  Future<void> pushTrack({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  /// Push a learning-order change to Firestore.
  // TODO(25.12): implement in FirestoreGateway
  Future<void> pushLearningOrder({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  /// Push a bookmark change to Firestore.
  // TODO(25.12): implement in FirestoreGateway
  Future<void> pushBookmark({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });
}
