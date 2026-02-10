import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';

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
  /// - Advances bookmark to next item in learning order
  /// - Triggers Firestore sync
  ///
  /// All operations are performed in a single database transaction for
  /// atomicity. If any operation fails, the entire transaction is rolled back.
  ///
  /// Throws [StageProgressionException] if attempting to complete stage N+1
  /// before stage N for the same content item.
  Future<Completion> markComplete(CompletionRequest request);

  /// Mark multiple content items as completed in a single transaction.
  ///
  /// Creates individual completion records for each item. If any operation
  /// fails, the entire transaction is rolled back.
  ///
  /// Returns the list of created completions.
  Future<List<Completion>> bulkMarkComplete(BulkCompletionRequest request);

  /// Get all completions for a specific curriculum.
  Future<List<Completion>> getCompletionsByCurriculum(String curriculumId);

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
class StageProgressionException implements Exception {
  final String message;
  final int attemptedStage;
  final int? lastCompletedStage;

  StageProgressionException({
    required this.message,
    required this.attemptedStage,
    this.lastCompletedStage,
  });

  @override
  String toString() => 'StageProgressionException: $message';
}
