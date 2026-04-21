import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';

/// Use case for marking multiple content items as completed in a single operation.
///
/// Useful for "mark this whole perek as learned" scenarios.
class BulkMarkCompletionUseCase {
  final CompletionRepository _repository;

  BulkMarkCompletionUseCase(this._repository);

  /// Execute the use case to mark multiple items as completed.
  ///
  /// Creates individual completion records for each item in a single transaction.
  /// If any operation fails, the entire transaction is rolled back.
  ///
  /// Returns the list of created completions.
  Future<List<Completion>> call(BulkCompletionRequest request) async {
    return await _repository.bulkMarkComplete(request);
  }
}
