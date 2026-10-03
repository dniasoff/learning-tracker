// Spaced-review steps and the reviews due on a civil date (delay, weekly
// and rolling stage schedules).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/main_track_config_history.dart';
import 'package:learning_tracker/domain/learner_state/review_schedule.dart';

ReviewStep _step(
  String leaf, {
  StageScheduleType type = StageScheduleType.delay,
  String openedOn = '2026-09-07',
  int openedMinute = 0,
  String dueFrom = '2026-09-09',
  Set<int> daysOfWeek = const {},
  int? windowSize,
  String? completedOn,
}) => ReviewStep(
  leaf: leaf,
  stageOrder: 2,
  scheduleType: type,
  openedOn: openedOn,
  openedAt: DateTime.utc(2026, 9, 7).add(Duration(minutes: openedMinute)),
  openedBy: 'event-$leaf',
  dueFrom: dueFrom,
  daysOfWeek: daysOfWeek,
  windowSize: windowSize,
  completedOn: completedOn,
);

void main() {
  test('a delay review is due from dueFrom until it is completed', () {
    final step = _step('A 1:1');
    final schedule = ReviewSchedule([step]);
    expect(schedule.stepFor('A 1:1', 2), step);
    expect(schedule.stepFor('A 1:1', 3), isNull);
    expect(schedule.dueOn('2026-09-08'), isEmpty);
    expect(schedule.dueOn('2026-09-10'), [
      const ReviewDue('A 1:1', 2, dueFrom: '2026-09-09'),
    ]);
    expect(schedule.dueForAttempt(step, '2026-09-08'), isFalse);
    expect(schedule.dueForAttempt(step, '2026-09-09'), isTrue);

    final done = _step('A 1:1', completedOn: '2026-09-10');
    expect(done.openOn('2026-09-10'), isTrue);
    expect(done.openOn('2026-09-11'), isFalse);
    expect(ReviewSchedule([done]).dueOn('2026-09-11'), isEmpty);
  });

  test('a weekly review is due on its weekdays only', () {
    // 2026-09-07 is a Monday (1); 2026-09-09 a Wednesday (3).
    final step = _step(
      'A 1:2',
      type: StageScheduleType.weekly,
      daysOfWeek: const {3},
    );
    final schedule = ReviewSchedule([step]);
    expect(schedule.dueOn('2026-09-08'), isEmpty);
    expect(schedule.dueOn('2026-09-09').single.dueFrom, '2026-09-09');
    expect(schedule.dueForAttempt(step, '2026-09-09'), isTrue);
    expect(schedule.dueForAttempt(step, '2026-09-10'), isFalse);
  });

  test('a rolling review is due only for the newest open steps that fit '
      'the window', () {
    final older = _step(
      'A 1:1',
      type: StageScheduleType.rolling,
      windowSize: 2,
    );
    final middle = _step(
      'A 1:2',
      type: StageScheduleType.rolling,
      openedMinute: 1,
      windowSize: 2,
    );
    final newest = _step(
      'A 1:3',
      type: StageScheduleType.rolling,
      openedMinute: 2,
      windowSize: 2,
    );
    final schedule = ReviewSchedule([older, middle, newest]);
    expect(
      [for (final d in schedule.dueOn('2026-09-08')) d.leaf],
      ['A 1:2', 'A 1:3'],
    );
    expect(schedule.dueForAttempt(older, '2026-09-08'), isFalse);
    expect(schedule.dueForAttempt(newest, '2026-09-08'), isTrue);
    expect(schedule, ReviewSchedule([older, middle, newest]));
  });
}
