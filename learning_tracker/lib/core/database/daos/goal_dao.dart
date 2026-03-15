import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';

part 'goal_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  Future<List<Goal>> getAllGoals() => select(goals).get();

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
}
