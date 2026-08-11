import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';

/// Repository interface for completion operations.
///
/// Defines the contract for marking content items as completed,
/// with stage progression validation, points calculation, and
/// bookmark advancement.
abstract class CompletionRepository {
  /// Mark a single content item as completed for a specific stage.
  ///
  /// This operation:
  /// - Validates stage progression (must complete stage N before N+1)
  /// - Checks for duplicates (idempotent - returns existing if already complete)
  /// - Calculates and awards points based on curriculum configuration
  ///   (only when [awardGamificationPoints] is true — B1 policy)
  /// - Advances bookmark to next item in learning order
  /// - Triggers Firestore sync
  ///
  /// All operations are performed in a single database transaction for
  /// atomicity. If any operation fails, the entire transaction is rolled back.
  ///
  /// ### B1 — Three-tier credit policy
  /// [awardGamificationPoints] controls the **engagement** tier (streak events,
  /// point awards, milestone unlocks). Pass `false` for `bulkInTrack` and
  /// `lifetimeOnly` sources.
  ///
  /// [creditsAchievement] controls the **achievement** tier (siyum detection
  /// via `CompletionDetectionService`, study-report indexing). Pass `true`
  /// for `live` and `bulkInTrack`; pass `false` only for `lifetimeOnly`
  /// historical imports.
  ///
  /// The engagement and achievement gates are independent — `bulkInTrack`
  /// suppresses engagement but credits achievement (so a learner who
  /// bulk-marks a complete masechta still earns the siyum).
  ///
  /// [MarkCompletionUseCase] is the canonical caller and always passes the
  /// correct values derived from `CompletionSource`.
  ///
  /// Throws [StageProgressionException] if attempting to complete stage N+1
  /// before stage N for the same content item.
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  });

  /// Mark multiple content items as completed in a single transaction.
  ///
  /// Creates individual completion records for each item. If any operation
  /// fails, the entire transaction is rolled back.
  ///
  /// Returns the list of created completions.
  Future<List<CompletionEntity>> bulkMarkComplete(BulkCompletionRequest request);

  /// Get all completions for a specific curriculum.
  ///
  /// [profileId] defaults to the repository's session profile when omitted.
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  });

  /// Get all completions for a specific content item by sefariaRef.
  Future<List<CompletionEntity>> getCompletionsForContentItem(String sefariaRef);

  /// Total review count per sefariaRef within [curriculumId] (AC-3, AC-7).
  /// Achievement data — throws when the backend is not ready rather than
  /// returning an empty map indistinguishable from "no reviews yet".
  Future<Map<String, int>> getReviewCountsForCurriculum(
    CurriculumId curriculumId,
  );

  /// Per-stage review-count breakdown for [sefariaRef] within [curriculumId]
  /// (AC-1, AC-5). Same achievement-data throw contract as
  /// [getReviewCountsForCurriculum].
  Future<Map<int, int>> getStageBreakdownForItem({
    required CurriculumId curriculumId,
    required String sefariaRef,
  });

  /// Check if a specific stage has been completed for a content item by sefariaRef.
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  });

  /// Tombstone a bulk-prior completion document (B8 / D-L).
  ///
  /// Delegates to `FirestoreCompletionRepository.purgeCompletion`: stamps
  /// `purged_at` on the document keyed by (curriculumId, sefariaRef, stageId).
  /// `firestore.rules` denies `delete`, so erasure is always a tombstone.
  Future<void> purgeCompletion({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
    required DateTime purgedAt,
  });
}

/// Exception thrown when attempting to complete a stage out of order.
class StageProgressionException extends ValidationException {
  StageProgressionException({
    required String message,
    required this.attemptedStage,
    this.lastCompletedStage,
  }) : super(message);

  final int attemptedStage;
  final int? lastCompletedStage;
}
