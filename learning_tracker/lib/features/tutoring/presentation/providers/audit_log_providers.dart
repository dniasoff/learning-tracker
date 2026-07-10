// Audit log providers — W6.13
//
// Riverpod providers for reading audit log entries from the
// `tutor_grants/{grantId}/audit_log/` sub-collection.
//
// The concrete repository implementation reads from Firestore.
//
// AUD-tutoring-06: there is no client-side write path. All tutor mutations
// go through Cloud Functions, and every one of them writes its own audit
// entry server-side via `writeAuditLog()` (functions/src/index.ts) inside
// the same Admin SDK transaction. The client only ever reads this
// sub-collection back for display.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/features/tutoring/data/repositories/firestore_audit_log_read_repository.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';

// ── Read repository interface ────────────────────────────────────────────────

/// Read-only repository for querying audit log entries.
///
/// The production implementation reads from
/// `tutor_grants/{grantId}/audit_log/` ordered by timestamp DESC.
abstract interface class TutorAuditLogReadRepository {
  /// Fetch all entries for [grantId], newest first.
  Future<List<TutorAuditLogEntry>> fetchEntries(String grantId);
}

// ── Repository provider ──────────────────────────────────────────────────────

/// Production provider backed by [FirestoreAuditLogReadRepository].
///
/// Falls back to an empty-list stub when the user is not cloud-authenticated
/// (i.e. gateway is null). Tutor features require cloud auth, so the stub
/// path is only reached in the rare unauthenticated/offline edge-case.
final tutorAuditLogReadRepositoryProvider =
    Provider<TutorAuditLogReadRepository>((ref) {
      final gateway = ref.watch(firestoreGatewayProvider);
      if (gateway == null) return const _UnauthenticatedAuditLogRepository();
      return FirestoreAuditLogReadRepository(gateway: gateway);
    });

/// Fallback repository returned when the user has no active Firestore session.
///
/// Returns an empty list instead of throwing, so the audit log screen can
/// render its empty state cleanly.
class _UnauthenticatedAuditLogRepository
    implements TutorAuditLogReadRepository {
  const _UnauthenticatedAuditLogRepository();

  @override
  Future<List<TutorAuditLogEntry>> fetchEntries(String grantId) async =>
      const [];
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
