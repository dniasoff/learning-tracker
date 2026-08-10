import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'goal_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<UserDatabase>
    with _$GoalDaoMixin, BaseDao<$GoalsTable, Goal, UserDatabase> {
  GoalDao(super.db);

  @override
  TableInfo<$GoalsTable, Goal> get table => goals;

  @override
  Expression<int> idColumn($GoalsTable t) => t.id;

  @override
  Expression<int> profileIdColumn($GoalsTable t) => t.profileId;

  /// Returns every goal for every profile on this device.
  ///
  /// AUD-guardrails-01: intentionally NOT profile-scoped. Its only two
  /// production callers — `DataExportImportService` (whole-account JSON
  /// export/import) and `LocalDataUploadService` (bulk local→cloud upload) —
  /// deliberately operate across every profile on the account and preserve
  /// each row's own `profileId` field. Adding a profileId filter here would
  /// silently drop other profiles' goals from account-level export/upload.
  /// Callers that need one profile's goals should use [getGoalsByProfile].
  Future<List<Goal>> getAllGoals() => select(goals).get();

  // ========== Profile-Scoped Queries ==========

  /// Get goals for a curriculum scoped to a specific profile.
  Future<List<Goal>> getGoalsByCurriculumAndProfile(
    String curriculumId,
    int profileId,
  ) =>
      (select(goals)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.profileId.equals(profileId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
          .get();

  /// Get all goals for a specific profile.
  Future<List<Goal>> getGoalsByProfile(int profileId) =>
      (select(goals)..where((t) => t.profileId.equals(profileId))).get();

  Future<Goal?> getGoalById(int id) =>
      (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Goal>> getGoalsByCurriculum(String curriculumId) =>
      (select(goals)
            ..where((t) => t.curriculumId.equals(curriculumId))
            ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
          .get();

  Future<int> insertGoal(GoalsCompanion entry) => into(goals).insert(entry);

  Future<bool> updateGoal(GoalsCompanion entry) => update(goals).replace(entry);

  Future<int> deleteGoal(int id) =>
      (delete(goals)..where((t) => t.id.equals(id))).go();

  /// Deletes every goal for [curriculumId] scoped to [profileId].
  ///
  /// AUD-guardrails-01: previously filtered by curriculumId alone, so two
  /// profiles sharing a curriculumId (e.g. two children both tracking
  /// Mishnayos) would have BOTH of their goals wiped by one profile's
  /// cleanup call. `profileId` is required to keep this call cross-profile
  /// safe by construction.
  Future<int> deleteGoalsByCurriculum(String curriculumId, int profileId) =>
      (delete(goals)..where(
            (t) =>
                t.curriculumId.equals(curriculumId) &
                t.profileId.equals(profileId),
          ))
          .go();

  // ========== Track-Scoped Queries (Story 20.2) ==========

  /// Get the goal for a specific track (single goal per track).
  Future<Goal?> getGoalByTrack(int trackId) => (select(
    goals,
  )..where((t) => t.trackId.equals(trackId))).getSingleOrNull();

  /// Get all goals for a specific track.
  Future<List<Goal>> getGoalsByTrack(int trackId) =>
      (select(goals)
            ..where((t) => t.trackId.equals(trackId))
            ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
          .get();

  /// Delete all goals for a specific track.
  Future<int> deleteGoalsForTrack(int trackId) =>
      (delete(goals)..where((t) => t.trackId.equals(trackId))).go();

  /// Upsert a goal keyed by trackId (one goal per track invariant).
  ///
  /// Per Epic 20 / DNI-212, each track owns at most one goal. Matches by
  /// [trackId] alone so two tracks in the same curriculum can have independent
  /// goals without collision. Last-write-wins on [updatedAt].
  ///
  /// This is the single consolidated upsert entry-point — the legacy
  /// `upsertGoal` (keyed by curriculumId+description) was removed in DNI-347.
  Future<void> upsertGoalByTrack({
    required int profileId,
    required int trackId,
    required String curriculumId,
    required String description,
    required double targetPercent,
    required DateTime? targetDate,
    String dateType = 'gregorian',
    String goalType = 'deadline',
    int? paceValue,
    String? pacePeriod,
    String? paceGranularity,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final existing = await getGoalByTrack(trackId);

    if (existing == null) {
      await insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          description: Value(description),
          targetPercent: Value(targetPercent),
          targetDate: Value(targetDate),
          dateType: Value(dateType),
          goalType: Value(goalType),
          paceValue: Value(paceValue),
          pacePeriod: Value(pacePeriod),
          paceGranularity: Value(paceGranularity),
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    } else if (updatedAt.isAfter(existing.updatedAt)) {
      await (update(goals)..where((t) => t.id.equals(existing.id))).write(
        GoalsCompanion(
          targetPercent: Value(targetPercent),
          targetDate: Value(targetDate),
          description: Value(description),
          dateType: Value(dateType),
          goalType: Value(goalType),
          paceValue: Value(paceValue),
          pacePeriod: Value(pacePeriod),
          paceGranularity: Value(paceGranularity),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }
}
