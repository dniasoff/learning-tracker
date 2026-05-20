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

  /// When true, after the bulk insert completes, [CompletionDetectionService]
  /// is dispatched for the parent units of every inserted completion so unit-
  /// and aggregate-level siyumim land in the `learning_ledger`. This is the
  /// achievement-tier gate for the bulk path — independent of
  /// [awardGamificationPoints], which is the engagement-tier gate.
  ///
  /// Per the B1 three-tier credit policy:
  ///   - `bulkInTrack`  → engagement=false, achievement=true
  ///   - `lifetimeOnly` → engagement=false, achievement=false
  final bool creditsAchievement;

  /// When set, overrides the timestamp written to each completion row.
  /// Pass [DateTime.utc(2000, 1, 1)] for bulk-mark-prior so the completions
  /// are recorded in the distant past and do not inflate the current streak.
  /// When null, each completion receives [DateTimeFactory.nowUtc()] at write time.
  final DateTime? completedAt;

  const BulkCompletionRequest({
    required this.curriculumId,
    required this.sefariaRefs,
    required this.stageId,
    required this.trackType,
    this.profileId,
    this.awardGamificationPoints = true,
    this.creditsAchievement = false,
    this.completedAt,
  });
}
