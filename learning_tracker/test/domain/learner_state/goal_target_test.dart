// AD-43/AD-44 goal targets: live goal selection, the deadline daily target
// and the pace rate in leaves per study day.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goal_target.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

PaceGoal _pace(num value, String unit, String granularity) => PaceGoal(
  curriculumId: engineCurriculum,
  paceValue: value,
  paceUnit: unit,
  paceGranularity: granularity,
);

void main() {
  const deadline = DeadlineGoal(
    curriculumId: engineCurriculum,
    targetDate: '2026-09-13',
  );

  test('liveDeadline and livePace ignore ended goals', () {
    final ended = DeadlineGoal(
      curriculumId: engineCurriculum,
      targetDate: '2026-09-13',
      endedAt: DateTime.utc(2026, 9),
    );
    expect(liveDeadline(null), isNull);
    expect(liveDeadline(const CurriculumGoals(deadline: deadline)), deadline);
    expect(liveDeadline(CurriculumGoals(deadline: ended)), isNull);
    final pace = _pace(1, 'per_day', 'mishnah');
    expect(livePace(CurriculumGoals(pace: pace)), pace);
    expect(livePace(const CurriculumGoals()), isNull);
  });

  test('deadlineDailyTarget rounds up over the remaining study days', () {
    final everyDay = StudyDays.everyDay();
    // Monday 2026-09-07 .. Sunday 2026-09-13: 7 study days.
    expect(
      deadlineDailyTarget(
        numerator: 9,
        deadline: deadline,
        studyDays: everyDay,
        today: '2026-09-07',
      ),
      2,
    );
    // No study days left: the whole remainder is due today, never negative.
    expect(
      deadlineDailyTarget(
        numerator: 4,
        deadline: deadline,
        studyDays: everyDay,
        today: '2026-09-14',
      ),
      4,
    );
    expect(
      deadlineDailyTarget(
        numerator: -3,
        deadline: deadline,
        studyDays: everyDay,
        today: '2026-09-07',
      ),
      0,
    );
  });

  test('paceRateOf converts the pace unit into leaves per study day', () {
    final corpus = mishnayosCorpus();
    bool all(_) => true;
    expect(
      paceRateOf(
        pace: _pace(2, 'per_day', 'mishnah'),
        corpus: corpus,
        inScope: all,
        studyDays: StudyDays.everyDay(),
      ),
      2,
    );
    // 9 leaves over 4 chapters = 2.25 leaves per chapter, spread over the
    // 3 study days of the week.
    expect(
      paceRateOf(
        pace: _pace(1, perWeekPaceUnit, 'chapter'),
        corpus: corpus,
        inScope: all,
        studyDays: StudyDays(studyWeekdays: {1, 3, 5}, activeWeekdays: {}),
      ),
      closeTo(0.75, 1e-9),
    );
  });
}
