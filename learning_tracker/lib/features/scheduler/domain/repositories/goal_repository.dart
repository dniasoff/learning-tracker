import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

/// Repository interface for goal CRUD operations.
abstract class GoalRepository {
  /// Create a new goal for a curriculum.
  ///
  /// [targetDate] is stored as UTC per P5. If the date originates from a
  /// Hebrew date picker, it must be converted to Gregorian UTC before calling.
  ///
  /// [profileId] is the learner profile that owns the goal (must match the
  /// track's profile when creating from add-track / onboarding).
  Future<GoalEntity> createGoal({
    required int profileId,
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
  ///
  /// [paceGranularity] is the typed learning-unit granularity. When provided,
  /// it takes precedence over any previously stored unit. Passing
  /// [clearLearningUnit] == `true` removes the learning unit entirely.
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
    PaceGranularity? paceGranularity,
    bool clearLearningUnit,
  });

  /// Delete a goal.
  Future<void> deleteGoal(int goalId);
}
