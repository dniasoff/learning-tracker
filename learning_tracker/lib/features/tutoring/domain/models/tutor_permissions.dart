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

/// Immutable value object encapsulating tutor permissions for a single grant.
///
/// The ONLY immutable invariant: [canMarkLiveCompletion] is always `false`.
/// Tutors are NEVER permitted to write live-forward completions regardless of
/// parent configuration. The Cloud Function enforces this independently.
class TutorPermissions {
  const TutorPermissions({
    this.canViewProgress = true,
    this.canViewContent = true,
    this.canBulkPriorCompletion = true,
    this.canResetCompletion = false,
    this.canEditGoals = false,
    this.canEditStages = false,
    this.canEditRewards = false,
    this.canEditStudyDays = false,
    this.canEditPoints = false,
  }) : canMarkLiveCompletion = false;

  // Intentionally not in constructor — always false.
  // ignore: prefer_const_constructors_in_immutables (it IS const — the field is final)
  final bool canMarkLiveCompletion;

  /// Tutor can view the learner's progress dashboards and reports.
  final bool canViewProgress;

  /// Tutor can browse and navigate the curriculum content.
  final bool canViewContent;

  /// Tutor can submit bulk-prior completions (via Cloud Function proxy).
  final bool canBulkPriorCompletion;

  /// Tutor can reset completion state for a specific item.
  final bool canResetCompletion;

  /// Tutor can create, edit, or delete learning goals.
  final bool canEditGoals;

  /// Tutor can change stage configuration (delay days, pace).
  final bool canEditStages;

  /// Tutor can configure reward settings (points per item, etc.).
  final bool canEditRewards;

  /// Tutor can change the learner's scheduled study days.
  final bool canEditStudyDays;

  /// H5: Tutor can configure point settings and apply manual point
  /// adjustments (`parent_points_adjust`). Distinct from [canEditGoals]
  /// (learning goals) and [canEditRewards] (reward catalogue).
  final bool canEditPoints;

  /// Default permissions for a newly accepted grant.
  ///
  /// Read-only (progress, content) + bulk prior completions enabled.
  /// All mutating permissions are off by default — the parent must explicitly
  /// enable them.
  factory TutorPermissions.defaults() => const TutorPermissions();

  /// Minimal read-only permissions (progress + content view only).
  factory TutorPermissions.readOnly() =>
      const TutorPermissions(canBulkPriorCompletion: false);

  TutorPermissions copyWith({
    bool? canViewProgress,
    bool? canViewContent,
    bool? canBulkPriorCompletion,
    bool? canResetCompletion,
    bool? canEditGoals,
    bool? canEditStages,
    bool? canEditRewards,
    bool? canEditStudyDays,
    bool? canEditPoints,
  }) => TutorPermissions(
    canViewProgress: canViewProgress ?? this.canViewProgress,
    canViewContent: canViewContent ?? this.canViewContent,
    canBulkPriorCompletion:
        canBulkPriorCompletion ?? this.canBulkPriorCompletion,
    canResetCompletion: canResetCompletion ?? this.canResetCompletion,
    canEditGoals: canEditGoals ?? this.canEditGoals,
    canEditStages: canEditStages ?? this.canEditStages,
    canEditRewards: canEditRewards ?? this.canEditRewards,
    canEditStudyDays: canEditStudyDays ?? this.canEditStudyDays,
    canEditPoints: canEditPoints ?? this.canEditPoints,
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
        canEditGoals: data['can_edit_goals'] as bool? ?? false,
        canEditStages: data['can_edit_stages'] as bool? ?? false,
        canEditRewards: data['can_edit_rewards'] as bool? ?? false,
        canEditStudyDays: data['can_edit_study_days'] as bool? ?? false,
        canEditPoints: data['can_edit_points'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TutorPermissions &&
          other.canViewProgress == canViewProgress &&
          other.canViewContent == canViewContent &&
          other.canBulkPriorCompletion == canBulkPriorCompletion &&
          other.canResetCompletion == canResetCompletion &&
          other.canEditGoals == canEditGoals &&
          other.canEditStages == canEditStages &&
          other.canEditRewards == canEditRewards &&
          other.canEditStudyDays == canEditStudyDays &&
          other.canEditPoints == canEditPoints;

  @override
  int get hashCode => Object.hash(
    canViewProgress,
    canViewContent,
    canBulkPriorCompletion,
    canResetCompletion,
    canEditGoals,
    canEditStages,
    canEditRewards,
    canEditStudyDays,
    canEditPoints,
  );

  @override
  String toString() =>
      'TutorPermissions('
      'viewProgress=$canViewProgress, '
      'viewContent=$canViewContent, '
      'bulkPrior=$canBulkPriorCompletion, '
      'resetCompletion=$canResetCompletion, '
      'editGoals=$canEditGoals, '
      'editStages=$canEditStages, '
      'editRewards=$canEditRewards, '
      'editStudyDays=$canEditStudyDays, '
      'editPoints=$canEditPoints, '
      'markLive=false[invariant])';
}
