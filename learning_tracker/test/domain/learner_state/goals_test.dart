// Mirror test for `lib/domain/learner_state/goals.dart` (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

void main() {
  const deadline = DeadlineGoal(
    curriculumId: 'mishnayos',
    targetDate: '2027-06-01',
  );
  const pace = PaceGoal(
    curriculumId: 'mishnayos',
    paceValue: 2,
    paceUnit: 'mishnah',
    paceGranularity: 'day',
  );

  test('goals compare by value', () {
    expect(
      deadline,
      const DeadlineGoal(curriculumId: 'mishnayos', targetDate: '2027-06-01'),
    );
    expect(
      deadline,
      isNot(
        const DeadlineGoal(curriculumId: 'mishnayos', targetDate: '2027-06-02'),
      ),
    );
    expect(
      pace,
      const PaceGoal(
        curriculumId: 'mishnayos',
        paceValue: 2,
        paceUnit: 'mishnah',
        paceGranularity: 'day',
      ),
    );
    expect(
      const CurriculumGoals(deadline: deadline, pace: pace),
      const CurriculumGoals(deadline: deadline, pace: pace),
    );
  });

  test('CurriculumGoals defaults to no goals', () {
    const none = CurriculumGoals();
    expect(none.deadline, isNull);
    expect(none.pace, isNull);
  });

  group('storage codecs (DNI-470)', () {
    final ended = DateTime.utc(2026, 9, 1);

    test('round-trip at the fixed doc ids', () {
      final d = DeadlineGoal(
        curriculumId: 'mishnayos',
        targetDate: '2027-06-01',
        lastChangeId: '01ARZ3NDEKTSV4RRFFQ69G5FAA',
        endedAt: ended,
      );
      expect(DeadlineGoal.fromStorage('mishnayos_deadline', d.toStorage()), d);
      expect(PaceGoal.fromStorage('mishnayos_pace', pace.toStorage()), pace);
      expect(deadlineGoalDocId('mishnayos'), 'mishnayos_deadline');
      expect(paceGoalDocId('mishnayos'), 'mishnayos_pace');
      expect(pace.toStorage(), {
        'goal_type': 'pace',
        'pace_value': 2,
        'pace_unit': 'mishnah',
        'pace_granularity': 'day',
        'curriculum_id': 'mishnayos',
      });
    });

    test('legacy keys are ignored and never re-emitted', () {
      final decoded = DeadlineGoal.fromStorage('mishnayos_deadline', {
        ...deadline.toStorage(),
        'target_percent': 100,
        'updated_at': ended,
      });
      expect(decoded, deadline);
      expect(decoded.toStorage().keys, isNot(contains('target_percent')));
    });

    test('a wrong type, id, date or pace is rejected', () {
      final bad = <String, void Function()>{
        'pace doc as deadline': () =>
            DeadlineGoal.fromStorage('mishnayos_deadline', pace.toStorage()),
        'deadline at a legacy id': () =>
            DeadlineGoal.fromStorage('g-123', deadline.toStorage()),
        'not a civil date': () => DeadlineGoal.fromStorage(
          'mishnayos_deadline',
          {...deadline.toStorage(), 'target_date': 'June'},
        ),
        'zero pace': () => PaceGoal.fromStorage('mishnayos_pace', {
          ...pace.toStorage(),
          'pace_value': 0,
        }),
        'pace at the deadline id': () =>
            PaceGoal.fromStorage('mishnayos_deadline', pace.toStorage()),
      };
      for (final MapEntry(key: why, value: decode) in bad.entries) {
        expect(decode, throwsA(isA<StorageFormatException>()), reason: why);
      }
    });
  });
}
