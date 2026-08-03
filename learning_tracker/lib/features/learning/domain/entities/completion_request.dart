/// Request to mark a content item as completed.
///
/// Immutable value object containing all data needed to create a completion record.
class CompletionRequest {
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;

  /// Gamification points to persist on the written completion row.
  ///
  /// **Storage-layer field, not a storage-computed value.** Point
  /// calculation (config lookup, child/track eligibility) is a business
  /// rule owned by `CompletionOrchestrator`
  /// (`lib/features/learning/domain/services/completion_orchestrator.dart`)
  /// — the orchestrator computes this value BEFORE calling
  /// `CompletionRepository.markComplete` and passes it through here so the
  /// storage layer only ever persists a number it was handed, never derives
  /// one. Defaults to 0 so every pre-existing caller that does not set it
  /// (e.g. a bulk-prior request, which never earns points) is unaffected.
  final int points;

  const CompletionRequest({
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    this.points = 0,
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

  /// Gamification points to persist on every inserted completion row —
  /// see [CompletionRequest.points]'s doc comment for why this is a
  /// storage-facing field set by `CompletionOrchestrator`, not computed by
  /// the repository. All items in one bulk call share a single stageId (and
  /// therefore a single point value), so unlike [CompletionRequest] this is
  /// one value applied uniformly, not per-item. Defaults to 0, matching
  /// [awardGamificationPoints]'s default-true-but-currently-unused-by-any-
  /// live-caller path: today's only production bulk caller
  /// (`BulkPriorCompletionService`) always passes
  /// `awardGamificationPoints: false`, so no live call site sets this yet.
  final int points;

  const BulkCompletionRequest({
    required this.curriculumId,
    required this.sefariaRefs,
    required this.stageId,
    required this.trackType,
    this.profileId,
    this.awardGamificationPoints = true,
    this.creditsAchievement = false,
    this.completedAt,
    this.points = 0,
  });
}
