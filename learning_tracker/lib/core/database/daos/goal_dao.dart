import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';

part 'goal_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<UserDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

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

  Future<int> deleteGoalsByCurriculum(String curriculumId) =>
      (delete(goals)..where((t) => t.curriculumId.equals(curriculumId))).go();

  // ========== Track-Scoped Queries (Story 20.2) ==========

  /// Get the goal for a specific track (single goal per track).
  Future<Goal?> getGoalByTrack(int trackId) =>
      (select(goals)..where((t) => t.trackId.equals(trackId)))
          .getSingleOrNull();

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
  /// Per Epic 20 / DNI-212, each track owns at most one goal. This variant
  /// matches by [trackId] alone (not by description), so two tracks in the
  /// same curriculum can have independent goals without collision.
  /// Last-write-wins on [updatedAt].
  Future<void> upsertGoalByTrack({
    required int trackId,
    required String curriculumId,
    required String description,
    required double targetPercent,
    required DateTime? targetDate,
    String dateType = 'gregorian',
    String goalType = 'deadline',
    int? paceValue,
    String? paceUnit,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final existing = await getGoalByTrack(trackId);

    if (existing == null) {
      await insertGoal(
        GoalsCompanion.insert(
          curriculumId: curriculumId,
          trackId: trackId,
          description: Value(description),
          targetPercent: Value(targetPercent),
          targetDate: Value(targetDate),
          dateType: Value(dateType),
          goalType: Value(goalType),
          paceValue: Value(paceValue),
          paceUnit: Value(paceUnit),
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
          paceUnit: Value(paceUnit),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }

  /// Upsert a goal by curriculum and description (last-write-wins per D4).
  ///
  /// Matches by [curriculumId] and [description]. Inserts if not found,
  /// or updates if remote [updatedAt] is newer than local.
  Future<void> upsertGoal({
    required String curriculumId,
    required int trackId,
    required String description,
    required double targetPercent,
    required DateTime? targetDate,
    String dateType = 'gregorian',
    String goalType = 'deadline',
    int? paceValue,
    String? paceUnit,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final existing =
        await (select(goals)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.description.equals(description),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await insertGoal(
        GoalsCompanion.insert(
          curriculumId: curriculumId,
          trackId: trackId,
          description: Value(description),
          targetPercent: Value(targetPercent),
          targetDate: Value(targetDate),
          dateType: Value(dateType),
          goalType: Value(goalType),
          paceValue: Value(paceValue),
          paceUnit: Value(paceUnit),
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
          paceUnit: Value(paceUnit),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }
}
