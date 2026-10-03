// Mirror test for `lib/domain/learner_state/goal_target.dart`: the AD-44
// deadline daily target and the AD-43 pace rate.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goal_target.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

DeadlineGoal _deadline(String date, {DateTime? endedAt}) => DeadlineGoal(
  curriculumId: engineCurriculum,
  targetDate: date,
  endedAt: endedAt,
);

PaceGoal _pace(
  num value,
  String unit,
  String granularity, {
  DateTime? endedAt,
}) => PaceGoal(
  curriculumId: engineCurriculum,
  paceValue: value,
  paceUnit: unit,
  paceGranularity: granularity,
  endedAt: endedAt,
);

void main() {
  group('liveDeadline / livePace', () {
    test('null goals yield null', () {
      expect(liveDeadline(null), isNull);
      expect(livePace(null), isNull);
      expect(liveDeadline(const CurriculumGoals()), isNull);
      expect(livePace(const CurriculumGoals()), isNull);
    });

    test('a live goal is returned, an ended one is not', () {
      final live = CurriculumGoals(
        deadline: _deadline('2026-12-01'),
        pace: _pace(1, 'per_day', 'mishnah'),
      );
      expect(liveDeadline(live), live.deadline);
      expect(livePace(live), live.pace);

      final ended = CurriculumGoals(
        deadline: _deadline('2026-12-01', endedAt: DateTime.utc(2026, 9)),
        pace: _pace(1, 'per_day', 'mishnah', endedAt: DateTime.utc(2026, 9)),
      );
      expect(liveDeadline(ended), isNull);
      expect(livePace(ended), isNull);
    });
  });

  group('deadlineDailyTarget', () {
    final all = StudyDays.everyDay();

    int target(
      int numerator,
      String deadline, {
      StudyDays? days,
      String today = '2026-09-07',
    }) => deadlineDailyTarget(
      numerator: numerator,
      deadline: _deadline(deadline),
      studyDays: days ?? all,
      today: today,
    );

    test('rounds the share per study day up', () {
      // 2026-09-07 .. 2026-09-16 is 10 days.
      expect(target(100, '2026-09-16'), 10);
      expect(target(101, '2026-09-16'), 11);
      expect(target(1, '2026-09-16'), 1);
      expect(target(0, '2026-09-16'), 0);
    });

    test('only study days divide the numerator', () {
      final weekdaysOnly = StudyDays(
        studyWeekdays: {1, 2, 3, 4, 5},
        activeWeekdays: {1, 2, 3, 4, 5, 6, 7},
      );
      // Mon 7th .. Sun 13th = 5 study days.
      expect(target(10, '2026-09-13', days: weekdaysOnly), 2);
      expect(target(11, '2026-09-13', days: weekdaysOnly), 3);
    });

    test('a zero divisor returns the whole numerator', () {
      final monOnly = StudyDays(studyWeekdays: {1}, activeWeekdays: {1, 2});
      // Deadline Tue 8th: [7th, 8th] holds Monday, divisor 1.
      expect(target(7, '2026-09-08', days: monOnly), 7);
      // Deadline today (Tue 8th) on a non-study day: divisor 0.
      expect(target(7, '2026-09-08', days: monOnly, today: '2026-09-08'), 7);
      // A past deadline: divisor 0.
      expect(target(9, '2026-09-01'), 9);
    });

    test('is never negative', () {
      expect(target(-5, '2026-09-16'), 0);
      expect(target(-5, '2026-09-01'), 0);
    });
  });

  group('paceRateOf', () {
    final corpus = mishnayosCorpus();
    bool all(String _) => true;

    double rate(
      PaceGoal pace, {
      bool Function(String)? inScope,
      StudyDays? d,
    }) => paceRateOf(
      pace: pace,
      corpus: corpus,
      inScope: inScope ?? all,
      studyDays: d ?? StudyDays.everyDay(),
    );

    test('a granularity naming no level counts leaves', () {
      expect(rate(_pace(3, 'per_day', 'mishnah')), 3);
      expect(rate(_pace(2, 'per_day', 'nonsense')), 2);
    });

    test('per_week spreads the weekly amount over all seven days', () {
      expect(rate(_pace(14, 'per_week', 'mishnah')), 2);
    });

    test('per_week divides by the study weekdays', () {
      final fiveDays = StudyDays(
        studyWeekdays: {1, 2, 3, 4, 5},
        activeWeekdays: {1, 2, 3, 4, 5},
      );
      expect(rate(_pace(10, 'per_week', 'mishnah'), d: fiveDays), 2);
    });

    test('per_week on all-review days divides by one', () {
      final none = StudyDays(studyWeekdays: {}, activeWeekdays: {1});
      expect(rate(_pace(4, 'per_week', 'mishnah'), d: none), 4);
    });

    test('a level converts at the average leaves per node of that level', () {
      // 5 leaves in 2 Berakhot perakim, 2 in Peah's, 2 in Shabbat's:
      // 9 leaves over 4 perakim.
      expect(rate(_pace(1, 'per_day', 'chapter')), closeTo(9 / 4, 1e-9));
      expect(rate(_pace(2, 'per_day', 'chapter')), closeTo(9 / 2, 1e-9));
      // 3 masechtos: 9 leaves over 3.
      expect(rate(_pace(1, 'per_day', 'masechta')), closeTo(3, 1e-9));
    });

    test('out-of-scope leaves drop out of the average', () {
      bool berakhotOnly(String ref) => ref.startsWith('Mishnah Berakhot');
      // Only the two Berakhot perakim count: 5 leaves over 2.
      expect(
        rate(_pace(1, 'per_day', 'chapter'), inScope: berakhotOnly),
        closeTo(2.5, 1e-9),
      );
    });

    test('a level with no in-scope node falls back to one leaf per unit', () {
      expect(rate(_pace(3, 'per_day', 'chapter'), inScope: (_) => false), 3);
    });
  });
}
