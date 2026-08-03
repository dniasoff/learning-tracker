import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
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
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    final rows = await _database.completionDao
        .getCompletionsByCurriculumAndProfile(curriculumId, _profileId);
    return rows.map(_toCompletionEntity).whereType<CompletionEntity>().toList();
  }

  @override
  Future<List<CompletionEntity>> getAllCompletions() async {
    final rows = await _database.completionDao.getCompletionsByProfile(
      _profileId,
    );
    return rows.map(_toCompletionEntity).whereType<CompletionEntity>().toList();
  }

  /// Converts a Drift [Completion] row into the storage-agnostic
  /// [CompletionEntity] [ProgressRepository]'s interface now returns (owner
  /// decision 3, `docs/firestore-rewrite-map.md`) — drops the autoincrement
  /// [Completion.id], the redundant `profileId` (already the scope of this
  /// repository instance), and the AD-25-retired `trackId`, mirroring what
  /// [CompletionEntity]'s own class doc comment documents as deliberately
  /// absent. Returns `null` (skipping the row, logged) for a `curriculumId`
  /// that does not resolve to a known [CurriculumId] — mirrors
  /// `FirestoreGoalRepository._decodeAll`'s "one bad row should not blank
  /// the list" treatment.
  ///
  /// [CompletionEntity.source] is set to [CompletionSource.live]
  /// unconditionally: the Drift `completions` view carries no tier/source
  /// column of its own — live vs. bulk-imported is a *correlated* fact
  /// against the separate `prior_completion_imports` table, computed only by
  /// `CompletionDao.getCompletionsByTier` (a different method this class
  /// does not call). This is a deliberate simplification, not a claim of
  /// accuracy: at the time of writing, [getCompletionsByCurriculum] and
  /// [getAllCompletions] have no consumer that reads `.source` (or ever did
  /// — `completionHistoryForCurriculumProvider|allCompletionHistoryProvider`
  /// just pass the list straight through). A future caller that needs an
  /// accurate tier here should route through `getCompletionsByTier` instead
  /// of trusting this default.
  CompletionEntity? _toCompletionEntity(Completion row) {
    final curriculumId = CurriculumId.fromStorageKey(row.curriculumId);
    if (curriculumId == null) {
      AppLogger.instance.warning(
        event: 'progress_repository_unknown_curriculum',
        fields: {'curriculumId': row.curriculumId},
      );
      return null;
    }
    return CompletionEntity(
      curriculumId: curriculumId,
      sefariaRef: row.sefariaRef,
      stageId: row.stageId,
      trackType: row.trackType,
      source: CompletionSource.live,
      completedAt: row.completedAt,
      points: row.points,
    );
  }
}
