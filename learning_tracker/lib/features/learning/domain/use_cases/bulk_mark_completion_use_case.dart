import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';

/// Use case for marking multiple content items as completed in a single operation.
///
/// Orchestrates the bulk completion flow, gating engagement side effects
/// according to the [CompletionSource] discriminator (B1 three-tier credit
/// policy). This mirrors exactly what [MarkCompletionUseCase] does for the
/// single-item path.
///
/// ```
/// Tier              | Streak / Points | Siyumim / Reports | Lifetime data
/// ──────────────────┼─────────────────┼───────────────────┼──────────────
/// live              |       ✓         |        ✓          |      ✓
/// bulkInTrack       |       ✗         |        ✓          |      ✓
/// lifetimeOnly      |       ✗         |        ✗          |      ✓
/// ```
///
/// The default source is [CompletionSource.bulkInTrack] because this is the
/// bulk use case — callers that perform prior-learning wizard bulk-marks must
/// NOT credit engagement (streak + points). Passing
/// [CompletionSource.lifetimeOnly] additionally suppresses the achievement tier.
class BulkMarkCompletionUseCase {
  /// Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
  /// owner decision 1): goes through [CompletionOrchestrator] rather than
  /// `CompletionRepository` directly — see [MarkCompletionUseCase]'s doc
  /// comment for why.
  final CompletionOrchestrator _orchestrator;

  BulkMarkCompletionUseCase(this._orchestrator);

  /// Execute the use case to mark multiple items as completed.
  ///
  /// [source] controls which handler tiers fire (B1 policy). Defaults to
  /// [CompletionSource.bulkInTrack] — engagement suppressed, achievement and
  /// lifetime tiers active — because bulk operations represent prior learning
  /// that should not inflate the current streak or award points.
  ///
  /// Creates individual completion records for each item in a single transaction.
  /// If any operation fails, the entire transaction is rolled back.
  ///
  /// Returns the list of created completions.
  Future<List<CompletionEntity>> call(
    BulkCompletionRequest request, {
    CompletionSource source = CompletionSource.bulkInTrack,
  }) async {
    // B1: derive the engagement gate from the source discriminator.
    // For bulkInTrack / lifetimeOnly the flag maps to false so the repository
    // correctly suppresses streak events and point awards.
    //
    // The achievement gate is independent — bulkInTrack credits achievement
    // (the user earns the siyum) while lifetimeOnly does not.
    // B1 sentinel: for any non-live source (bulkInTrack / lifetimeOnly),
    // completedAt MUST be the sentinel date DateTime.utc(2000, 1, 1) so the
    // stored rows fall below any "completedAt >= trackStartDate" threshold used
    // by streak math and pace calculations. The caller may pass the sentinel
    // explicitly; when they don't (completedAt == null), we enforce it here so
    // no caller can accidentally write a live timestamp for a prior-mark row.
    //
    // For live source, pass the caller's value through (null → nowUtc() inside
    // the repository, explicit value for test injection).
    // D3 telemetry: log which tier(s) are being bypassed for non-live sources.
    // These events confirm the three-tier credit policy is enforced on the bulk
    // path — their presence is expected; their absence would signal a regression.
    if (source == CompletionSource.bulkInTrack) {
      AppLogger.instance.info(
        event: LogEvents.track.bulkEngagementSkipped,
        fields: {
          'source': source.name,
          'item_count': request.sefariaRefs.length,
        },
      );
    } else if (source == CompletionSource.lifetimeOnly) {
      AppLogger.instance.info(
        event: LogEvents.track.lifetimeAchievementSkipped,
        fields: {
          'source': source.name,
          'item_count': request.sefariaRefs.length,
        },
      );
    }

    final effectiveCompletedAt = source.creditsEngagement
        ? request.completedAt
        : kBulkPriorSentinelDate;

    final gatedRequest = BulkCompletionRequest(
      curriculumId: request.curriculumId,
      sefariaRefs: request.sefariaRefs,
      stageId: request.stageId,
      trackType: request.trackType,
      awardGamificationPoints: source.creditsEngagement,
      creditsAchievement: source.creditsAchievement,
      completedAt: effectiveCompletedAt,
    );
    return await _orchestrator.bulkMarkComplete(gatedRequest);
  }
}
