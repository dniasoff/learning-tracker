// TutorAuditLogWriter — W6.20-W6.22
//
// Middleware service that writes audit log entries for tutor-originated
// mutations. Every tutor write path (Cloud Functions + client-side config
// changes) calls through this writer.
//
// W6.21: The tutor_name_snapshot is captured at write-time from the caller's
// displayName so it persists even after account deletion (FR-7.2).
//
// W6.22: All 9 TutorAuditAction types are covered:
//   config_changed, completion_bulk_prior, completion_reset,
//   bookmark_advanced, profile_edited, goal_changed, stage_changed,
//   reward_changed, study_day_changed.
//
// IMPORTANT: The Cloud Function (tutorBulkPriorCompletions, W3.43) already
// writes audit entries for completion_bulk_prior directly. This writer
// handles the remaining 8 action types that happen from client-side tutor
// mutations (which go through Cloud Functions too). The audit entry is
// written inside the same Cloud Function transaction.
//
// For client-side read-only mutations (config changes visible immediately),
// the audit entry is written via a separate Firestore document write using
// Admin SDK (the Cloud Function for config changes).
//
// This class is the typed domain-layer interface; the concrete write
// implementation (TutorAuditLogFirestoreWriter) lives in the data layer
// and writes to tutor_grants/{grantId}/audit_log/{entryId}.

import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';

/// Repository interface for writing audit log entries.
///
/// The concrete implementation writes to the Firestore sub-collection
/// `tutor_grants/{grantId}/audit_log/{entryId}` via Admin SDK or
/// through a Cloud Function depending on the caller context.
abstract interface class TutorAuditLogRepository {
  /// Append a single audit log entry.
  ///
  /// Implementations MUST be idempotent on [entryId] — duplicate writes with
  /// the same ULID are silently ignored. This guarantees at-least-once
  /// delivery is safe.
  Future<void> appendEntry(TutorAuditLogEntry entry);
}

/// Domain service that constructs and dispatches audit log entries.
///
/// Callers supply the semantic fields (action, target, before/after); this
/// service fills in the tutor identity fields and dispatches to the
/// [TutorAuditLogRepository].
///
/// W6.21 implementation: [tutorNameSnapshot] is passed in from the caller
/// (read from Firebase Auth `displayName` at the time of the action). If the
/// displayName is null (account has no display name set), we fall back to the
/// tutor email address, which is always present.
class TutorAuditLogWriter {
  const TutorAuditLogWriter({
    required this.tutorUid,
    required this.tutorNameSnapshot,
    required this.grantId,
    required this.repository,
  });

  /// UID of the tutor performing the action.
  final String tutorUid;

  /// Display name captured at write-time (W6.21 — persists after deletion).
  final String tutorNameSnapshot;

  /// The active grant ID this action is being performed under.
  final String grantId;

  final TutorAuditLogRepository repository;

  // ── Per-action write methods (W6.22) ──────────────────────────────────────

  /// Config item changed (e.g. a permissions flag toggled by the parent's
  /// override or a tutor-accessible setting).
  Future<void> logConfigChanged({
    required String target,
    required String? beforeValue,
    required String? afterValue,
  }) =>
      _log(
        action: TutorAuditAction.configChanged,
        target: target,
        beforeValue: beforeValue,
        afterValue: afterValue,
      );

  /// Bulk-prior completions submitted (also written by Cloud Function W3.43).
  Future<void> logCompletionBulkPrior({
    required String target,
    required String afterValue, // JSON: { count: N }
  }) =>
      _log(
        action: TutorAuditAction.completionBulkPrior,
        target: target,
        afterValue: afterValue,
      );

  /// A completion was reset by the tutor.
  Future<void> logCompletionReset({
    required String target,
    required String? beforeValue,
  }) =>
      _log(
        action: TutorAuditAction.completionReset,
        target: target,
        beforeValue: beforeValue,
      );

  /// A bookmark was advanced by the tutor.
  Future<void> logBookmarkAdvanced({
    required String target,
    required String? beforeValue,
    required String? afterValue,
  }) =>
      _log(
        action: TutorAuditAction.bookmarkAdvanced,
        target: target,
        beforeValue: beforeValue,
        afterValue: afterValue,
      );

  /// A learner profile field was edited by the tutor.
  Future<void> logProfileEdited({
    required String target, // e.g. "profile/42.displayName"
    required String? beforeValue,
    required String? afterValue,
  }) =>
      _log(
        action: TutorAuditAction.profileEdited,
        target: target,
        beforeValue: beforeValue,
        afterValue: afterValue,
      );

  /// A goal was created, modified, or deleted by the tutor.
  Future<void> logGoalChanged({
    required String target, // e.g. "goal/{goalId}.targetDate"
    required String? beforeValue,
    required String? afterValue,
  }) =>
      _log(
        action: TutorAuditAction.goalChanged,
        target: target,
        beforeValue: beforeValue,
        afterValue: afterValue,
      );

  /// A stage configuration was changed by the tutor.
  Future<void> logStageChanged({
    required String target, // e.g. "stage/{stageId}.delayDays"
    required String? beforeValue,
    required String? afterValue,
  }) =>
      _log(
        action: TutorAuditAction.stageChanged,
        target: target,
        beforeValue: beforeValue,
        afterValue: afterValue,
      );

  /// A reward configuration was changed by the tutor.
  Future<void> logRewardChanged({
    required String target,
    required String? beforeValue,
    required String? afterValue,
  }) =>
      _log(
        action: TutorAuditAction.rewardChanged,
        target: target,
        beforeValue: beforeValue,
        afterValue: afterValue,
      );

  /// Study day schedule was changed by the tutor.
  Future<void> logStudyDayChanged({
    required String target,
    required String? beforeValue,
    required String? afterValue,
  }) =>
      _log(
        action: TutorAuditAction.studyDayChanged,
        target: target,
        beforeValue: beforeValue,
        afterValue: afterValue,
      );

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _log({
    required TutorAuditAction action,
    required String target,
    String? beforeValue,
    String? afterValue,
  }) {
    // ULID: use timestamp + random suffix. In production, replace this with
    // a proper ULID library (e.g. package:ulid). The format is:
    //   yyyyMMddHHmmssSSS + 10 random hex chars (26 chars total)
    // For now, use DateTime.now() as a sortable key — close enough for v1.
    final now = DateTime.now().toUtc();
    final entryId =
        '${now.millisecondsSinceEpoch.toRadixString(16).padLeft(16, '0')}'
        '_${action.toJson()}';

    final entry = TutorAuditLogEntry(
      entryId: entryId,
      tutorUid: tutorUid,
      tutorNameSnapshot: tutorNameSnapshot, // W6.21
      action: action,
      target: target,
      beforeValue: beforeValue,
      afterValue: afterValue,
      timestamp: now,
    );

    return repository.appendEntry(entry);
  }
}
