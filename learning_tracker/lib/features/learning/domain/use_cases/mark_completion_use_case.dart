import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';

/// Use case for marking a single content item as completed.
///
/// Orchestrates the completion flow, gating side effects according to
/// the [CompletionSource] discriminator (B1 three-tier credit policy):
///
/// ```
/// Tier              | Streak / Points | Siyumim / Reports | Lifetime data
/// ──────────────────┼─────────────────┼───────────────────┼──────────────
/// live              |       ✓         |        ✓          |      ✓
/// bulkInTrack       |       ✗         |        ✓          |      ✓
/// lifetimeOnly      |       ✗         |        ✗          |      ✓
/// ```
///
/// The source is encoded into the repository request so the data layer
/// can persist the correct `priorMarkOnly` flag and suppress streak events:
///   - [CompletionSource.live] → `awardGamificationPoints = true`, streak
///     event written.
///   - [CompletionSource.bulkInTrack] → `awardGamificationPoints = false`,
///     no streak event. Completions stored with `priorMarkOnly = true`.
///   - [CompletionSource.lifetimeOnly] → same as `bulkInTrack` at the
///     data level; no achievement side effects at the use-case level.
class MarkCompletionUseCase {
  const MarkCompletionUseCase(this._orchestrator, {AnalyticsService? analytics})
    : _analytics = analytics;

  /// Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
  /// owner decision 1): this use case now goes through
  /// [CompletionOrchestrator] rather than [CompletionRepository] directly —
  /// the orchestrator owns order validation, points, siyum detection,
  /// bookmark advance and streak, none of which the repository does any
  /// more. See [CompletionOrchestrator]'s class doc comment.
  final CompletionOrchestrator _orchestrator;
  // W7.11: optional analytics — fires B1 regression telemetry when non-live
  // completions enter this use case.
  final AnalyticsService? _analytics;

  /// Execute the use case to mark a content item as completed.
  ///
  /// [source] controls which handler tiers fire (B1 policy). When omitted
  /// the default is [CompletionSource.live] so existing callers that have
  /// not yet been migrated to pass an explicit source continue to behave
  /// correctly.
  ///
  /// Returns the completion record and any new reward milestone unlocks.
  /// [MarkCompletionResult.newMilestoneUnlocks] is empty when
  /// [source.creditsEngagement] is false (achievement rewards suppressed
  /// for bulk and lifetime sources).
  ///
  /// Throws [StageProgressionException] if stage progression is violated.
  Future<MarkCompletionResult> call(
    CompletionRequest request, {
    CompletionSource source = CompletionSource.live,
  }) async {
    // B1 regression telemetry (W7.11):
    // When a non-live source reaches this use case, fire a telemetry event to
    // confirm the engagement gate is active. These events should be ABSENT in
    // normal operation for engagement-only handlers (streak/points). Their
    // presence confirms the source arrived correctly; their ABSENCE in the DB
    // handler (where engagement is suppressed) would be the regression signal.
    if (source == CompletionSource.bulkInTrack) {
      // BulkInTrack: engagement suppressed, achievement enabled. This is NOT
      // a regression — the event name reflects that we are skipping engagement
      // credit intentionally.
      await _analytics?.logEvent(AnalyticsEvent.bulkEngagementSkipped);
    } else if (source == CompletionSource.lifetimeOnly) {
      // LifetimeOnly: both engagement and achievement suppressed. This is NOT
      // a regression — the event name reflects that we are skipping achievement
      // credit intentionally.
      await _analytics?.logEvent(AnalyticsEvent.lifetimeAchievementSkipped);
    }

    // B1 three-tier policy: pass the engagement and achievement gates
    // independently. Previously the repository's completionDetectionService
    // call was wired to the engagement gate, which meant bulkInTrack (which
    // suppresses engagement but should credit achievement) wrongly skipped
    // siyum detection. The achievement gate is now distinct.
    //
    //   - live          → engagement=true,  achievement=true
    //   - bulkInTrack   → engagement=false, achievement=true  (earns siyum)
    //   - lifetimeOnly  → engagement=false, achievement=false
    //
    // Lifetime-tier (coverage counters) is unconditional — every completion
    // enters the DB regardless of source.
    return _orchestrator.markComplete(
      request,
      awardGamificationPoints: source.creditsEngagement,
      creditsAchievement: source.creditsAchievement,
    );
  }
}
