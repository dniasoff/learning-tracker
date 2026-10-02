/// Firestore implementation of [ChangeLogRepository] and
/// [GovernedDocReader] — `users/{uid}/learner_profiles/{profileId}/
/// change_log/{ulid}` and the governed docs it describes (AD-37, AD-38,
/// AD-54; DNI-470 / Story 1.8).
///
/// - **Intent history** ([watchIntentHistory], AC-1): the entries whose
///   `entity` is one of [intentHistoryEntities], read with ONE equality-
///   family filter (`whereIn`) ordered by document id and paged at ≤ 500
///   through [watchCompletePaged] — loading until every page is in, never
///   partial. A single-field filter plus the implicit `__name__` order is
///   served by Firestore's automatic single-field indexes, so no composite
///   index is added (AD-54 "Indexes: none added").
/// - **Undo lookups** (AC-4, AC-5): [entriesOfAction] pages every entry of
///   one `action_id` to the end; [watchIsReverted] watches for any entry
///   whose `reverts_action_id` is the action, so every device marks an
///   undone action "Undone".
/// - **History pages** ([historyPage], DNI-513 parent Change history): one
///   `orderBy('at', descending: true)` page of ≤ 100 through
///   [readHistoryPage]; served by the automatic single-field index on
///   `at` (no composite index, AD-54).
/// - **Governed batch** ([commitGoverned], AC-2): one [WriteBatch] holding a
///   field-level `set(merge: true)` of each doc's changed fields plus
///   `last_change_id`, and the create of the entry. `change_log` is
///   append-only: the entry is pre-read through [readExistingForCreate]; an
///   identical entry is a no-op (the batch already landed, and re-applying
///   it could revert a later change), a different one throws
///   [ChangeLogConflictException] and nothing is written. A terminal server
///   rejection surfaces as [PermanentWriteRejection] (AD-54 Recovery).
/// - **Reads before a write** ([currentDoc], [entry]): cache, then server;
///   an offline client that has never seen the doc reads it as absent.
///
/// The `{uid}` path segment is the caller-supplied [LearnerScope.ownerUid]
/// (ruling B10), never read from the live Auth user here.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/repositories/create_only_guard.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart'
    show kChangeLogCollection;
import 'package:learning_tracker/data/repositories/history_page_query.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/data/repositories/paged_complete_query.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';

/// The `entity` storage values of the AD-37 intent history, in a stable
/// order (the `whereIn` operand).
final List<String> intentHistoryEntityValues = [
  for (final e in GovernedEntity.values)
    if (intentHistoryEntities.contains(e)) e.storage,
];

/// Profile-scoped `change_log` repository and governed-doc reader.
final class FirestoreChangeLogRepository
    implements ChangeLogRepository, GovernedDocReader {
  /// Creates the repository over an account-scoped [firestore] handle.
  FirestoreChangeLogRepository({
    required FirebaseFirestore firestore,
    this.backoffBase = const Duration(seconds: 1),
    this.backoffCap = const Duration(seconds: 30),
    this.random,
    this.onListenerError,
    this.pageProbe,
    CreateGuardRead? guardRead,
    CreateGuardRead? docRead,
  }) : _firestore = firestore,
       _guardRead = guardRead ?? readExistingForCreate,
       _docRead = docRead ?? readExistingForCreate;

  final FirebaseFirestore _firestore;

  /// The change-log create-only pre-read (tests inject outcomes).
  final CreateGuardRead _guardRead;

  /// The governed-doc / entry read (cache, then server; null = absent).
  final CreateGuardRead _docRead;

  /// AD-9 resubscribe backoff base.
  final Duration backoffBase;

  /// AD-9 resubscribe backoff cap.
  final Duration backoffCap;

  /// Jitter source (tests pin it).
  final math.Random? random;

  /// Called for each stream-level listener failure.
  final void Function(Object error, StackTrace stackTrace)? onListenerError;

  /// Test seam: observes every page query of the paged reads.
  final PageProbe? pageProbe;

  CollectionReference<Map<String, dynamic>> _profiles(LearnerScope scope) =>
      _firestore
          .collection('users')
          .doc(scope.ownerUid)
          .collection(GovernedEntity.learnerSettings.collection);

  DocumentReference<Map<String, dynamic>> _profile(LearnerScope scope) =>
      _profiles(scope).doc(scope.profileId);

  /// `users/{ownerUid}/learner_profiles/{profileId}/change_log`.
  CollectionReference<Map<String, dynamic>> collectionFor(LearnerScope scope) =>
      _profile(scope).collection(kChangeLogCollection);

  DocumentReference<Map<String, dynamic>> _governedDoc(
    LearnerScope scope,
    String collection,
    String docId,
  ) => collection == GovernedEntity.learnerSettings.collection
      // `learnerSettings` lives on the profile doc itself
      // (`learner_profiles/{profileId}`, AD-37).
      ? _profiles(scope).doc(docId)
      : _profile(scope).collection(collection).doc(docId);

  @override
  Stream<CompleteRead<ChangeLogEntry>> watchIntentHistory(LearnerScope scope) =>
      watchCompletePaged<ChangeLogEntry>(
        collection: collectionFor(
          scope,
        ).where(ChangeLogEntry.kEntity, whereIn: intentHistoryEntityValues),
        decode: ChangeLogEntry.fromStorage,
        backoffBase: backoffBase,
        backoffCap: backoffCap,
        random: random,
        onError: onListenerError,
        probe: pageProbe,
      );

  @override
  Future<HistoryPage<ChangeLogEntry>> historyPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) => readHistoryPage(
    collectionFor(scope),
    orderField: ChangeLogEntry.kAt,
    after: after,
    limit: limit,
    decode: ChangeLogEntry.fromStorage,
  );

  @override
  Future<List<ChangeLogEntry>> entriesOfAction(
    LearnerScope scope,
    String actionId,
  ) async {
    final base = collectionFor(
      scope,
    ).where(ChangeLogEntry.kActionId, isEqualTo: actionId);
    final entries = <ChangeLogEntry>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? after;
    for (var page = 0; ; page++) {
      var query = base.orderBy(FieldPath.documentId);
      if (after != null) query = query.startAfterDocument(after);
      pageProbe?.call(
        pageIndex: page,
        afterDocId: after?.id,
        limit: kMaxListPageSize,
        delivered: null,
      );
      final docs = (await query.limit(kMaxListPageSize).get()).docs;
      pageProbe?.call(
        pageIndex: page,
        afterDocId: after?.id,
        limit: kMaxListPageSize,
        delivered: docs.length,
      );
      for (final doc in docs) {
        entries.add(
          ChangeLogEntry.fromStorage(doc.id, fromFirestoreMap(doc.data())),
        );
      }
      if (docs.length < kMaxListPageSize) return entries;
      after = docs.last;
    }
  }

  @override
  Stream<bool> watchIsReverted(LearnerScope scope, String actionId) =>
      resilientQueryStream<String>(
        openStream: () => collectionFor(scope)
            .where(ChangeLogEntry.kRevertsActionId, isEqualTo: actionId)
            .limit(1)
            .snapshots(),
        decode: (doc) => doc.id,
        backoffBase: backoffBase,
        backoffCap: backoffCap,
        random: random,
        onError: onListenerError,
      ).map((ids) => ids.isNotEmpty).distinct();

  @override
  Future<void> commitGoverned(LearnerScope scope, GovernedBatch batch) async {
    // Every payload is validated by its domain type before any I/O.
    final entry = batch.entry;
    final entryPayload = toFirestoreMap(entry.toStorage());
    final merges = [
      for (final merge in batch.merges)
        (
          _governedDoc(scope, merge.collection, merge.docId),
          toFirestoreMap(merge.toMergePatch(entry.id)),
        ),
    ];
    final entryDoc = collectionFor(scope).doc(entry.id);
    final existing = await _guardRead(entryDoc);
    if (existing != null) {
      // Identical replay: the atomic batch already landed. No-op.
      if (_decodesTo(entry, existing)) return;
      throw ChangeLogConflictException(entry.id);
    }
    final writes = _firestore.batch();
    for (final (doc, patch) in merges) {
      writes.set(doc, patch, SetOptions(merge: true));
    }
    writes.set(entryDoc, entryPayload);
    try {
      await writes.commit();
    } on FirebaseException catch (e) {
      if (FirestoreLearningEventRepository.permanentRejectionCodes.contains(
        e.code,
      )) {
        throw PermanentWriteRejection(e.code);
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, Object?>?> currentDoc(
    LearnerScope scope,
    String collection,
    String docId,
  ) async {
    final data = await _docRead(_governedDoc(scope, collection, docId));
    return data == null ? null : fromFirestoreMap(data);
  }

  @override
  Future<ChangeLogEntry?> entry(LearnerScope scope, String entryId) async {
    final data = await _docRead(collectionFor(scope).doc(entryId));
    if (data == null) return null;
    try {
      return ChangeLogEntry.fromStorage(entryId, fromFirestoreMap(data));
    } on Object {
      return null; // undecodable: the actor is unknown
    }
  }

  static bool _decodesTo(ChangeLogEntry entry, Map<String, dynamic> data) {
    try {
      return ChangeLogEntry.fromStorage(entry.id, fromFirestoreMap(data)) ==
          entry;
    } on Object {
      return false; // an undecodable stored row is never silently replaced
    }
  }
}
