// TutorAuditLogReadRepository — domain repository interface (moved by
// AUD-tutoring-10 from presentation/providers/audit_log_providers.dart).
//
// Relocated per the placement guide in docs/coding-standards.md ("New
// repository interface -> domain/repositories/<name>_repository.dart"): the
// interface previously lived in a presentation-layer file, which forced the
// data-layer implementation (firestore_audit_log_read_repository.dart) to
// import FROM presentation to satisfy `implements` — the inverse of the
// documented data-flow direction (data -> domain <- presentation).

import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';

/// Read-only repository for querying audit log entries.
///
/// The production implementation reads from
/// `tutor_grants/{grantId}/audit_log/` ordered by timestamp DESC.
abstract interface class TutorAuditLogReadRepository {
  /// Fetch all entries for [grantId], newest first.
  Future<List<TutorAuditLogEntry>> fetchEntries(String grantId);
}
