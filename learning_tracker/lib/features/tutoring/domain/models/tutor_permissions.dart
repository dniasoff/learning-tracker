// TutorPermissions — VO (W4.28)
//
// Single source of truth for the 8 boolean policy fields that govern what a
// tutor can do on a tutored learner profile.
//
// Stored as a nested map (`permissions`) within the tutor_grants/{grantId}
// Firestore document. Cloud Functions read this map to authorise write
// operations (e.g. tutorBulkPriorCompletions checks canBulkPriorCompletion).
//
// The parent can configure these flags when sending the invite (or later via
// the settings screen). Defaults are the most permissive values that still
// preserve the hard security invariant (canMarkLiveCompletion is always false —
// it is not configurable).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'tutor_permissions.freezed.dart';

/// Immutable value object encapsulating tutor permissions for a single grant.
///
/// The ONLY immutable invariant: [canMarkLiveCompletion] is always `false`.
/// Tutors are NEVER permitted to write live-forward completions regardless of
/// parent configuration. The Cloud Function enforces this independently.
@freezed
abstract class TutorPermissions with _$TutorPermissions {
  // Private const constructor required for the custom canMarkLiveCompletion
  // getter and toFirestore/fromFirestore methods below.
  const TutorPermissions._();

  const factory TutorPermissions({
    /// Tutor can view the learner's progress dashboards and reports.
    @Default(true) bool canViewProgress,

    /// Tutor can browse and navigate the curriculum content.
    @Default(true) bool canViewContent,

    /// Tutor can submit bulk-prior completions (via Cloud Function proxy).
    @Default(true) bool canBulkPriorCompletion,

    /// Tutor can reset completion state for a specific item.
    @Default(false) bool canResetCompletion,

    /// Tutor can create, edit, or delete learning goals.
    @Default(true) bool canEditGoals,

    /// Tutor can change stage configuration (delay days, pace).
    @Default(true) bool canEditStages,

    /// Tutor can configure reward settings (points per item, etc.).
    @Default(true) bool canEditRewards,

    /// Tutor can change the learner's scheduled study days.
    @Default(true) bool canEditStudyDays,

    /// H5: Tutor can configure point settings and apply manual point
    /// adjustments (`parent_points_adjust`). Distinct from [canEditGoals]
    /// (learning goals) and [canEditRewards] (reward catalogue).
    @Default(true) bool canEditPoints,
  }) = _TutorPermissions;

  /// Intentionally NOT a constructor field — always false, and therefore
  /// structurally excluded from the generated `==`/`hashCode`/`copyWith`.
  /// Tutors can never set this regardless of parent configuration; the
  /// Cloud Function enforces the invariant independently.
  bool get canMarkLiveCompletion => false;

  /// Default permissions for a newly accepted grant.
  ///
  /// Read-only (progress, content) + bulk prior completions enabled.
  /// All mutating permissions are off by default — the parent must explicitly
  /// enable them.
  factory TutorPermissions.defaults() => const TutorPermissions();

  /// Minimal read-only permissions (progress + content view only).
  factory TutorPermissions.readOnly() => const TutorPermissions(
    canBulkPriorCompletion: false,
    canEditGoals: false,
    canEditStages: false,
    canEditRewards: false,
    canEditStudyDays: false,
    canEditPoints: false,
  );

  /// Serialise to the nested Firestore map stored in tutor_grants/{grantId}.
  Map<String, dynamic> toFirestore() => {
    // canMarkLiveCompletion is intentionally omitted — it is always false
    // and the Cloud Function enforces it independently. Storing it would
    // allow a rogue client to read it and think it might change.
    'can_view_progress': canViewProgress,
    'can_view_content': canViewContent,
    'can_bulk_prior_completion': canBulkPriorCompletion,
    'can_reset_completion': canResetCompletion,
    'can_edit_goals': canEditGoals,
    'can_edit_stages': canEditStages,
    'can_edit_rewards': canEditRewards,
    'can_edit_study_days': canEditStudyDays,
    'can_edit_points': canEditPoints,
  };

  factory TutorPermissions.fromFirestore(Map<String, dynamic> data) =>
      TutorPermissions(
        canViewProgress: data['can_view_progress'] as bool? ?? true,
        canViewContent: data['can_view_content'] as bool? ?? true,
        canBulkPriorCompletion:
            data['can_bulk_prior_completion'] as bool? ?? true,
        canResetCompletion: data['can_reset_completion'] as bool? ?? false,
        canEditGoals: data['can_edit_goals'] as bool? ?? true,
        canEditStages: data['can_edit_stages'] as bool? ?? true,
        canEditRewards: data['can_edit_rewards'] as bool? ?? true,
        canEditStudyDays: data['can_edit_study_days'] as bool? ?? true,
        canEditPoints: data['can_edit_points'] as bool? ?? true,
      );
}
