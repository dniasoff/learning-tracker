// FirestoreAuditLogReadRepository — W6.13 (data-layer fix)
//
// Real Firestore-backed read implementation for the tutor audit log.
// Reads from: tutor_grants/{grantId}/audit_log/{entryId}
// Ordered by timestamp DESC.
//
// Firestore security rules (firestore.rules lines 151–160) allow reads for
// both the parent_uid and tutor_uid of the grant — verified against the live
// rules at the time this was written.
//
// Delegates Firestore I/O to [FirestoreGateway.fetchAuditLogEntries] so this
// file does not import `cloud_firestore` directly (layering rule — only
// `core/sync/firestore_gateway_impl.dart` may import that package).

import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/audit_log_providers.dart';

/// Real Firestore-backed implementation of [TutorAuditLogReadRepository].
///
/// All Firestore I/O is delegated to [FirestoreGateway.fetchAuditLogEntries]
/// which lives in `core/sync/` — the only permitted importer of
/// `package:cloud_firestore`.
///
/// Optional filters:
///   - [dateRange] — server-side `timestamp` range (inclusive).
///   - [actionFilter] — server-side `action` equality filter.
///   - [tutorUidFilter] — client-side `tutor_uid` equality filter (no
///       composite index needed).
class FirestoreAuditLogReadRepository implements TutorAuditLogReadRepository {
  const FirestoreAuditLogReadRepository({required FirestoreGateway gateway})
    : _gateway = gateway;

  final FirestoreGateway _gateway;

  @override
  Future<List<TutorAuditLogEntry>> fetchEntries(String grantId) =>
      fetchEntriesFiltered(grantId: grantId);

  /// Fetch entries with optional server-side + client-side filtering.
  Future<List<TutorAuditLogEntry>> fetchEntriesFiltered({
    required String grantId,
    ({DateTime start, DateTime end})? dateRange,
    String? actionFilter,
    String? tutorUidFilter,
  }) async {
    final rawEntries = await _gateway.fetchAuditLogEntries(
      grantId: grantId,
      startTimestamp: dateRange?.start.toUtc().toIso8601String(),
      endTimestamp: dateRange?.end.toUtc().toIso8601String(),
      actionFilter: actionFilter,
    );

    var entries = rawEntries
        .map(_parse)
        .whereType<TutorAuditLogEntry>()
        .toList();

    if (tutorUidFilter != null) {
      entries = entries.where((e) => e.tutorUid == tutorUidFilter).toList();
    }

    return entries;
  }

  TutorAuditLogEntry? _parse(Map<String, dynamic> data) {
    try {
      return TutorAuditLogEntry.fromFirestore(data);
    } catch (_) {
      // Malformed entry — skip rather than crash the entire list.
      return null;
    }
  }
}
