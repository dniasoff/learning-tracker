// Audit log providers — W6.13
//
// Riverpod providers for reading audit log entries from the
// `tutor_grants/{grantId}/audit_log/` sub-collection.
//
// The concrete repository implementation reads from Firestore.
// Until the data layer lands, a stub returns an empty list.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_audit_log_writer.dart';

// ── Stub read repository ─────────────────────────────────────────────────────

/// Read-only repository for querying audit log entries.
///
/// TODO(data-layer): Replace stub with a real Firestore implementation that
/// reads from `tutor_grants/{grantId}/audit_log/` ordered by timestamp desc.
abstract interface class TutorAuditLogReadRepository {
  /// Fetch all entries for [grantId], newest first.
  Future<List<TutorAuditLogEntry>> fetchEntries(String grantId);
}

class _StubAuditLogReadRepository implements TutorAuditLogReadRepository {
  const _StubAuditLogReadRepository();

  @override
  Future<List<TutorAuditLogEntry>> fetchEntries(String grantId) async =>
      const [];
}

// ── Repository provider ──────────────────────────────────────────────────────

final tutorAuditLogReadRepositoryProvider =
    Provider<TutorAuditLogReadRepository>(
      (_) => const _StubAuditLogReadRepository(),
    );

// The write repository provider (used by TutorAuditLogWriter) is also
// provided here as a stub. The concrete implementation writes via Admin SDK
// (Cloud Function) or directly to Firestore.
final tutorAuditLogWriteRepositoryProvider = Provider<TutorAuditLogRepository>(
  (_) => _StubAuditLogWriteRepository(),
);

class _StubAuditLogWriteRepository implements TutorAuditLogRepository {
  @override
  Future<void> appendEntry(TutorAuditLogEntry entry) async {
    // No-op stub. The real implementation writes to Firestore via Admin SDK.
    // TODO(data-layer): Replace with Firestore write.
  }
}

// ── Async data provider ──────────────────────────────────────────────────────

/// Fetch audit log entries for a specific grant.
///
/// Parameterised by [grantId]. Returns entries newest-first.
final tutorAuditLogProvider =
    FutureProvider.family<List<TutorAuditLogEntry>, String>((ref, grantId) {
      final repo = ref.watch(tutorAuditLogReadRepositoryProvider);
      return repo.fetchEntries(grantId);
    });
