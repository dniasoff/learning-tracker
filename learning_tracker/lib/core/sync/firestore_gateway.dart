/// Firestore I/O facade.
///
/// `FirestoreGateway` is the public seam between the rest of the sync
/// subsystem and Firestore. Concrete implementations encapsulate
/// `package:cloud_firestore/cloud_firestore.dart`; everything else in `lib/`
/// goes through this interface, so Firestore types never leak across the
/// boundary. (See `core/sync/firestore_gateway_impl.dart` for the only
/// allowed importer of `cloud_firestore`.)
///
/// Methods come in two families:
///   * `push*` — write a single mutation document for an entity kind.
///   * `fetchPage` — paginated read for a collection, used by [PullPipeline].
abstract class FirestoreGateway {
  /// Push a single completion document.
  ///
  /// The Firestore document ID is always derived from the completion's
  /// structured natural key (`profile_id`, `sefaria_ref`, `stage_id`,
  /// `track_type`) — the [docId] parameter is **ignored for completions** and
  /// retained only for non-completion callers that pass an explicit ID.
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
    String? docId,
  });

  /// Push multiple completions using Firestore [WriteBatch]es and report which
  /// entries genuinely committed.
  ///
  /// Each entry carries the outbox `entityKey` (a local-only dedup key) and
  /// the snake_case `payload`. The Firestore document ID is derived solely
  /// from the payload's structured natural key — never from the entityKey.
  ///
  /// Payloads are chunked into batches of ≤500 ops (Firestore limit) and each
  /// chunk is committed with a single `WriteBatch.commit()` call — producing
  /// ≤⌈entries.length/500⌉ commits. This method never calls `collection.add()`;
  /// every write is a `doc(deterministicId).set(...)`, so the operation is
  /// fully idempotent.
  ///
  /// **Return value / partial-failure contract.** On full success the returned
  /// list contains every entityKey. Chunks commit sequentially; if a later
  /// chunk throws, the chunks that already committed are durable. Rather than
  /// discard that fact by simply rethrowing, the implementation throws a
  /// [BatchPushException] whose `committed` field lists the entityKeys of the
  /// chunks that did land — so the caller can delete exactly those outbox rows
  /// and retry only the rest, never re-pushing or dead-lettering a row that
  /// already committed.
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> items,
  });

  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  });

  // ── P2a additions ──────────────────────────────────────────────────────────

  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  });

  // ── P2b additions ──────────────────────────────────────────────────────────

  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> deleteLearnerProfile(int profileId);

  // ── P2c additions ──────────────────────────────────────────────────────────

  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  });

  // ── P2d additions ──────────────────────────────────────────────────────────

  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  });

  /// Fetch one page of documents from [collection] for [profileId].
  ///
  /// Pages are ordered server-side by document key. Pass the previous
  /// page's last row back as [cursor] to advance; pass `null` to start from
  /// the beginning. An empty [FirestorePage.rows] signals end-of-stream.
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  });

  // ── P2e additions ──────────────────────────────────────────────────────────

  /// Fetch all documents from [collection] for [profileId] without pagination.
  ///
  /// Use for small collections only (bookmarks, etc.) where the total document
  /// count is bounded and pagination overhead is not warranted.
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  });

  // ── Step 1 additions (DNI-333 cutover) ────────────────────────────────────

  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  });

  /// Push account-level profile document at `users/{uid}`.
  Future<void> pushAccountProfile({required Map<String, dynamic> data});

  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  });

  /// Batch-delete all user subcollections under `users/{uid}`.
  Future<void> deleteUserData(String uid);

  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  });

  /// Write the `users/{uid}` document (account-level user profile).
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  });

  /// Open a real-time stream of a profile subcollection.
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  });

  /// Open a real-time stream of a single document in a profile subcollection.
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  });

  /// Fetch all learner profile documents at `users/{uid}/learner_profiles/`.
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles();

  /// Fetch a single document from a profile subcollection.
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  });
}

/// Result of [FirestoreGateway.fetchPage].
///
/// The [rows] list is empty when no more documents remain. The pipeline
/// uses the *last* row as the cursor for the subsequent page (so the row
/// must carry whatever fields the gateway needs to resume).
class FirestorePage {
  const FirestorePage({required this.rows});
  final List<Map<String, dynamic>> rows;
}

/// Thrown by [FirestoreGateway.pushCompletionsBatch] when one of its
/// sequentially-committed chunks fails.
///
/// [committed] holds the outbox entityKeys whose documents *did* reach
/// Firestore (the chunks that committed before the failure). The caller
/// (`OutboxProcessor`) deletes exactly those outbox rows and marks only the
/// remainder as attempted — so a row that genuinely committed is never
/// re-pushed and never dead-lettered (H3).
class BatchPushException implements Exception {
  BatchPushException({required this.committed, required this.cause});

  /// entityKeys of completions that committed before the failure.
  final List<String> committed;

  /// The underlying error that aborted the failing chunk.
  final Object cause;

  @override
  String toString() =>
      'BatchPushException(committed: ${committed.length}, cause: $cause)';
}
