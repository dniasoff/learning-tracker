// Mirror test for `lib/domain/learner_state/review_schedule.dart`: the AD-32
// spaced-review schedule (`deriveReviewSchedule`, `ReviewSchedule.dueOn`,
// `dueForAttempt`, `ReviewStep`), driven directly with a stages history.
// September 2026: the 1st is a Tuesday, the 7th a Monday.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_config_history.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/review_schedule.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';

int _on(int day, {int hour = 10}) => (day - 1) * 1440 + hour * 60;

String _sep(int day) => '2026-09-${day.toString().padLeft(2, '0')}';

MainTrackConfigDoc _stage(
  int order, {
  String type = 'delay',
  int delay = 0,
  List<int>? days,
  int? window,
}) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.stages,
  docId: '${engineCurriculum}_$order',
  curriculumId: engineCurriculum,
  fields: {
    'stage_order': order,
    'schedule_type': type,
    'delay_days': delay,
    'days_of_week': ?days,
    'rolling_window_size': ?window,
  },
);

MainTrackConfigDoc _studyDay(int dow, String type) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.studyDays,
  docId: '${engineCurriculum}_$dow',
  curriculumId: engineCurriculum,
  fields: {'day_of_week': dow, 'day_type': type},
);

LearningEvent _learn(
  int id,
  String ref,
  int? stage,
  int day, {
  String source = LearningEvent.sourceMain,
  DateState dateState = DateState.dated,
  String? level,
}) => engineLearn(
  id,
  ref,
  stage: stage,
  minutes: _on(day),
  learnedOn: _sep(day),
  source: source,
  dateState: dateState,
  level: level,
);

final _threeStages = [_stage(1), _stage(2, delay: 1), _stage(3, delay: 7)];

ReviewSchedule _derive(
  List<LearningEvent> events, {
  List<MainTrackConfigDoc>? stages,
  List<MainTrackConfigDoc> days = const [],
  bool Function(LeafRef)? inScope,
  int? fallbackFirstStage,
}) => deriveReviewSchedule(
  countedLearns: events,
  corpus: mishnayosCorpus(),
  inScope: inScope ?? (_) => true,
  configHistory: MainTrackConfigHistory.build(
    curriculumId: engineCurriculum,
    intent: MainTrackIntent(
      curriculumId: engineCurriculum,
      track: MainTrack(
        curriculumId: engineCurriculum,
        state: MainTrackState.active,
      ),
      stages: stages ?? _threeStages,
      studyDays: days,
    ),
    intentHistory: const [],
  ),
  settingsHistory: c0SettingsHistory(),
  fallbackFirstStage: fallbackFirstStage,
);

ReviewDue _due(String leaf, int stage, String dueFrom, {String? done}) =>
    ReviewDue(leaf, stage, dueFrom: dueFrom, completedOn: done);

void main() {
  group('deriveReviewSchedule cycles', () {
    test('a first-stage learn opens the next stage, due delay days later', () {
      final schedule = _derive([_learn(1, _b11, 1, 1)]);
      expect(schedule.steps, hasLength(1));
      final step = schedule.steps.single;
      expect(step.leaf, _b11);
      expect(step.stageOrder, 2);
      expect(step.scheduleType, StageScheduleType.delay);
      expect(step.openedOn, _sep(1));
      expect(step.openedAt, engineAt(_on(1)));
      expect(step.openedBy, engineUlid(1));
      expect(step.dueFrom, _sep(2));
      expect(step.completedOn, isNull);
      expect(schedule.stepFor(_b11, 2), step);
      expect(schedule.stepFor(_b11, 3), isNull);
      expect(schedule.stepFor(_b12, 2), isNull);
    });

    test('completing a step opens the following one from that event', () {
      final schedule = _derive([_learn(1, _b11, 1, 1), _learn(2, _b11, 2, 3)]);
      expect(schedule.steps.map((s) => s.stageOrder), [2, 3]);
      expect(schedule.stepFor(_b11, 2)!.completedOn, _sep(3));
      final third = schedule.stepFor(_b11, 3)!;
      expect(third.openedOn, _sep(3));
      expect(third.openedBy, engineUlid(2));
      expect(third.dueFrom, _sep(10));
      expect(third.completedOn, isNull);
    });

    test('a stage done before it was due still completes its step', () {
      final schedule = _derive([
        _learn(1, _b11, 1, 1),
        // Same day: stage 2 is only due on the 2nd.
        _learn(2, _b11, 2, 1),
      ]);
      expect(schedule.stepFor(_b11, 2)!.completedOn, _sep(1));
    });

    test('the last stage ends the cycle', () {
      final schedule = _derive([
        _learn(1, _b11, 1, 1),
        _learn(2, _b11, 2, 2),
        _learn(3, _b11, 3, 9),
      ]);
      expect(schedule.steps.map((s) => s.stageOrder), [2, 3]);
      expect(schedule.stepFor(_b11, 3)!.completedOn, _sep(9));
    });

    test('only the earliest first-stage event starts the one cycle', () {
      final schedule = _derive([_learn(1, _b11, 1, 1), _learn(2, _b11, 1, 5)]);
      expect(schedule.steps, hasLength(1));
      expect(schedule.steps.single.openedBy, engineUlid(1));
    });

    test('catch_up events start cycles like dated ones', () {
      final schedule = _derive([
        _learn(1, _b11, 1, 1, dateState: DateState.catchUp),
      ]);
      expect(schedule.steps, hasLength(1));
    });

    test('events that cannot start a cycle are skipped', () {
      final schedule = _derive([
        // A sub-track learn.
        _learn(1, _b11, 1, 1, source: engineUlid(900)),
        // A free tick (no stage).
        _learn(2, _b12, null, 1),
        // Before tracking.
        _learn(3, _b13, 1, 1, dateState: DateState.beforeTracking),
        // A node (level) event.
        _learn(4, 'Mishnah Berakhot 2', 1, 1, level: 'chapter'),
        // Not the first stage in force.
        _learn(5, 'Mishnah Berakhot 2:1', 2, 1),
        // Not a corpus leaf.
        _learn(6, 'Mishnah Berakhot 1', 1, 1),
        _learn(7, 'Mishnah Nope 1:1', 1, 1),
      ]);
      expect(schedule.steps, isEmpty);
    });

    test('out-of-scope leaves have no cycle', () {
      final schedule = _derive([
        _learn(1, _b11, 1, 1),
        _learn(2, 'Mishnah Peah 1:1', 1, 1),
      ], inScope: (ref) => ref.startsWith('Mishnah Peah'));
      expect(schedule.steps.single.leaf, 'Mishnah Peah 1:1');
    });

    test('cycles are listed in order of their start event', () {
      final schedule = _derive([
        _learn(1, _b12, 1, 3),
        _learn(2, _b11, 1, 1),
        _learn(3, _b13, 1, 2),
      ]);
      expect(schedule.steps.map((s) => s.leaf), [_b11, _b13, _b12]);
    });

    test('a delay due on an inactive weekday moves to the next active one', () {
      // Review-only Mon, study Tue; Sat 5th + 1 day = Sun 6th -> Mon 7th.
      final schedule = _derive(
        [_learn(1, _b11, 1, 5)],
        days: [_studyDay(2, 'study'), _studyDay(1, 'review')],
      );
      expect(schedule.steps.single.dueFrom, _sep(7));
    });

    test(
      'with no stage in force the fallback starts a cycle with no steps',
      () {
        final schedule = _derive(
          [_learn(1, _b11, 1, 1)],
          stages: const [],
          fallbackFirstStage: 1,
        );
        expect(schedule.steps, isEmpty);
        expect(
          _derive([_learn(1, _b11, 1, 1)], stages: const []).steps,
          isEmpty,
        );
      },
    );
  });

  group('ReviewSchedule.dueOn', () {
    test('a delay review is due from dueFrom and stays due until done', () {
      final schedule = _derive([_learn(1, _b11, 1, 1)]);
      expect(schedule.dueOn(_sep(1)), isEmpty);
      expect(schedule.dueOn(_sep(2)), [_due(_b11, 2, _sep(2))]);
      expect(schedule.dueOn(_sep(20)), [_due(_b11, 2, _sep(2))]);
    });

    test('a step completed on the date is still due that day only', () {
      final schedule = _derive([_learn(1, _b11, 1, 1), _learn(2, _b11, 2, 4)]);
      expect(schedule.dueOn(_sep(3)), [_due(_b11, 2, _sep(2))]);
      expect(schedule.dueOn(_sep(4)), [_due(_b11, 2, _sep(2), done: _sep(4))]);
      expect(schedule.dueOn(_sep(5)), isEmpty);
      // Stage 3 opened on the 4th, due on the 11th.
      expect(schedule.dueOn(_sep(10)), isEmpty);
      expect(schedule.dueOn(_sep(11)), [_due(_b11, 3, _sep(11))]);
    });

    test('a weekly review is due on its weekdays while open', () {
      final schedule = _derive(
        [_learn(1, _b11, 1, 1)],
        stages: [
          _stage(1),
          _stage(2, type: 'weekly', days: [1, 5]),
        ],
      );
      // Mon 7th and Fri 4th; not Tue 8th; not before it opened.
      expect(schedule.dueOn(_sep(7)), [_due(_b11, 2, _sep(7))]);
      expect(schedule.dueOn(_sep(4)), [_due(_b11, 2, _sep(4))]);
      expect(schedule.dueOn(_sep(8)), isEmpty);
    });

    test('a rolling review is due for the most recently opened window', () {
      final events = [_learn(1, _b11, 1, 1), _learn(2, _b12, 1, 2)];
      final window1 = _derive(
        events,
        stages: [
          _stage(1),
          _stage(2, type: 'rolling', window: 1),
        ],
      );
      expect(window1.dueOn(_sep(3)), [_due(_b12, 2, _sep(3))]);
      final window2 = _derive(
        events,
        stages: [
          _stage(1),
          _stage(2, type: 'rolling', window: 2),
        ],
      );
      expect(window2.dueOn(_sep(3)).map((d) => d.leaf), [_b11, _b12]);
    });

    test('a rolling step falls back into the window once newer ones close', () {
      final schedule = _derive(
        [
          _learn(1, _b11, 1, 1),
          _learn(2, _b12, 1, 2),
          // b12's rolling review is done on the 4th.
          _learn(3, _b12, 2, 4),
        ],
        stages: [
          _stage(1),
          _stage(2, type: 'rolling', window: 1),
          _stage(3, delay: 30),
        ],
      );
      expect(schedule.dueOn(_sep(3)).map((d) => d.leaf), [_b12]);
      // On the 4th b12 is still open (done that day) and ranks first.
      expect(schedule.dueOn(_sep(4)).map((d) => d.leaf), [_b12]);
      // From the 5th it is closed and b11 is the only open one.
      expect(schedule.dueOn(_sep(5)).map((d) => d.leaf), [_b11]);
    });

    test('a rolling stage without a window size is never due', () {
      final schedule = _derive(
        [_learn(1, _b11, 1, 1)],
        stages: [
          _stage(1),
          _stage(2, type: 'rolling'),
        ],
      );
      expect(schedule.dueOn(_sep(3)), isEmpty);
      expect(schedule.dueForAttempt(schedule.steps.single, _sep(3)), isFalse);
    });
  });

  group('ReviewSchedule.dueForAttempt', () {
    test('a step is not due before it opened', () {
      final schedule = _derive([_learn(1, _b11, 3, 1)], stages: [_stage(3)]);
      expect(schedule.steps, isEmpty);
      final open = _derive([_learn(1, _b11, 1, 5)]);
      expect(open.dueForAttempt(open.steps.single, _sep(4)), isFalse);
    });

    test('a delay step judges by dueFrom, ignoring its completion marker', () {
      final schedule = _derive([
        _learn(1, _b11, 1, 1),
        // An early attempt (before the 2nd) completed the step.
        _learn(2, _b11, 2, 1),
      ]);
      final step = schedule.stepFor(_b11, 2)!;
      expect(schedule.dueForAttempt(step, _sep(1)), isFalse);
      expect(schedule.dueForAttempt(step, _sep(2)), isTrue);
      expect(schedule.dueForAttempt(step, _sep(30)), isTrue);
      // dueOn no longer lists it after completion, dueForAttempt still does.
      expect(schedule.dueOn(_sep(2)), isEmpty);
    });

    test('a weekly step judges by weekday', () {
      final schedule = _derive(
        [_learn(1, _b11, 1, 1)],
        stages: [
          _stage(1),
          _stage(2, type: 'weekly', days: [1]),
        ],
      );
      final step = schedule.steps.single;
      expect(schedule.dueForAttempt(step, _sep(7)), isTrue);
      expect(schedule.dueForAttempt(step, _sep(8)), isFalse);
    });

    test('a rolling step is judged against the other open steps', () {
      final schedule = _derive(
        [_learn(1, _b11, 1, 1), _learn(2, _b12, 1, 2)],
        stages: [
          _stage(1),
          _stage(2, type: 'rolling', window: 1),
        ],
      );
      expect(
        schedule.dueForAttempt(schedule.stepFor(_b12, 2)!, _sep(3)),
        isTrue,
      );
      expect(
        schedule.dueForAttempt(schedule.stepFor(_b11, 2)!, _sep(3)),
        isFalse,
      );
    });
  });

  group('ReviewStep', () {
    ReviewStep step({String? completedOn, Set<int> days = const {}}) =>
        ReviewStep(
          leaf: _b11,
          stageOrder: 2,
          scheduleType: StageScheduleType.weekly,
          openedOn: _sep(2),
          openedAt: engineAt(_on(2)),
          openedBy: engineUlid(1),
          dueFrom: _sep(2),
          daysOfWeek: days,
          completedOn: completedOn,
        );

    test('openOn spans opening to completion inclusive', () {
      final open = step();
      expect(open.openOn(_sep(1)), isFalse);
      expect(open.openOn(_sep(2)), isTrue);
      expect(open.openOn(_sep(30)), isTrue);
      final done = step(completedOn: _sep(4));
      expect(done.openOn(_sep(4)), isTrue);
      expect(done.openOn(_sep(5)), isFalse);
    });

    test('compares by value', () {
      expect(step(days: {1, 2}), step(days: {2, 1}));
      expect(step(days: {1}).hashCode, step(days: {1}).hashCode);
      expect(step(), isNot(step(completedOn: _sep(3))));
      expect(step(days: {1}), isNot(step(days: {2})));
      expect(step().toString(), contains(_b11));
    });

    test('ReviewSchedule compares its steps', () {
      expect(ReviewSchedule([step()]), ReviewSchedule([step()]));
      expect(
        ReviewSchedule([step()]).hashCode,
        ReviewSchedule([step()]).hashCode,
      );
      expect(ReviewSchedule([step()]), isNot(ReviewSchedule(const [])));
      expect(
        ReviewSchedule([step()]),
        isNot(ReviewSchedule([step(completedOn: _sep(3))])),
      );
      expect(
        () => ReviewSchedule([step()]).steps.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
