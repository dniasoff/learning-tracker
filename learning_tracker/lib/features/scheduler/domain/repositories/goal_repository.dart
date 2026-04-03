import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

/// Repository interface for goal CRUD operations.
abstract class GoalRepository {
  /// Create a new goal for a curriculum.
  ///
  /// [targetDate] is stored as UTC per P5. If the date originates from a
  /// Hebrew date picker, it must be converted to Gregorian UTC before calling.
  Future<GoalEntity> createGoal({
    required CurriculumId curriculumId,
    required int trackId,
    required double targetPercent,
    DateTime? targetDate,
    String description,
    String dateType,
    String goalType,
    int? paceValue,
    String? paceUnit,
    String? learningUnit,
  });

  /// Get all goals for a curriculum, sorted by target date.
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId);

  /// Update an existing goal's deadline and/or target percentage.
  Future<GoalEntity> updateGoal({
    required int goalId,
    double? targetPercent,
    DateTime? targetDate,
    bool clearTargetDate,
    String? description,
    String? goalType,
    int? paceValue,
    String? paceUnit,
    bool clearPace,
  });

  /// Delete a goal.
  Future<void> deleteGoal(int goalId);
}
