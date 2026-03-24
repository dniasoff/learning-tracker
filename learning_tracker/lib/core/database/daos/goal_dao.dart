import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';

part 'goal_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
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

  /// Upsert a goal by curriculum and description (last-write-wins per D4).
  ///
  /// Matches by [curriculumId] and [description]. Inserts if not found,
  /// or updates if remote [updatedAt] is newer than local.
  Future<void> upsertGoal({
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
