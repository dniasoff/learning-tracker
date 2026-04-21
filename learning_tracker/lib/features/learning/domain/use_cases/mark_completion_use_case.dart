import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
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
  /// Returns the created completion record.
  ///
  /// Throws [StageProgressionException] if stage progression is violated.
  Future<Completion> call(CompletionRequest request) async {
    return await _repository.markComplete(request);
  }
}
