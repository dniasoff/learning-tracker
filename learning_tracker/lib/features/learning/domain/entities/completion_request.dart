/// Request to mark a content item as completed.
///
/// Immutable value object containing all data needed to create a completion record.
class CompletionRequest {
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;

  const CompletionRequest({
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
  });
}

/// Request to mark multiple content items as completed (bulk operation).
class BulkCompletionRequest {
  final String curriculumId;
  final List<String> sefariaRefs;
  final int stageId;
  final String trackType;

  /// When set, completions and bookmark updates target this profile (e.g. add
  /// track for a child while the session active profile differs).
  final int? profileId;

  /// When false, each inserted completion stores [points] as 0 — used for
  /// onboarding "prior learning" bulk marks so gamification reflects daily
  /// track study only.
  final bool awardGamificationPoints;

  const BulkCompletionRequest({
    required this.curriculumId,
    required this.sefariaRefs,
    required this.stageId,
    required this.trackType,
    this.profileId,
    this.awardGamificationPoints = true,
  });
}
