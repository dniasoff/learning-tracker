import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';

/// Implementation of [ProgressRepository] using Drift database.
///
/// All queries are scoped to a single profile. Constructing one impl
/// per active profile keeps progress data isolated between profiles on
/// the same account.
class ProgressRepositoryImpl implements ProgressRepository {
  final UserDatabase _database;
  final int _profileId;

  ProgressRepositoryImpl({required UserDatabase database, int profileId = 0})
    : _database = database,
      _profileId = profileId;

  @override
  Future<Map<String, int>> getTrackBreakdown(String curriculumId) async {
    return _database.completionDao.getTrackBreakdownByProfile(
      curriculumId,
      _profileId,
    );
  }

  @override
  Future<int> getAggregateCount(String curriculumId) async {
    return await _database.completionDao.getAggregateCountByProfile(
      curriculumId,
      _profileId,
    );
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    return await _database.completionDao.getCompletionsByCurriculumAndProfile(
      curriculumId,
      _profileId,
    );
  }

  @override
  Future<List<Completion>> getAllCompletions() async {
    return await _database.completionDao.getCompletionsByProfile(_profileId);
  }
}
