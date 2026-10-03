// Calendar-program planning (AD-43): per-date assignments, the backlog
// since the amnesty anchor and today's target.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/calendar_plan.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  final plan = CalendarPlan(
    assignments: {
      '2026-09-08': ['B 1:2'],
      '2026-09-07': ['B 1:1', 'B 1:2'],
      '2026-09-09': ['B 1:3'],
    },
    amnestyFrom: '2026-09-07',
    learnt: {'B 1:1'},
  );

  test('assignments are per date; unknown dates have none', () {
    expect(plan.assignments('2026-09-07'), ['B 1:1', 'B 1:2']);
    expect(plan.assignments('2026-09-01'), isEmpty);
  });

  test('backlog holds unlearnt leaves assigned before today, once each', () {
    expect(plan.backlog('2026-09-07'), isEmpty);
    expect(plan.backlog('2026-09-09'), ['B 1:2']);
  });

  test('dailyTarget counts unlearnt leaves up to and including today', () {
    expect(plan.dailyTarget('2026-09-08'), 1);
    expect(plan.dailyTarget('2026-09-09'), 2);
  });

  test('no amnesty anchor means no backlog and no target', () {
    final unanchored = CalendarPlan(
      assignments: {
        '2026-09-07': ['B 1:1'],
      },
      amnestyFrom: null,
      learnt: const {},
    );
    expect(unanchored.backlog('2026-09-09'), isEmpty);
    expect(unanchored.dailyTarget('2026-09-09'), isNull);
  });

  test('equal plans compare equal', () {
    expect(
      plan,
      CalendarPlan(
        assignments: {
          '2026-09-07': ['B 1:1', 'B 1:2'],
          '2026-09-08': ['B 1:2'],
          '2026-09-09': ['B 1:3'],
        },
        amnestyFrom: '2026-09-07',
        learnt: {'B 1:1'},
      ),
    );
  });

  test('only a live main track with a live calendar program follows one', () {
    expect(followsCalendarProgram(null), isFalse);
    expect(followsCalendarProgram(engineIntent()), isFalse);
  });
}
