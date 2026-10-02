// TutorPermissions — VO (W4.28, AD-53 / DNI-487)
//
// Single source of truth for the boolean policy fields that govern what a
// tutor can do on a tutored learner profile.
//
// Stored as a nested map (`permissions`) within the tutor_grants/{grantId}
// Firestore document. Cloud Functions read this map to authorise write
// operations.
//
// AD-53 (Story 1.25 / DNI-487): ONE permission — `can_edit_learning` —
// authorises every learning and governed-entity write (tracks, deadline,
// study days, goals, learning records). It replaces the five legacy keys
// `can_edit_goals`, `can_edit_stages`, `can_edit_study_days`,
// `can_reset_completion` and `can_bulk_prior_completion`, which are no longer
// modelled, serialised or shown. It is set only by parent action: the
// pre-checked invite checkbox, or the parent-only `updateTutorGrantPermissions`
// callable. A grant WITHOUT the field (every pre-AD-53 grant) is read as
// `false` — existing tutors stay read-only until the parent opts them in
// (prd-deviations #7).
//
// `can_view_progress`, `can_view_content`, `can_edit_rewards` and
// `can_edit_points` are unchanged.
//
// Legacy keys still present on old grant documents are tolerated on read (and
// ignored) until the retired callables are deleted (DNI-488).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'tutor_permissions.freezed.dart';

/// Firestore key of the AD-53 single learning-edit permission.
const String kCanEditLearningKey = 'can_edit_learning';

/// The five retired per-operation edit keys (AD-53). Never written by the
/// client; listed so tests and codecs can assert their absence.
const List<String> kLegacyTutorEditPermissionKeys = <String>[
  'can_edit_goals',
  'can_edit_stages',
  'can_edit_study_days',
  'can_reset_completion',
  'can_bulk_prior_completion',
];

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

    /// AD-53: tutor can change the learner's tracks, deadline and learning
    /// records (every learning and governed-entity write). Fails closed: the
    /// default is `false`; the invite form pre-checks it explicitly.
    @Default(false) bool canEditLearning,

    /// Tutor can configure reward settings (points per item, etc.).
    @Default(true) bool canEditRewards,

    /// H5: Tutor can configure point settings and apply manual point
    /// adjustments (`parent_points_adjust`). Distinct from [canEditLearning]
    /// and [canEditRewards] (reward catalogue).
    @Default(true) bool canEditPoints,
  }) = _TutorPermissions;

  /// Intentionally NOT a constructor field — always false, and therefore
  /// structurally excluded from the generated `==`/`hashCode`/`copyWith`.
  /// Tutors can never set this regardless of parent configuration; the
  /// Cloud Function enforces the invariant independently.
  bool get canMarkLiveCompletion => false;

  /// Default permissions for a grant whose document carries no explicit
  /// learning-edit choice: view progress/content, rewards and points on;
  /// [canEditLearning] OFF (AD-53 fail-closed).
  factory TutorPermissions.defaults() => const TutorPermissions();

  /// Minimal read-only permissions (progress + content view only).
  factory TutorPermissions.readOnly() =>
      const TutorPermissions(canEditRewards: false, canEditPoints: false);

  /// Serialise to the nested Firestore map stored in tutor_grants/{grantId}.
  ///
  /// Never emits any of [kLegacyTutorEditPermissionKeys].
  Map<String, dynamic> toFirestore() => {
    // canMarkLiveCompletion is intentionally omitted — it is always false
    // and the Cloud Function enforces it independently. Storing it would
    // allow a rogue client to read it and think it might change.
    'can_view_progress': canViewProgress,
    'can_view_content': canViewContent,
    kCanEditLearningKey: canEditLearning,
    'can_edit_rewards': canEditRewards,
    'can_edit_points': canEditPoints,
  };

  /// Tolerant decode: legacy keys on pre-AD-53 grants are ignored, and a
  /// missing or non-boolean `can_edit_learning` reads as `false`.
  factory TutorPermissions.fromFirestore(Map<String, dynamic> data) =>
      TutorPermissions(
        canViewProgress: data['can_view_progress'] as bool? ?? true,
        canViewContent: data['can_view_content'] as bool? ?? true,
        canEditLearning: data[kCanEditLearningKey] == true,
        canEditRewards: data['can_edit_rewards'] as bool? ?? true,
        canEditPoints: data['can_edit_points'] as bool? ?? true,
      );

  /// Overrides the freezed-generated `toString()` to keep the explicit
  /// `markLive=false[invariant]` marker: [canMarkLiveCompletion] is a
  /// computed getter (not a constructor field), so freezed's generated
  /// `toString()` omits it entirely. Callers/tests rely on the marker being
  /// visibly present whenever a TutorPermissions is logged or printed, as a
  /// belt-and-braces reminder that the invariant is hard-coded and cannot be
  /// toggled — the Cloud Function enforces it independently either way.
  @override
  String toString() =>
      'TutorPermissions('
      'viewProgress=$canViewProgress, '
      'viewContent=$canViewContent, '
      'editLearning=$canEditLearning, '
      'editRewards=$canEditRewards, '
      'editPoints=$canEditPoints, '
      'markLive=false[invariant])';
}
