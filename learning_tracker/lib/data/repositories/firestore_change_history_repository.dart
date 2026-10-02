/// Firestore implementation of [ChangeHistoryRepository] — the parent
/// Change history pages of `users/{uid}/learner_profiles/{profileId}/
/// change_log` and `…/learning_events` (Story 4.5 / DNI-513, AD-38).
///
/// - Each page is ONE single-field ordered query, newest first:
///   `orderBy('at', descending: true)` on `change_log`,
///   `orderBy('recorded_at', descending: true)` on `learning_events`, with
///   `limit(100)` and `startAfterDocument` of the previous page's last
///   document. Firestore serves these from its automatic single-field
///   indexes (the implicit `__name__` tie-break runs in the same
///   direction), so no composite index is added (AD-54 "Indexes: none
///   added").
/// - A document that does not decode is skipped and reported in
///   [HistoryPage.rejected]; the page, its cursor and its watermark still
///   advance past it, so one malformed document never blanks a page.
/// - Reads are one-shot `get()`s: the history is paged on demand, not
///   watched (the screen reloads on retry or re-entry).
/// - The `{uid}` path segment is the caller-supplied
///   [LearnerScope.ownerUid] (ruling B10), never the live Auth user.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart'
    show kLearningEventsCollection;
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart'
    show kChangeLogCollection;
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/change_history/domain/repositories/change_history_repository.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Profile-scoped Change history pages over Firestore.
final class FirestoreChangeHistoryRepository
    implements ChangeHistoryRepository {
  /// Creates the repository over an account-scoped [firestore] handle.
  FirestoreChangeHistoryRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profile(LearnerScope scope) =>
      _firestore
          .collection('users')
          .doc(scope.ownerUid)
          .collection('learner_profiles')
          .doc(scope.profileId);

  @override
  Future<HistoryPage<ChangeLogEntry>> changeLogPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) => _page(
    _profile(scope).collection(kChangeLogCollection),
    orderField: ChangeLogEntry.kAt,
    after: after,
    limit: limit,
    decode: ChangeLogEntry.fromStorage,
  );

  @override
  Future<HistoryPage<LearningEvent>> learningEventPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) => _page(
    _profile(scope).collection(kLearningEventsCollection),
    orderField: LearningEvent.kRecordedAt,
    after: after,
    limit: limit,
    decode: LearningEvent.fromStorage,
  );

  @override
  Future<List<LearningEvent>> learningEventsById(
    LearnerScope scope,
    Set<String> ids,
  ) async {
    final events = _profile(scope).collection(kLearningEventsCollection);
    final snapshots = await Future.wait([
      for (final id in ids) events.doc(id).get(),
    ]);
    return [
      for (final snap in snapshots)
        if (snap.data() case final data?)
          if (_tryDecode(snap.id, data, LearningEvent.fromStorage)
              case final event?)
            event,
    ];
  }

  Future<HistoryPage<T>> _page<T>(
    CollectionReference<Map<String, dynamic>> collection, {
    required String orderField,
    required HistoryCursor? after,
    required int limit,
    required T Function(String id, Map<String, Object?> map) decode,
  }) async {
    if (limit < 1 || limit > kChangeHistoryPageSize) {
      throw ArgumentError.value(limit, 'limit', 'must be 1..100');
    }
    var query = collection.orderBy(orderField, descending: true);
    if (after != null) {
      query = query.startAfterDocument(after.token as _Doc);
    }
    final docs = (await query.limit(limit).get()).docs;
    final items = <T>[];
    final rejected = <RejectedRow>[];
    for (final doc in docs) {
      try {
        items.add(decode(doc.id, fromFirestoreMap(doc.data())));
      } on Object catch (error) {
        rejected.add(RejectedRow(doc.id, error));
      }
    }
    final exhausted = docs.length < limit;
    return HistoryPage<T>(
      items: items,
      rejected: rejected,
      exhausted: exhausted,
      next: exhausted || docs.isEmpty ? null : HistoryCursor(docs.last),
      watermark: docs.isEmpty ? null : _instant(docs.last.data()[orderField]),
    );
  }

  static T? _tryDecode<T>(
    String id,
    Map<String, dynamic> data,
    T Function(String id, Map<String, Object?> map) decode,
  ) {
    try {
      return decode(id, fromFirestoreMap(data));
    } on Object {
      return null;
    }
  }

  static DateTime? _instant(Object? raw) =>
      raw is Timestamp ? raw.toDate().toUtc() : null;
}
