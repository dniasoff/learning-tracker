import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';

/// Use case for marking a single content item as completed.
///
/// Orchestrates the completion flow including validation,
/// points calculation, bookmark advancement, and sync.
class MarkCompletionUseCase {
  final CompletionRepository _repository;

  MarkCompletionUseCase(this._repository);

  /// Execute the use case to mark a content item as completed.
  ///
  /// Returns the completion record and any new reward milestone unlocks.
  ///
  /// Throws [StageProgressionException] if stage progression is violated.
  Future<MarkCompletionResult> call(CompletionRequest request) async {
    return _repository.markComplete(request);
  }
}
