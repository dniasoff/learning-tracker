// DNI-467 AC-6: no-sub-track deadline target and pace rate from the fixed
// goal docs (AD-43, AD-44).
// DNI-494 AC-5: with no deadline, no capacity, shortfall or daily target is
// computed and no sub-track rate affects any value (FR-20).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

// Today (`engineAt(10000)`) is Monday 2026-09-07. The fixture corpus has
// 9 leaves; 4 chapters (3 + 2 + 2 + 2 leaves).

DeadlineGoal _deadline(String target, {DateTime? endedAt}) => DeadlineGoal(
  curriculumId: engineCurriculum,
  targetDate: target,
  endedAt: endedAt,
);

PaceGoal _pace(
  num value, {
  String unit = 'per_day',
  String granularity = 'mishnah',
  DateTime? endedAt,
}) => PaceGoal(
  curriculumId: engineCurriculum,
  paceValue: value,
  paceUnit: unit,
  paceGranularity: granularity,
  endedAt: endedAt,
);

MainTrackConfigDoc _day(int dow, String type) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.studyDays,
  docId: '${engineCurriculum}_$dow',
  curriculumId: engineCurriculum,
  fields: {'day_of_week': dow, 'day_type': type},
);

/// Monday–Thursday study, Friday–Sunday review.
final _monToThu = [
  for (final dow in [1, 2, 3, 4]) _day(dow, 'study'),
  for (final dow in [5, 6, 7]) _day(dow, 'review'),
];

/// An ongoing sub-track over Peah (2 leaves) at [rate] a week.
SubTrack _subTrack(double rate) => SubTrack(
  id: engineUlid(800),
  curriculumId: engineCurriculum,
  name: 'Shiur',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: rate,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [peah],
  lastChangeId: engineUlid(801),
);

CurriculumState _run({
  DeadlineGoal? deadline,
  PaceGoal? pace,
  List<MainTrackConfigDoc> studyDays = const [],
  List<LearningEvent> events = const [],
  MainTrackProgram? program,
  List<SubTrack> subTracks = const [],
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    subTracks: subTracks,
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        studyDays: studyDays,
        program: program,
      ),
    },
    goals: {engineCurriculum: CurriculumGoals(deadline: deadline, pace: pace)},
  ),
)[engineCurriculum]!;

void main() {
  group('deadline goal, no sub-tracks', () {
    test('numerator is mainTrackRemaining over inclusive study days', () {
      // [Mon 7th, Wed 9th] = 3 study days; ceil(9 / 3) = 3.
      final state = _run(deadline: _deadline('2026-09-09'));
      expect(state.mainTrackRemaining, 9);
      expect(state.dailyTarget, 3);
    });

    test('the numerator is taken at the start of today: leaves learnt today '
        'do not shrink today\'s target (DNI-477)', () {
      LearningEvent learn(int id, String ref, String learnedOn) => engineLearn(
        id,
        ref,
        minutes: 9000 + id,
        stage: 1,
        learnedOn: learnedOn,
      );
      // Three learnt today: 6 remain now, 9 at the start of today;
      // ceil(9 / 3) = 3, not ceil(6 / 3) = 2.
      final today = _run(
        deadline: _deadline('2026-09-09'),
        events: [
          learn(1, 'Mishnah Berakhot 1:1', '2026-09-07'),
          learn(2, 'Mishnah Berakhot 1:2', '2026-09-07'),
          learn(3, 'Mishnah Berakhot 1:3', '2026-09-07'),
        ],
      );
      expect(today.mainTrackRemaining, 6);
      expect(today.dailyTarget, 3);
      // The same three learnt yesterday: ceil(6 / 3) = 2.
      final yesterday = _run(
        deadline: _deadline('2026-09-09'),
        events: [
          learn(1, 'Mishnah Berakhot 1:1', '2026-09-06'),
          learn(2, 'Mishnah Berakhot 1:2', '2026-09-06'),
          learn(3, 'Mishnah Berakhot 1:3', '2026-09-06'),
        ],
      );
      expect(yesterday.dailyTarget, 2);
    });

    test('the ceiling rounds up', () {
      // [Mon 7th, Thu 10th] = 4 days; ceil(9 / 4) = 3.
      expect(_run(deadline: _deadline('2026-09-10')).dailyTarget, 3);
      // 6 days; ceil(9 / 6) = 2.
      expect(_run(deadline: _deadline('2026-09-12')).dailyTarget, 2);
    });

    test('only study days in study_day_configs count', () {
      // [Mon 7th, Sun 13th]: Mon–Thu are study days; ceil(9 / 4) = 3.
      final state = _run(
        deadline: _deadline('2026-09-13'),
        studyDays: _monToThu,
      );
      expect(state.dailyTarget, 3);
      // [Mon 7th, Sun 20th]: 8 study days; ceil(9 / 8) = 2.
      expect(
        _run(
          deadline: _deadline('2026-09-20'),
          studyDays: _monToThu,
        ).dailyTarget,
        2,
      );
    });

    test('a deadline today on a study day divides by one', () {
      expect(_run(deadline: _deadline('2026-09-07')).dailyTarget, 9);
    });

    test('no study day left gives the numerator', () {
      // Monday is a review day and the deadline is today.
      final reviewMonday = [
        _day(1, 'review'),
        for (final dow in [2, 3, 4, 5, 6, 7]) _day(dow, 'study'),
      ];
      expect(
        _run(
          deadline: _deadline('2026-09-07'),
          studyDays: reviewMonday,
        ).dailyTarget,
        9,
      );
      // A deadline already past: no date in [today, target_date].
      expect(_run(deadline: _deadline('2026-09-01')).dailyTarget, 9);
    });

    test('everything learnt gives a target of 0', () {
      final state = _run(
        deadline: _deadline('2026-09-09'),
        events: [
          for (final (i, node) in [zeraim, moed].indexed)
            engineGround(i + 1, node),
        ],
      );
      expect(state.mainTrackRemaining, 0);
      expect(state.dailyTarget, 0);
    });

    test('an ended deadline doc is ignored', () {
      final state = _run(
        deadline: _deadline('2026-09-09', endedAt: engineAt(1)),
      );
      expect(state.dailyTarget, isNull);
    });
  });

  group('pace goal', () {
    test('with no deadline, paceRate comes from the pace doc', () {
      final state = _run(pace: _pace(2));
      expect(state.paceRate, 2.0);
      expect(state.dailyTarget, isNull);
    });

    test('a coarse granularity converts at average leaves per node', () {
      // 4 chapters, 9 leaves: 1 chapter ≈ 2.25 leaves.
      expect(_run(pace: _pace(1, granularity: 'chapter')).paceRate, 2.25);
    });

    test('a weekly pace spreads over the week\'s study days', () {
      expect(_run(pace: _pace(7, unit: 'per_week')).paceRate, 1.0);
      expect(
        _run(
          pace: _pace(8, unit: 'per_week'),
          studyDays: _monToThu,
        ).paceRate,
        2.0,
      );
    });

    test('an ended pace doc is ignored', () {
      expect(_run(pace: _pace(2, endedAt: engineAt(1))).paceRate, isNull);
    });

    test('with a deadline too, both are derived', () {
      final state = _run(deadline: _deadline('2026-09-09'), pace: _pace(1));
      expect(state.dailyTarget, 3);
      expect(state.paceRate, 1.0);
    });
  });

  test('with neither goal both are null', () {
    final state = _run();
    expect(state.dailyTarget, isNull);
    expect(state.paceRate, isNull);
  });

  test('a calendar-program curriculum ignores goals (AD-43/AD-45)', () {
    final state = _run(
      deadline: _deadline('2026-09-09'),
      pace: _pace(5),
      program: MainTrackProgram(
        curriculumId: engineCurriculum,
        programId: 'p',
        trackingStartDate: '2026-09-01',
      ),
    );
    expect(state.dailyTarget, 0);
    expect(state.paceRate, isNull);
  });

  group('DNI-494 AC-5: no deadline goal', () {
    test('capacity, shortfall and daily target are not computed', () {
      final state = _run(subTracks: [_subTrack(2)]);
      final sub = state.subTracks[engineUlid(800)]!;
      expect(sub.holdsGround, isTrue);
      expect(sub.capacity, isNull);
      expect(sub.expectedNewGround, 0);
      expect(sub.shortfall, 0);
      expect(sub.shortfallLeaves, isEmpty);
      expect(state.shortfall, isNull);
      expect(state.dailyTarget, isNull);
      expect(state.paceRate, isNull);
      // The held ground still leaves the main track.
      expect(state.mainTrackRemaining, 7);
    });

    test('a pace goal provides paceRate', () {
      final state = _run(pace: _pace(3), subTracks: [_subTrack(2)]);
      expect(state.paceRate, 3.0);
      expect(state.dailyTarget, isNull);
    });

    test('no sub-track rate affects any value', () {
      for (final pace in [null, _pace(3)]) {
        final slow = _run(pace: pace, subTracks: [_subTrack(2)]);
        final fast = _run(pace: pace, subTracks: [_subTrack(200)]);
        expect(fast.subTracks, slow.subTracks);
        expect(fast.dailyTarget, slow.dailyTarget);
        expect(fast.paceRate, slow.paceRate);
        expect(fast.shortfall, slow.shortfall);
        expect(fast.projection, slow.projection);
        expect(fast.schedulableRefs, slow.schedulableRefs);
      }
    });

    test('with a deadline the same rate change does move the target', () {
      // [Mon 7th, Sun 13th] = 7 days. Rate 2: floor(2 × 52 × 7 ÷ 365) = 1
      // of 2 ground leaves → 1 shortfall: ceil((7 + 1) ÷ 7) = 2. Rate 200:
      // capacity 199, expected 197 → numerator −190 → 0.
      final deadline = _deadline('2026-09-13');
      expect(
        _run(deadline: deadline, subTracks: [_subTrack(2)]).dailyTarget,
        2,
      );
      expect(
        _run(deadline: deadline, subTracks: [_subTrack(200)]).dailyTarget,
        0,
      );
    });
  });

  group('StudyDays.countStudyDays', () {
    test('counts inclusive dates on study weekdays across many weeks', () {
      final days = StudyDays.fromDocs(_monToThu);
      // 2026-09-07 (Mon) .. 2026-12-06 (Sun): 13 full weeks.
      expect(days.countStudyDays('2026-09-07', '2026-12-06'), 52);
      expect(days.countStudyDays('2026-09-11', '2026-09-13'), 0);
      expect(days.countStudyDays('2026-09-10', '2026-09-07'), 0);
    });

    test('no readable doc means every day is a study day', () {
      final days = StudyDays.fromDocs(const []);
      expect(days.countStudyDays('2026-09-07', '2026-09-13'), 7);
    });

    test('an ended doc is not read', () {
      final ended = MainTrackConfigDoc(
        collection: MainTrackConfigDoc.studyDays,
        docId: '${engineCurriculum}_1',
        curriculumId: engineCurriculum,
        fields: const {'day_of_week': 1, 'day_type': 'study'},
        endedAt: engineAt(1),
      );
      final days = StudyDays.fromDocs([ended, _day(2, 'study')]);
      expect(days.studyWeekdays, {2});
    });
  });
}
