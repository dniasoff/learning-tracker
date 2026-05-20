// Import so the typedef on line 10 can reference SyncPushException within this
// file (export alone does not bring the symbol into scope here).
import 'package:learning_tracker/core/sync/exceptions/sync_push_exception.dart'
    show SyncPushException;

// Re-export SyncPushException so existing importers of this file don't break
// after the move to core/sync/exceptions/ (W7.3).
export 'package:learning_tracker/core/sync/exceptions/sync_push_exception.dart'
    show SyncPushException;

/// Backward-compat alias — callers that catch [BatchPushException] continue
/// to work; new code should catch [SyncPushException] directly.
typedef BatchPushException = SyncPushException;

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
  /// `track_type`, `curriculum_id`) — the [docId] parameter is **ignored for
  /// completions** and retained only for non-completion callers that pass an
  /// explicit ID.
  ///
  /// Including `curriculum_id` in the doc ID ensures that two completions with
  /// the same (profileId, sefariaRef, stageId, trackType) but different
  /// curriculumIds are stored as DISTINCT Firestore documents (Option B /
  /// per-curriculum isolation).
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
  /// from the payload's structured natural key (`profile_id`, `sefaria_ref`,
  /// `stage_id`, `track_type`, `curriculum_id`) — never from the entityKey.
  /// The `curriculum_id` component ensures per-curriculum document isolation.
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

  /// Hard-delete a goal document from Firestore. Mirrors the
  /// `removeProfileProgramAssignment` pattern — the cloud row goes away,
  /// the local row was already removed by the caller.
  Future<void> deleteGoal({
    required int profileId,
    required String firestoreId,
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

  // ── W2.29 additions — stage_definitions/ collection ──────────────────────

  /// Push a single stage definition document to the `stage_definitions/`
  /// subcollection. The document ID is derived from `trackId` and `stageOrder`
  /// so that the push is idempotent and updates overwrite previous values.
  Future<void> pushStageDefinition({
    required int profileId,
    required Map<String, dynamic> data,
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
