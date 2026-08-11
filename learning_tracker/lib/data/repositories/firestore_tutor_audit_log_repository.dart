/// Firestore-backed repository for `tutor_grants/{grantId}/audit_log/{entryId}`
/// — built to the shape `lib/data/repositories/firestore_account_repository.dart`
/// establishes as the reference. See that file's class doc comment for the
/// pattern this copies. This doc comment only calls out what is DIFFERENT
/// here.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-backed read repository for a tutor grant's audit log.
/// Replaces `FirestoreGatewayImpl.fetchAuditLogEntries` (archived with the
/// rest of the Drift sync engine, `docs/_archive/drift-user-db/sync/`).
///
/// `firestore.rules` (`match /tutor_grants/{grantId}/audit_log/{entryId}`)
/// allows reads for both the grant's `parent_uid` and `tutor_uid` — this
/// repository is grant-scoped, not account-scoped, so it takes no `uid` at
/// construction; every call names the `grantId` explicitly.
///
/// Returns raw decoded document maps rather than a typed entity: the
/// feature-scoped `FirestoreAuditLogReadRepository`
/// (`lib/features/tutoring/data/repositories/firestore_audit_log_read_repository.dart`)
/// owns the `TutorAuditLogEntry.fromFirestore` parse + the per-entry
/// malformed-doc tolerance, matching what it did with the archived gateway.
///
/// **`timestamp` is a plain ISO-8601 `String` field, not a Firestore
/// `Timestamp`** — `TutorAuditLogEntry.toFirestore` writes
/// `timestamp.toUtc().toIso8601String()` and `.fromFirestore` reads it back
/// with `DateTime.parse`, so range filtering below compares strings
/// directly (lexicographic ISO-8601 ordering matches chronological
/// ordering) — no `Timestamp`-to-`DateTime` read-side normalization is
/// needed, unlike `completions.completed_at`.
class FirestoreTutorAuditLogRepository {
  FirestoreTutorAuditLogRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Fetch raw audit-log entry documents for [grantId], newest first.
  ///
  /// [dateRange] applies a server-side inclusive `timestamp` range filter;
  /// [actionFilter] applies a server-side `action` equality filter.
  Future<List<Map<String, dynamic>>> fetchEntries({
    required String grantId,
    ({DateTime start, DateTime end})? dateRange,
    String? actionFilter,
  }) async {
    var query = _firestore
        .collection('tutor_grants')
        .doc(grantId)
        .collection('audit_log')
        .orderBy('timestamp', descending: true);

    if (dateRange != null) {
      query = query
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: dateRange.start.toUtc().toIso8601String(),
          )
          .where(
            'timestamp',
            isLessThanOrEqualTo: dateRange.end.toUtc().toIso8601String(),
          );
    }
    if (actionFilter != null) {
      query = query.where('action', isEqualTo: actionFilter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
