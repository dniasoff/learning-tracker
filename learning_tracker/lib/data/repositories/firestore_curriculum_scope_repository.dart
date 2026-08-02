/// Firestore implementation for curriculum scopes — one of the two
/// repositories built alongside `FirestoreProfileProgramRepository`
/// (`docs/firestore-rewrite-map.md`). Follows the shape
/// `FirestoreBookmarkRepository`/`FirestoreStageDefinitionRepository`
/// established; see this file's own doc comments for what is genuinely new.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_scope.dart';

/// Firestore-backed curriculum-scopes repository: `users/{uid}/
/// learner_profiles/{profileId}/curriculum_scopes/{scopeId}` (one document
/// per selected scope VALUE — `docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /curriculum_scopes/{scopeId}`).
///
/// **Not wired into the app yet** — same status as every other repository
/// under `lib/data/repositories/`: stands alone, nothing under
/// `lib/features/` reads it, the existing Drift-backed `CurriculumScopeDao`
/// is untouched.
///
/// **No interface** — same reasoning as `FirestoreBookmarkRepository`'s doc
/// comment.
///
/// ## Doc-id: `DocIds.curriculumScopeDocId`
///
/// No `DocIds` entry existed for `curriculum_scopes` when this repository
/// was first built (the Drift-era gateway never pushed this collection
/// under a deterministic id — `CurriculumScopeDao` predates the sync
/// engine's Firestore path for this table). Rather than leave a private
/// one-off formula living only in this file, it was promoted into
/// `lib/data/firestore/doc_ids.dart` as `DocIds.curriculumScopeDocId` — see
/// that function's doc comment for why it has no live-`FirestoreGatewayImpl`
/// golden counterpart the way most `DocIds` formulas do, and how
/// `doc_ids_test.dart` pins it instead.
///
/// ## Set-replace semantics — Drift's `transaction()` does NOT fully survive
///
/// `CurriculumScopeDao.setScopes` clears every existing row for a
/// curriculum, then inserts the new set, inside one Drift `transaction()` —
/// atomic, all-or-nothing. [setScopes] below reproduces the SAME clear-then-
/// insert shape, and — because a curriculum's scope-selection list is
/// realistically tiny (a few dozen sedarim/masechtos/perakim at most, never
/// remotely close to Firestore's 500-operation batch cap) — the common case
/// stays atomic too: when `(existing to delete) + (new to insert) <= 500`,
/// both halves commit in a SINGLE `WriteBatch`, which Firestore applies
/// all-or-nothing exactly like the Drift transaction.
///
/// **Only past that cap does the guarantee genuinely weaken**: with more
/// than 500 combined operations, no single Firestore batch can hold the
/// replace, so it is chunked across MULTIPLE sequential batches
/// ([_deleteInChunks] then [_commitSetsInChunks]) — each chunk is atomic
/// on its own, but the replace as a whole is NOT atomic end-to-end. A
/// listener via [watchScopes] could observe a transient state with some old
/// scopes deleted and none/some of the new ones written yet. Flagged here
/// rather than silently changed: this only bites a scope list orders of
/// magnitude larger than any real curriculum's hierarchy, but the semantics
/// genuinely differ once it does.
class FirestoreCurriculumScopeRepository {
  FirestoreCurriculumScopeRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final AppLogger _logger;

  /// Firestore's hard cap on operations inside one `WriteBatch`.
  static const _maxBatchOps = 500;

  CollectionReference<Map<String, dynamic>> get _scopes => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('curriculum_scopes');

  DocumentReference<Map<String, dynamic>> _doc({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required String scopeValue,
  }) => _scopes.doc(
    DocIds.curriculumScopeDocId({
      'curriculum_id': curriculumId.storageKey,
      'scope_level': scopeLevel,
      'scope_value': scopeValue,
    }),
  );

  /// Equality-only filter — no `.orderBy()` on a different field, so no
  /// composite index is needed (unlike `FirestoreStageDefinitionRepository`'s
  /// `curriculum_id` + `stage_order` query).
  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _scopes.where('curriculum_id', isEqualTo: curriculumId.storageKey);

  /// Returns every scope selection for [curriculumId] (any level, unordered
  /// beyond Firestore's default document-id order).
  Future<List<CurriculumScopeEntity>> getScopes(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails — same "one bad document should not blank
  /// the list" reasoning as `FirestoreStageDefinitionRepository._decodeAll`.
  List<CurriculumScopeEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <CurriculumScopeEntity>[];
    for (final doc in docs) {
      try {
        results.add(curriculumScopeFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_curriculum_scopes_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Live updates for [curriculumId]'s scope list. Resubscribes with
  /// bounded exponential backoff if the underlying listener errors
  /// (`resilientQueryStream`).
  Stream<List<CurriculumScopeEntity>> watchScopes(CurriculumId curriculumId) {
    return resilientQueryStream<CurriculumScopeEntity>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) => curriculumScopeFromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_curriculum_scopes_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    );
  }

  /// Scope values as plain strings for [curriculumId] — mirrors
  /// `CurriculumScopeDao.getScopeValues`.
  Future<List<String>> getScopeValues(CurriculumId curriculumId) async {
    final scopes = await getScopes(curriculumId);
    return scopes.map((s) => s.scopeValue).toList();
  }

  /// The scope level for [curriculumId] (taken from the first result), or
  /// `null` if no scopes exist — mirrors `CurriculumScopeDao.getScopeLevel`,
  /// including its "look at the first row" behavior for a curriculum with
  /// mixed-level scopes.
  Future<int?> getScopeLevel(CurriculumId curriculumId) async {
    final scopes = await getScopes(curriculumId);
    if (scopes.isEmpty) return null;
    return scopes.first.scopeLevel;
  }

  /// Whether [curriculumId] has any scope selections set.
  Future<bool> hasScopes(CurriculumId curriculumId) async {
    final snapshot = await _queryForCurriculum(curriculumId).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// Every scope selection in this profile's whole `curriculum_scopes`
  /// subcollection (cross-curriculum). Unfiltered — no `where()`/
  /// `orderBy()`, so no composite index needed.
  Future<List<CurriculumScopeEntity>> getAllScopes() async {
    final snapshot = await _scopes.get();
    return _decodeAll(snapshot.docs);
  }

  /// Additively inserts [scopes] for [curriculumId] — does NOT clear
  /// existing selections first. Mirrors `CurriculumScopeDao.
  /// insertScopesForTrack` minus its `trackId` parameter (AD-25 retires the
  /// per-device track id for this collection): callers that need
  /// replace-not-append semantics should call [setScopes] or clear first
  /// with [clearScopes].
  Future<void> insertScopes({
    required CurriculumId curriculumId,
    required List<({int level, String value})> scopes,
  }) async {
    if (scopes.isEmpty) return;
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final entities = [
      for (final scope in scopes)
        CurriculumScopeEntity(
          curriculumId: curriculumId,
          scopeLevel: scope.level,
          scopeValue: scope.value,
          createdAt: now,
        ),
    ];
    await _commitSetsInChunks(entities, updatedAt: now);
  }

  /// Replaces every scope selection for [curriculumId] with [scopeValues]
  /// at [scopeLevel] — clear-then-insert, mirroring `CurriculumScopeDao.
  /// setScopes`. Pass an empty [scopeValues] to clear all scopes (= track
  /// the entire curriculum). See the class doc comment for exactly what
  /// atomicity guarantee this does and does not preserve versus the Drift
  /// `transaction()`-wrapped original.
  Future<void> setScopes({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async {
    final existing = await getScopes(curriculumId);
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final deleteRefs = [
      for (final scope in existing)
        _doc(
          curriculumId: scope.curriculumId,
          scopeLevel: scope.scopeLevel,
          scopeValue: scope.scopeValue,
        ),
    ];
    final newEntities = [
      for (final value in scopeValues)
        CurriculumScopeEntity(
          curriculumId: curriculumId,
          scopeLevel: scopeLevel,
          scopeValue: value,
          createdAt: now,
        ),
    ];

    if (deleteRefs.length + newEntities.length <= _maxBatchOps) {
      // Fits in one WriteBatch — atomic, matching the Drift transaction.
      final batch = _firestore.batch();
      for (final ref in deleteRefs) {
        batch.delete(ref);
      }
      for (final entity in newEntities) {
        batch.set(
          _doc(
            curriculumId: entity.curriculumId,
            scopeLevel: entity.scopeLevel,
            scopeValue: entity.scopeValue,
          ),
          entity.toFirestore(updatedAt: now),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      return;
    }

    // See the class doc comment: past the 500-op cap this is no longer
    // atomic end-to-end.
    await _deleteInChunks(deleteRefs);
    await _commitSetsInChunks(newEntities, updatedAt: now);
  }

  /// Clears every scope selection for [curriculumId] (= track the entire
  /// curriculum) — mirrors `CurriculumScopeDao.clearScopes`.
  Future<void> clearScopes(CurriculumId curriculumId) async {
    final existing = await getScopes(curriculumId);
    final refs = [
      for (final scope in existing)
        _doc(
          curriculumId: scope.curriculumId,
          scopeLevel: scope.scopeLevel,
          scopeValue: scope.scopeValue,
        ),
    ];
    await _deleteInChunks(refs);
  }

  Future<void> _deleteInChunks(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    for (var i = 0; i < refs.length; i += _maxBatchOps) {
      final batch = _firestore.batch();
      for (final ref in refs.skip(i).take(_maxBatchOps)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _commitSetsInChunks(
    List<CurriculumScopeEntity> entities, {
    required DateTime updatedAt,
  }) async {
    for (var i = 0; i < entities.length; i += _maxBatchOps) {
      final batch = _firestore.batch();
      for (final entity in entities.skip(i).take(_maxBatchOps)) {
        batch.set(
          _doc(
            curriculumId: entity.curriculumId,
            scopeLevel: entity.scopeLevel,
            scopeValue: entity.scopeValue,
          ),
          entity.toFirestore(updatedAt: updatedAt),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }
}
