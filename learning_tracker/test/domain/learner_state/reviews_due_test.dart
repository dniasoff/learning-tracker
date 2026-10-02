// DNI-467 AC-5: AD-32 review cycles; each step under the stages and study
// days in force at the event that completed the previous step.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

// September 2026: the 1st is a Tuesday, the 4th a Friday, the 5th a
// Saturday, the 7th a Monday.

const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';

/// Minutes after 2026-09-01T00:00Z of September [day] at [hour]:00.
int _on(int day, {int hour = 10}) => (day - 1) * 1440 + hour * 60;

String _sep(int day) => '2026-09-${day.toString().padLeft(2, '0')}';

MainTrackConfigDoc _stage(
  int order, {
  String type = 'delay',
  int delay = 0,
  List<int>? daysOfWeek,
  int? window,
}) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.stages,
  docId: '${engineCurriculum}_$order',
  curriculumId: engineCurriculum,
  fields: {
    'stage_order': order,
    'schedule_type': type,
    'delay_days': delay,
    'days_of_week': ?daysOfWeek,
    'rolling_window_size': ?window,
  },
);

MainTrackConfigDoc _day(int dow, String type) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.studyDays,
  docId: '${engineCurriculum}_$dow',
  curriculumId: engineCurriculum,
  fields: {'day_of_week': dow, 'day_type': type},
);

final _threeStages = [_stage(1), _stage(2, delay: 1), _stage(3, delay: 7)];

/// A main event on [ref] at [stage], learnt on September [day].
LearningEvent _main(
  int id,
  String ref,
  int stage,
  int day, {
  DateState dateState = DateState.dated,
}) => engineLearn(
  id,
  ref,
  stage: stage,
  minutes: _on(day),
  learnedOn: _sep(day),
  dateState: dateState,
);

ChangeLogEntry _change(
  int id,
  GovernedEntity entity,
  Map<String, Object?> before,
  Map<String, Object?> after, {
  required int minutes,
}) => ChangeLogEntry(
  id: engineUlid(id),
  entity: entity,
  entityId: engineCurriculum,
  actionId: engineUlid(id),
  before: before,
  after: after,
  at: engineAt(minutes),
  actor: parentActor,
);

CurriculumState _run(
  List<LearningEvent> events, {
  List<MainTrackConfigDoc>? stages,
  List<MainTrackConfigDoc> studyDays = const [],
  List<ChangeLogEntry> history = const [],
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        stages: stages ?? _threeStages,
        studyDays: studyDays,
      ),
    },
    intentHistory: history,
    nowUtc: engineAt(_on(20)),
  ),
)[engineCurriculum]!;

void main() {
  group('a cycle from a main first-stage learn', () {
    final state = _run([_main(1, _b11, 1, 1), _main(2, _b11, 2, 3)]);

    test('stage 2 is due delay_days after the learn and stays due while '
        'overdue, through the day it is done', () {
      expect(state.reviewsDue(_sep(1)), isEmpty);
      expect(state.reviewsDue(_sep(2)), [const ReviewDue(_b11, 2)]);
      expect(state.reviewsDue(_sep(3)), [const ReviewDue(_b11, 2)]);
    });

    test('the next step is scheduled from the completing event', () {
      expect(state.reviewsDue(_sep(4)), isEmpty);
      expect(state.reviewsDue(_sep(9)), isEmpty);
      expect(state.reviewsDue(_sep(10)), [const ReviewDue(_b11, 3)]);
      expect(state.reviewsDue(_sep(30)), [const ReviewDue(_b11, 3)]);
    });

    test('after the last stage nothing more is due', () {
      final done = _run([
        _main(1, _b11, 1, 1),
        _main(2, _b11, 2, 2),
        _main(3, _b11, 3, 9),
      ]);
      expect(done.reviewsDue(_sep(9)), [const ReviewDue(_b11, 3)]);
      expect(done.reviewsDue(_sep(10)), isEmpty);
    });

    test('a catch_up first-stage learn starts a cycle too', () {
      final s = _run([_main(1, _b11, 1, 1, dateState: DateState.catchUp)]);
      expect(s.reviewsDue(_sep(2)), [const ReviewDue(_b11, 2)]);
    });
  });

  group('no cycle without a qualifying start', () {
    test('sub-track, free tick and before-tracking learns have no cycle', () {
      final state = _run([
        engineLearn(
          1,
          _b11,
          source: engineUlid(70),
          minutes: _on(1),
          learnedOn: _sep(1),
        ),
        engineLearn(2, _b12, minutes: _on(1), learnedOn: _sep(1)),
        engineGround(3, berakhot1, minutes: _on(1)),
      ]);
      expect(state.learntLeaves, containsAll([_b11, _b12, _b13]));
      for (var d = 1; d <= 20; d++) {
        expect(state.reviewsDue(_sep(d)), isEmpty, reason: _sep(d));
      }
    });

    test('a later-stage main event alone starts nothing', () {
      expect(_run([_main(1, _b11, 2, 1)]).reviewsDue(_sep(5)), isEmpty);
    });

    test('a voided first-stage learn starts nothing', () {
      final state = _run([_main(1, _b11, 1, 1), engineVoid(2, 1)]);
      expect(state.reviewsDue(_sep(5)), isEmpty);
    });

    test('a skipped stage does not complete the step', () {
      final state = _run([_main(1, _b11, 1, 1), _main(2, _b11, 3, 2)]);
      expect(state.reviewsDue(_sep(5)), [const ReviewDue(_b11, 2)]);
    });

    test('a second first-stage learn does not restart the cycle', () {
      final state = _run([_main(1, _b11, 1, 1), _main(2, _b11, 1, 5)]);
      expect(state.reviewsDue(_sep(2)), [const ReviewDue(_b11, 2)]);
    });
  });

  group('intent in force at the previous step', () {
    test('a stage change after the learn does not move the open step', () {
      // Stage 2 is now delay 5, but was delay 1 when the learn happened.
      final state = _run(
        [_main(1, _b11, 1, 1)],
        stages: [_stage(1), _stage(2, delay: 5), _stage(3, delay: 7)],
        history: [
          _change(
            40,
            GovernedEntity.mainTrackStages,
            {'stage_definitions/${engineCurriculum}_2.delay_days': 1},
            {'stage_definitions/${engineCurriculum}_2.delay_days': 5},
            minutes: _on(2, hour: 12),
          ),
        ],
      );
      expect(state.reviewsDue(_sep(2)), [const ReviewDue(_b11, 2)]);
    });

    test('a step completed after the change uses the new stages', () {
      // Stage 3 went from delay 7 to delay 2 between the two events.
      final state = _run(
        [_main(1, _b11, 1, 1), _main(2, _b11, 2, 3)],
        stages: [_stage(1), _stage(2, delay: 1), _stage(3, delay: 2)],
        history: [
          _change(
            40,
            GovernedEntity.mainTrackStages,
            {'stage_definitions/${engineCurriculum}_3.delay_days': 7},
            {'stage_definitions/${engineCurriculum}_3.delay_days': 2},
            minutes: _on(2),
          ),
        ],
      );
      expect(state.reviewsDue(_sep(4)), isEmpty);
      expect(state.reviewsDue(_sep(5)), [const ReviewDue(_b11, 3)]);
    });

    test('a stage added later does not extend a cycle step already '
        'scheduled before it existed', () {
      // Stage 2 was created on the 5th; the learn on the 1st had only
      // stage 1 in force, so it opened no step.
      final state = _run(
        [_main(1, _b11, 1, 1)],
        stages: [_stage(1), _stage(2, delay: 1)],
        history: [
          _change(
            40,
            GovernedEntity.mainTrackStages,
            {
              'stage_definitions/${engineCurriculum}_2.stage_order': null,
              'stage_definitions/${engineCurriculum}_2.schedule_type': null,
              'stage_definitions/${engineCurriculum}_2.delay_days': null,
            },
            {
              'stage_definitions/${engineCurriculum}_2.stage_order': 2,
              'stage_definitions/${engineCurriculum}_2.schedule_type': 'delay',
              'stage_definitions/${engineCurriculum}_2.delay_days': 1,
            },
            minutes: _on(5),
          ),
        ],
      );
      expect(state.reviewsDue(_sep(10)), isEmpty);
      // A learn after the change does start a two-stage cycle.
      final later = _run(
        [_main(1, _b11, 1, 6)],
        stages: [_stage(1), _stage(2, delay: 1)],
      );
      expect(later.reviewsDue(_sep(7)), [const ReviewDue(_b11, 2)]);
    });

    test('study days in force move a due date off an inactive weekday', () {
      // At the learn (Thu 3rd) Saturday had no study-day doc: a delay-2
      // review lands on Sunday. Saturday became a review day later, which
      // does not move this step.
      final week = [
        for (final dow in [1, 2, 3, 4, 7]) _day(dow, 'study'),
        _day(5, 'review'),
      ];
      final state = _run(
        [_main(1, _b11, 1, 3)],
        stages: [_stage(1), _stage(2, delay: 2)],
        studyDays: [...week, _day(6, 'review')],
        history: [
          _change(
            40,
            GovernedEntity.mainTrackStudyDays,
            {
              'study_day_configs/${engineCurriculum}_6.day_of_week': null,
              'study_day_configs/${engineCurriculum}_6.day_type': null,
            },
            {
              'study_day_configs/${engineCurriculum}_6.day_of_week': 6,
              'study_day_configs/${engineCurriculum}_6.day_type': 'review',
            },
            minutes: _on(4),
          ),
        ],
      );
      expect(state.reviewsDue(_sep(5)), isEmpty);
      expect(state.reviewsDue(_sep(6)), [const ReviewDue(_b11, 2)]);

      // A learn after the change sees Saturday as a review day.
      final after = _run(
        [_main(1, _b11, 1, 10)],
        stages: [_stage(1), _stage(2, delay: 2)],
        studyDays: [...week, _day(6, 'review')],
      );
      expect(after.reviewsDue(_sep(12)), [const ReviewDue(_b11, 2)]);
    });
  });

  group('schedule types', () {
    test('weekly: due on its weekdays once the previous stage is done', () {
      final state = _run(
        [_main(1, _b11, 1, 1)],
        stages: [
          _stage(1),
          _stage(2, type: 'weekly', daysOfWeek: [1]),
        ],
      );
      expect(state.reviewsDue(_sep(2)), isEmpty);
      expect(state.reviewsDue(_sep(7)), [const ReviewDue(_b11, 2)]);
      expect(state.reviewsDue(_sep(8)), isEmpty);
      expect(state.reviewsDue(_sep(14)), [const ReviewDue(_b11, 2)]);
    });

    test('rolling: the most recent N open leaves', () {
      final state = _run(
        [_main(1, _b11, 1, 1), _main(2, _b12, 1, 2), _main(3, _b13, 1, 3)],
        stages: [
          _stage(1),
          _stage(2, type: 'rolling', window: 2),
        ],
      );
      expect(state.reviewsDue(_sep(1)), [const ReviewDue(_b11, 2)]);
      expect(state.reviewsDue(_sep(3)), [
        const ReviewDue(_b12, 2),
        const ReviewDue(_b13, 2),
      ]);
    });
  });

  test('reviews are ordered by cycle start', () {
    final state = _run([_main(2, _b12, 1, 1), _main(1, _b11, 1, 2)]);
    expect(state.reviewsDue(_sep(5)), [
      const ReviewDue(_b12, 2),
      const ReviewDue(_b11, 2),
    ]);
  });
}
