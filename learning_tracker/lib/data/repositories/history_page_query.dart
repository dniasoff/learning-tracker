/// The one-shot, time-descending page read behind
/// `FirestoreChangeLogRepository.historyPage` and
/// `FirestoreLearningEventRepository.historyPage` (DNI-513, AD-38, AD-54).
///
/// - Each page is ONE single-field ordered query, newest first:
///   `orderBy(orderField, descending: true)` with `limit` and
///   `startAfterDocument` of the previous page's last document. Firestore
///   serves it from its automatic single-field index (the implicit
///   `__name__` tie-break runs in the same direction), so no composite
///   index is added (AD-54 "Indexes: none added").
/// - A document that does not decode is skipped and reported in
///   [HistoryPage.rejected]; the page, its cursor and its watermark still
///   advance past it, so one malformed document never blanks a page.
/// - Reads are `get()`s: the history is paged on demand, not watched.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';

/// Reads one history page of [collection] ordered by [orderField]
/// (a Firestore `Timestamp`) descending, after [after].
///
/// Throws [ArgumentError] when [limit] is outside
/// 1..[kChangeHistoryPageSize].
Future<HistoryPage<T>> readHistoryPage<T>(
  Query<Map<String, dynamic>> collection, {
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
    query = query.startAfterDocument(
      after.token as QueryDocumentSnapshot<Map<String, dynamic>>,
    );
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
  final last = docs.isEmpty ? null : docs.last.data()[orderField];
  return HistoryPage<T>(
    items: items,
    rejected: rejected,
    exhausted: exhausted,
    next: exhausted || docs.isEmpty ? null : HistoryCursor(docs.last),
    watermark: last is Timestamp ? last.toDate().toUtc() : null,
  );
}
