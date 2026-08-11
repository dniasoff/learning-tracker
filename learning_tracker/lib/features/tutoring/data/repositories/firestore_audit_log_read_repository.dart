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
// Delegates Firestore I/O to [FirestoreTutorAuditLogRepository] (replaces
// the archived `FirestoreGateway.fetchAuditLogEntries` —
// docs/_archive/drift-user-db/sync/), resolved via
// `firestoreTutorAuditLogRepositoryProvider`. This file lives under
// `features/tutoring/data/repositories/`, the AD-23/AD-28 sanctioned seam
// that may reach `lib/data/firestore/repository_providers.dart` directly —
// presentation code (audit_log_providers.dart) reaches this adapter
// instead, never the raw provider.
//
// Not-ready (no active account) resolves to `[]`, not a throw: matches this
// file's pre-existing tolerance for an unauthenticated/offline caller (see
// `audit_log_providers.dart`'s `_UnauthenticatedAuditLogRepository`, which
// this replaces at one layer up) — an audit log is a tutor's own diagnostic
// history, not achievement data, so D-E's throw-on-not-ready branch does
// not apply here.
//
// AUD-tutoring-10: imports the repository interface from its domain-layer
// home rather than from a UI-layer providers file — a data-layer file must
// not depend on the UI layer (the inverse of the documented data-flow
// direction).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
import 'package:learning_tracker/features/tutoring/domain/repositories/tutor_audit_log_repository.dart';

/// Real Firestore-backed implementation of [TutorAuditLogReadRepository].
///
/// All Firestore I/O is delegated to [FirestoreTutorAuditLogRepository] via
/// `firestoreTutorAuditLogRepositoryProvider`.
///
/// Optional filters:
///   - [dateRange] — server-side `timestamp` range (inclusive).
///   - [actionFilter] — server-side `action` equality filter.
///   - [tutorUidFilter] — client-side `tutor_uid` equality filter (no
///       composite index needed).
class FirestoreAuditLogReadRepository implements TutorAuditLogReadRepository {
  const FirestoreAuditLogReadRepository({required Ref ref}) : _ref = ref;

  final Ref _ref;

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
    final repository = await _ref.read(
      firestoreTutorAuditLogRepositoryProvider.future,
    );
    if (repository == null) return const [];

    final rawEntries = await repository.fetchEntries(
      grantId: grantId,
      dateRange: dateRange,
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
