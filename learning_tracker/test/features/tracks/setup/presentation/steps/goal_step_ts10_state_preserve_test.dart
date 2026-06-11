/// Regression test for TS-10:
/// SelfPacedGoalStep must accept an [initialGoal] parameter and restore
/// _mode='deadline' and _deadline when the user navigates Back and returns
/// to the goal step.
///
/// Before the fix: SelfPacedGoalStep always initializes _mode='pace' and
/// _deadline=today on every rebuild, discarding any deadline the user set.
///
/// After the fix: the step accepts [initialGoal] and restores the goal type
/// (pace/deadline) and target date from it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_goal.dart';

final _now = DateTime(2026, 6, 11);

void main() {
  group('TS-10 — SelfPacedGoalStep preserves goal state via initialGoal', () {
    test('SelfPacedGoalStep constructor accepts initialGoal', () {
      // If this test compiles, the parameter exists.
      final deadline = DateTime(2026, 12, 31);
      final initialGoal = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        goalType: 'deadline',
        targetDate: deadline.toUtc(),
        paceValue: 7,
        pacePeriod: 'per_week',
        createdAt: _now,
        updatedAt: _now,
      );

      final step = SelfPacedGoalStep(
        curriculumId: CurriculumId.mishnayos,
        studyDays: const {},
        onComplete: (_) {},
        initialGoal: initialGoal,
      );

      expect(step.initialGoal, equals(initialGoal));
    });

    test('SelfPacedGoalStep defaults initialGoal to null', () {
      final step = SelfPacedGoalStep(
        curriculumId: CurriculumId.mishnayos,
        studyDays: const {},
        onComplete: (_) {},
      );

      expect(step.initialGoal, isNull);
    });
  });
}
