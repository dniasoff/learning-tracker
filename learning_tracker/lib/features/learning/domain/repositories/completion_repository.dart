import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
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
  /// [awardGamificationPoints] controls the engagement tier (streak events,
  /// point awards). Pass `false` for [CompletionSource.bulkInTrack] and
  /// [CompletionSource.lifetimeOnly] sources. [MarkCompletionUseCase] is
  /// the canonical caller and always passes the correct value.
  ///
  /// Throws [StageProgressionException] if attempting to complete stage N+1
  /// before stage N for the same content item.
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
  });

  /// Mark multiple content items as completed in a single transaction.
  ///
  /// Creates individual completion records for each item. If any operation
  /// fails, the entire transaction is rolled back.
  ///
  /// Returns the list of created completions.
  Future<List<Completion>> bulkMarkComplete(BulkCompletionRequest request);

  /// Get all completions for a specific curriculum.
  ///
  /// [profileId] defaults to the repository's session profile when omitted.
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  });

  /// Get all completions for a specific content item by sefariaRef.
  Future<List<Completion>> getCompletionsForContentItem(String sefariaRef);

  /// Check if a specific stage has been completed for a content item by sefariaRef.
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
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
