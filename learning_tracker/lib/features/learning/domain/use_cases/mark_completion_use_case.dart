import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/tutor_mode/domain/tutor_mode_provider.dart';

/// Use case for marking a single content item as completed.
///
/// Orchestrates the completion flow including validation,
/// points calculation, bookmark advancement, and sync.
class MarkCompletionUseCase {
  final CompletionRepository _repository;
  final bool _isTutorMode;

  MarkCompletionUseCase(this._repository, {bool isTutorMode = false})
      : _isTutorMode = isTutorMode;

  /// Execute the use case to mark a content item as completed.
  ///
  /// Returns the created completion record.
  ///
  /// Throws [TutorModeReadOnlyException] if tutor mode is active.
  /// Throws [StageProgressionException] if stage progression is violated.
  Future<Completion> call(CompletionRequest request) async {
    guardTutorModeWriteFromBool(_isTutorMode);
    return await _repository.markComplete(request);
  }
}
