import 'package:drift/drift.dart';

import 'package:learning_tracker/core/database/app_database.dart';

/// Service to prevent duplicate completions for the same content item and stage.
///
/// This service enforces the rule that a content item can only be completed
/// once for a given stage within a curriculum, regardless of track type.
class DuplicatePreventionService {
  final AppDatabase _database;

  DuplicatePreventionService(this._database);

  /// Checks if a completion can be created for the given parameters.
  ///
  /// Returns true if no prior completion exists for the same
  /// [curriculumId], [contentItemId], and [stageId].
  ///
  /// Returns false if a completion already exists, preventing duplicates.
  Future<bool> canComplete({
    required String curriculumId,
    required int contentItemId,
    required int stageId,
  }) async {
    final existing = await getExistingCompletion(
      curriculumId: curriculumId,
      contentItemId: contentItemId,
      stageId: stageId,
    );
    return existing == null;
  }

  /// Retrieves an existing completion for the given parameters.
  ///
  /// Returns the completion record if one exists, or null if none found.
  /// This is useful for getting details about the existing completion
  /// (e.g., which track it was completed under) for error messages.
  Future<Completion?> getExistingCompletion({
    required String curriculumId,
    required int contentItemId,
    required int stageId,
  }) async {
    return (_database.select(_database.completions)..where(
          (t) =>
              t.curriculumId.equals(curriculumId) &
              t.contentItemId.equals(contentItemId) &
              t.stageId.equals(stageId),
        ))
        .getSingleOrNull();
  }
}
