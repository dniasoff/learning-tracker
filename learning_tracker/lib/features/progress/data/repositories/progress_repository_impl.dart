import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';

/// Implementation of [ProgressRepository] using Drift database.
class ProgressRepositoryImpl implements ProgressRepository {
  final UserDatabase _database;

  ProgressRepositoryImpl({required UserDatabase database})
    : _database = database;

  @override
  Future<Map<TrackType, int>> getTrackBreakdown(String curriculumId) async {
    // Get the breakdown from the DAO (returns Map<String, int>)
    final rawBreakdown = await _database.completionDao.getTrackBreakdown(
      curriculumId,
    );

    // Convert string keys to TrackType enum keys
    final result = <TrackType, int>{};

    // Initialize all track types with zero counts
    for (final trackType in TrackType.values) {
      result[trackType] = 0;
    }

    // Populate with actual counts from database
    for (final entry in rawBreakdown.entries) {
      try {
        final trackType = TrackType.fromStorageKey(entry.key);
        result[trackType] = entry.value;
      } on ArgumentError {
        // Skip invalid track types (defensive - shouldn't happen)
        continue;
      }
    }

    return result;
  }

  @override
  Future<int> getAggregateCount(String curriculumId) async {
    return await _database.completionDao.getAggregateCount(curriculumId);
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    return await _database.completionDao.getCompletionsByCurriculum(
      curriculumId,
    );
  }

  @override
  Future<List<Completion>> getAllCompletions() async {
    return await _database.completionDao.getAllCompletions();
  }
}
