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
  ///
  /// Phase 2 sync-architecture-plan: every listener is now bounded by
  /// `.orderBy(<orderField>, descending: true).limit(limit)` so the snapshot
  /// size is O(updates) rather than O(history). The payload carries an
  /// [ListenerSnapshot.isAtLimit] flag so the supervisor can trigger a
  /// recovery pull when the snapshot saturates the page size (signal: there
  /// may be older docs that fell off the window).
  ///
  /// [orderField] is the document field used for ordering. Pass
  /// [FirestoreGateway.documentIdOrderField] to order by document ID (used for
  /// collections that have no orderable timestamp field).
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit,
  });

  /// Open a real-time stream of a top-level collection that scopes by the
  /// caller's uid via a `where` predicate.
  ///
  /// Used for the `tutor_grants` collection which lives at root level (not
  /// under `users/{uid}/...`). Returns the union of documents matching
  /// `tutor_uid == auth.uid` OR `parent_uid == auth.uid` — Firestore does not
  /// support disjunctive `where` so this is two streams merged client-side.
  /// Payload follows the same [ListenerSnapshot] shape as
  /// [listenToCollection].
  Stream<ListenerSnapshot> listenToTutorGrants({int limit});

  /// Open a real-time stream of the account-level
  /// `users/{uid}/learner_profiles/` collection.
  ///
  /// This collection is the parent of every per-profile subcollection — it is
  /// NOT a subcollection of any profile document. The bounded query orders by
  /// `updated_at` descending and uses the gateway's standard listener page
  /// size. Empty stream when not authenticated.
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit});

  /// Open a real-time stream of a single document in a profile subcollection.
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  });

  /// Sentinel value for [listenToCollection.orderField] meaning "order by
  /// document ID" — used when the collection has no orderable timestamp.
  static const String documentIdOrderField = '__name__';

  /// Fetch all learner profile documents at `users/{uid}/learner_profiles/`.
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles();

  /// Fetch a single document from a profile subcollection.
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  });

  // ── T1.gateway — parent-scoped child reads ────────────────────────────────

  /// Fetch a paginated page of a child's subcollection at
  /// `users/{parentUid}/learner_profiles/{remoteProfileId}/{collection}/`.
  ///
  /// Used by the tutored pull path, which reads from the *parent's* Firestore
  /// namespace. The [remoteProfileId] is the child's string-form profile id
  /// in the parent's account — distinct from the tutor's synthetic local id.
  Future<FirestorePage> fetchChildPage({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  });

  /// Fetch a single document from a child's preference subcollection at
  /// `users/{parentUid}/learner_profiles/{remoteProfileId}/{collection}/{docId}`.
  Future<Map<String, dynamic>?> fetchChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  });

  // ── D3/D5 — parent-scoped child listeners ────────────────────────────────

  /// Open a real-time stream of a child's subcollection at
  /// `users/{parentUid}/learner_profiles/{remoteProfileId}/{collection}/`.
  ///
  /// Used by [TutoredListenerSupervisor] to stream delta changes from the
  /// parent's Firestore namespace into the tutor's local Drift mirror.
  /// The payload shape matches [listenToCollection] (a [ListenerSnapshot]
  /// with `rows` + `isAtLimit`).
  ///
  /// Returns [Stream.empty] when not authenticated.
  Stream<ListenerSnapshot> listenToChildCollection({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String orderField,
    int limit,
  });

  /// Open a real-time stream of a single document in a child's preference
  /// subcollection at
  /// `users/{parentUid}/learner_profiles/{remoteProfileId}/{collection}/{docId}`.
  ///
  /// Returns [Stream.empty] when not authenticated.
  Stream<Map<String, dynamic>?> listenToChildDocument({
    required String parentUid,
    required String remoteProfileId,
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

  // ── Phase 1 — study_day_configs/ collection ──────────────────────────────

  /// Push a study-day config record to the `study_day_configs/` subcollection.
  ///
  /// Document ID is derived deterministically from
  /// `(curriculum_id, day_of_week, track_id)` — matching the composite PK on
  /// the local `study_day_configs` table — so repeated pushes for the same
  /// composite key overwrite the same document (idempotent).
  Future<void> pushStudyDayConfig({
    required int profileId,
    required Map<String, dynamic> data,
  });

  // ── WS9 Wave-B (C#2) — points spend economy ────────────────────────────────

  /// Push one append-only points-ledger event to
  /// `points_ledger/{ulid}` (deduplicated on the ULID doc-id).
  Future<void> pushPointsLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  });

  /// Push one reward-redemption state-machine doc to
  /// `reward_redemptions/{ulid}` (LWW on `updated_at`).
  Future<void> pushRewardRedemption({
    required int profileId,
    required Map<String, dynamic> data,
  });

  // ── Tutor audit log reads (W6.13) ─────────────────────────────────────────

  /// Fetch raw audit log entries from `tutor_grants/{grantId}/audit_log/`,
  /// ordered by `timestamp` DESC.
  ///
  /// Returns the raw Firestore document payloads; callers are responsible
  /// for deserialising them via `TutorAuditLogEntry.fromFirestore`.
  ///
  /// Optional server-side filters:
  ///   - [startTimestamp] / [endTimestamp]: ISO-8601 UTC strings (inclusive).
  ///   - [actionFilter]: exact match on the `action` field.
  Future<List<Map<String, dynamic>>> fetchAuditLogEntries({
    required String grantId,
    String? startTimestamp,
    String? endTimestamp,
    String? actionFilter,
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

/// Result of [FirestoreGateway.listenToCollection].
///
/// Carries the snapshot's rows plus the "snapshot saturated the listener's
/// page-size limit" signal. [ListenerSupervisor] consumes [isAtLimit] to
/// trigger a recovery pull for the collection — without this signal, every
/// `.limit(N)` snapshot would silently truncate older changes.
class ListenerSnapshot {
  const ListenerSnapshot({required this.rows, required this.isAtLimit});
  final List<Map<String, dynamic>> rows;

  /// True when the snapshot returned exactly the listener's `limit` rows —
  /// indicates there may be older documents that the listener window did not
  /// cover. The supervisor reacts by issuing a one-shot recovery pull for the
  /// collection.
  final bool isAtLimit;
}
