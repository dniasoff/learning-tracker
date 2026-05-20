// TutorAuditLogEntry — sub-collection document model (W3.40)
//
// Firestore path: tutor_grants/{grantId}/audit_log/{entryId}
//
// Retention: auto-purged 12 months after the grant's revoked_at / declined_at
// by a scheduled Cloud Function (W3.42).
//
// The tutor_name_snapshot is captured at write-time so it survives tutor
// account deletion (FR-7.2 requirement).

/// The type of action recorded in the audit log.
enum TutorAuditAction {
  configChanged,
  completionBulkPrior,
  completionReset,
  bookmarkAdvanced,
  profileEdited,
  goalChanged,
  stageChanged,
  rewardChanged,
  studyDayChanged;

  String toJson() => switch (this) {
        TutorAuditAction.configChanged => 'config_changed',
        TutorAuditAction.completionBulkPrior => 'completion_bulk_prior',
        TutorAuditAction.completionReset => 'completion_reset',
        TutorAuditAction.bookmarkAdvanced => 'bookmark_advanced',
        TutorAuditAction.profileEdited => 'profile_edited',
        TutorAuditAction.goalChanged => 'goal_changed',
        TutorAuditAction.stageChanged => 'stage_changed',
        TutorAuditAction.rewardChanged => 'reward_changed',
        TutorAuditAction.studyDayChanged => 'study_day_changed',
      };

  static TutorAuditAction fromJson(String value) => switch (value) {
        'config_changed' => TutorAuditAction.configChanged,
        'completion_bulk_prior' => TutorAuditAction.completionBulkPrior,
        'completion_reset' => TutorAuditAction.completionReset,
        'bookmark_advanced' => TutorAuditAction.bookmarkAdvanced,
        'profile_edited' => TutorAuditAction.profileEdited,
        'goal_changed' => TutorAuditAction.goalChanged,
        'stage_changed' => TutorAuditAction.stageChanged,
        'reward_changed' => TutorAuditAction.rewardChanged,
        'study_day_changed' => TutorAuditAction.studyDayChanged,
        _ => throw ArgumentError('Unknown TutorAuditAction: $value'),
      };
}

/// A single audit log entry recording one tutor-originated mutation.
class TutorAuditLogEntry {
  const TutorAuditLogEntry({
    required this.entryId,
    required this.tutorUid,
    required this.tutorNameSnapshot,
    required this.action,
    required this.target,
    required this.timestamp,
    this.beforeValue,
    this.afterValue,
  });

  /// ULID entry ID.
  final String entryId;

  /// UID of the tutor who performed the action.
  final String tutorUid;

  /// Display name captured at write-time.
  /// Preserved even after the tutor deletes their account (FR-7.2).
  final String tutorNameSnapshot;

  /// Type of action performed.
  final TutorAuditAction action;

  /// Identifies the specific field or entity mutated.
  /// E.g. "goal/{goalId}.targetDate" or "stage/{stageId}.delayDays".
  final String target;

  /// Value before the mutation (serialised as JSON string).
  final String? beforeValue;

  /// Value after the mutation (serialised as JSON string).
  final String? afterValue;

  /// When the action was performed.
  final DateTime timestamp;

  Map<String, dynamic> toFirestore() => {
        'entry_id': entryId,
        'tutor_uid': tutorUid,
        'tutor_name_snapshot': tutorNameSnapshot,
        'action': action.toJson(),
        'target': target,
        if (beforeValue != null) 'before_value': beforeValue,
        if (afterValue != null) 'after_value': afterValue,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory TutorAuditLogEntry.fromFirestore(Map<String, dynamic> data) =>
      TutorAuditLogEntry(
        entryId: data['entry_id'] as String,
        tutorUid: data['tutor_uid'] as String,
        tutorNameSnapshot: data['tutor_name_snapshot'] as String,
        action: TutorAuditAction.fromJson(data['action'] as String),
        target: data['target'] as String,
        beforeValue: data['before_value'] as String?,
        afterValue: data['after_value'] as String?,
        timestamp: DateTime.parse(data['timestamp'] as String).toLocal(),
      );
}
