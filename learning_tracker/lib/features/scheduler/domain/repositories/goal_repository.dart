import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

/// Repository interface for goal CRUD operations.
abstract class GoalRepository {
  /// Create a new goal for a curriculum.
  ///
  /// [paceTarget] is the sealed discriminant that carries all goal-mode data:
  /// - [DeadlineTarget] for deadline-based goals (targetDate inside)
  /// - [PacePeriodTarget] for pace-based goals (rate + period inside)
  /// - `null` for "no goal" / goalType='none'
  ///
  /// [profileId] is the learner profile that owns the goal (must match the
  /// track's profile when creating from add-track / onboarding). It must
  /// also match the profile the repository instance itself was constructed
  /// for — implementations throw `GoalProfileMismatchException`
  /// (AUD-scheduler-03) otherwise.
  Future<GoalEntity> createGoal({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
    required double targetPercent,
    PaceTarget? paceTarget,
    String description,
    String dateType,
    String? paceGranularity,
  });

  /// Get all goals for a curriculum, sorted by target date.
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId);

  /// Update an existing goal's pace target and/or other fields.
  ///
  /// [paceTarget] is the sealed discriminant. Pass `null` with
  /// [clearPaceTarget] == `true` to remove the goal mode entirely.
  ///
  /// [paceGranularity] is the typed learning-unit granularity. When provided,
  /// it takes precedence over any previously stored unit. Passing
  /// [clearLearningUnit] == `true` removes the learning unit entirely.
  ///
  /// [goal] is passed by value rather than by row number (owner decision 4,
  /// `docs/firestore-rewrite-map.md`) — Firestore has no integer identity, so
  /// a Drift-only `int goalId` could never be implemented against a
  /// Firestore-backed repository. [goal] must belong to the profile the
  /// repository instance was constructed for — implementations throw
  /// `GoalProfileMismatchException` (AUD-scheduler-03) otherwise.
  Future<GoalEntity> updateGoal({
    required GoalEntity goal,
    double? targetPercent,
    PaceTarget? paceTarget,
    bool clearPaceTarget,
    String? description,
    PaceGranularity? paceGranularity,
    bool clearLearningUnit,
  });

  /// Delete a goal.
  ///
  /// [goal] is passed by value — see [updateGoal]'s doc comment. It must
  /// belong to the profile the repository instance was constructed for —
  /// implementations throw `GoalProfileMismatchException` (AUD-scheduler-03)
  /// otherwise. Deleting an already-absent goal is a no-op.
  Future<void> deleteGoal(GoalEntity goal);
}
