/// Story 2.4 (DNI-495) AC-6: the goal chosen from a sub-track form's
/// no-deadline link maps onto the AD-43 fixed-id goal docs as a governed
/// action carrying changed fields only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/features/sub_tracks/domain/governed_goal_change.dart';

const _c = 'mishnayos';
final _now = DateTime.utc(2026, 10, 2, 9);

GovernedAction? _action(GoalChoice choice, [CurriculumGoals? current]) =>
    governedGoalAction(
      curriculumId: _c,
      choice: choice,
      current: current,
      nowUtc: _now,
    );

GovernedEntityChange _goal(String docId, Map<String, Object?> fields) =>
    GovernedEntityChange(
      entity: GovernedEntity.goal,
      entityId: docId,
      docs: [
        GovernedDocPatch(collection: 'goals', docId: docId, fields: fields),
      ],
    );

const _pace = PaceGoal(
  curriculumId: _c,
  paceValue: 2,
  paceUnit: 'per_day',
  paceGranularity: 'perek',
);

void main() {
  test('fixed AD-43 doc ids', () {
    expect(deadlineGoalDocId(_c), 'mishnayos_deadline');
    expect(paceGoalDocId(_c), 'mishnayos_pace');
  });

  test('a first deadline creates goals/{c}_deadline with its full fields', () {
    expect(
      _action(const DeadlineGoalChoice('2028-06-01')),
      GovernedAction([
        _goal('mishnayos_deadline', {
          'goal_type': 'deadline',
          'curriculum_id': _c,
          'target_date': '2028-06-01',
        }),
      ]),
    );
  });

  test('a deadline next to a pace goal leaves the pace goal alone', () {
    expect(
      _action(
        const DeadlineGoalChoice('2028-06-01'),
        const CurriculumGoals(pace: _pace),
      )!.changes.map((c) => c.entityId),
      ['mishnayos_deadline'],
    );
  });

  test('a changed deadline writes only target_date', () {
    expect(
      _action(
        const DeadlineGoalChoice('2029-01-01'),
        const CurriculumGoals(
          deadline: DeadlineGoal(curriculumId: _c, targetDate: '2028-06-01'),
        ),
      ),
      GovernedAction([
        _goal('mishnayos_deadline', {'target_date': '2029-01-01'}),
      ]),
    );
  });

  test('an unchanged deadline is no action', () {
    expect(
      _action(
        const DeadlineGoalChoice('2028-06-01'),
        const CurriculumGoals(
          deadline: DeadlineGoal(curriculumId: _c, targetDate: '2028-06-01'),
        ),
      ),
      isNull,
    );
  });

  test('an ended deadline is revived by clearing ended_at', () {
    expect(
      _action(
        const DeadlineGoalChoice('2028-06-01'),
        CurriculumGoals(
          deadline: DeadlineGoal(
            curriculumId: _c,
            targetDate: '2027-06-01',
            endedAt: DateTime.utc(2026),
          ),
        ),
      ),
      GovernedAction([
        _goal('mishnayos_deadline', {
          'target_date': '2028-06-01',
          'ended_at': null,
        }),
      ]),
    );
  });

  test('a pace goal writes goals/{c}_pace; a change only its fields', () {
    expect(
      _action(
        const PaceGoalChoice(value: 2, unit: 'per_day', granularity: 'perek'),
      ),
      GovernedAction([
        _goal('mishnayos_pace', {
          'goal_type': 'pace',
          'curriculum_id': _c,
          'pace_value': 2,
          'pace_unit': 'per_day',
          'pace_granularity': 'perek',
        }),
      ]),
    );
    expect(
      _action(
        const PaceGoalChoice(value: 3, unit: 'per_day', granularity: 'perek'),
        const CurriculumGoals(pace: _pace),
      ),
      GovernedAction([
        _goal('mishnayos_pace', {'pace_value': 3}),
      ]),
    );
  });

  test('no goal ends every live goal doc and nothing else', () {
    expect(
      _action(
        const NoGoalChoice(),
        const CurriculumGoals(
          deadline: DeadlineGoal(curriculumId: _c, targetDate: '2028-06-01'),
          pace: _pace,
        ),
      ),
      GovernedAction([
        _goal('mishnayos_deadline', {'ended_at': _now}),
        _goal('mishnayos_pace', {'ended_at': _now}),
      ]),
    );
    expect(_action(const NoGoalChoice()), isNull);
  });
}
