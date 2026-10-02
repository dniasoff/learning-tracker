// Mirror test for `lib/domain/learner_state/goals.dart` (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';

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
}
