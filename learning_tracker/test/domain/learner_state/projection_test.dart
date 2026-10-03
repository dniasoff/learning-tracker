// DNI-467 AC-7: projection velocity from distinct newly learnt leaves by
// learned_on, with the 14-day minimum and the 28-day trailing window.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

/// Today is 2026-10-10.
final _now = DateTime.utc(2026, 10, 10, 12);

/// Every event is recorded at one ordinary weekday instant (Thursday
/// 2026-10-08 10:00Z, outside any lock); `learned_on` carries the day.
final _recordedMinutes = DateTime.utc(
  2026,
  10,
  8,
  10,
).difference(DateTime.utc(2026, 9)).inMinutes;

LearningEvent _learn(
  int id,
  String ref,
  String learnedOn, {
  int? stage = 1,
  DateState dateState = DateState.dated,
  String source = LearningEvent.sourceMain,
}) => engineLearn(
  id,
  ref,
  minutes: _recordedMinutes,
  learnedOn: learnedOn,
  stage: source == LearningEvent.sourceMain ? stage : null,
  dateState: dateState,
  source: source,
);

CurriculumState _run(
  List<LearningEvent> events, {
  String? trackingStartDate,
  DeadlineGoal? deadline,
  PaceGoal? pace,
  List<ChangeLogEntry> history = const [],
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    nowUtc: _now,
    intentHistory: history,
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        program: trackingStartDate == null
            ? null
            : MainTrackProgram(
                curriculumId: engineCurriculum,
                trackingStartDate: trackingStartDate,
              ),
        stages: [engineStage(1), engineStage(2)],
      ),
    },
    goals: {engineCurriculum: CurriculumGoals(deadline: deadline, pace: pace)},
  ),
)[engineCurriculum]!;

void main() {
  group('history boundaries', () {
    test('13 days of tracked history: no projection', () {
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-09-28'),
      ], trackingStartDate: '2026-09-28').projection!;
      expect(p.status, ProjectionStatus.tooEarly);
      expect(p.velocityPerDay, isNull);
      expect(p.projectedFinish, isNull);
    });

    test('no tracked history at all: no projection', () {
      expect(_run(const []).projection!.status, ProjectionStatus.tooEarly);
    });

    test('14 days: velocity over all of it', () {
      // [2026-09-27, 2026-10-10] = 14 days; 5 distinct new leaves.
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-09-27'),
        _learn(2, 'Mishnah Berakhot 1:2', '2026-09-28'),
        _learn(3, 'Mishnah Berakhot 1:3', '2026-10-01'),
        _learn(4, 'Mishnah Berakhot 2:1', '2026-10-05'),
        _learn(5, 'Mishnah Berakhot 2:2', '2026-10-10'),
      ], trackingStartDate: '2026-09-27').projection!;
      expect(p.status, ProjectionStatus.noDeadline);
      expect(p.velocityPerDay, 5 / 14);
      // 4 left at 5/14 a day: ceil(11.2) = 12 days, today counting first.
      expect(p.projectedFinish, '2026-10-21');
    });

    test('27 days: still all history', () {
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-09-14'),
      ], trackingStartDate: '2026-09-14').projection!;
      expect(p.velocityPerDay, 1 / 27);
    });

    test('28+ days: the trailing 28 days only, both ends inclusive', () {
      // Window [2026-09-13, 2026-10-10].
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-09-01'),
        _learn(2, 'Mishnah Peah 1:1', '2026-09-12'),
        _learn(3, 'Mishnah Berakhot 1:2', '2026-09-13'),
        _learn(4, 'Mishnah Berakhot 1:3', '2026-10-10'),
      ], trackingStartDate: '2026-08-01').projection!;
      expect(p.velocityPerDay, 2 / 28);
    });

    test('without tracking_start_date, history starts at the earliest '
        'dated learn', () {
      final early = _run([_learn(1, 'Mishnah Berakhot 1:1', '2026-09-28')]);
      expect(early.projection!.status, ProjectionStatus.tooEarly);
      final enough = _run([_learn(1, 'Mishnah Berakhot 1:1', '2026-09-27')]);
      expect(enough.projection!.velocityPerDay, 1 / 14);
    });
  });

  group('what counts as newly learnt', () {
    const start = '2026-09-27';

    double velocity(List<LearningEvent> events) =>
        _run(events, trackingStartDate: start).projection!.velocityPerDay!;

    test('a leaf learnt on several days counts once, on its first day', () {
      expect(
        velocity([
          _learn(1, 'Mishnah Berakhot 1:1', '2026-09-30'),
          _learn(2, 'Mishnah Berakhot 1:1', '2026-10-02'),
          _learn(3, 'Mishnah Berakhot 1:1', '2026-10-02'),
        ]),
        1 / 14,
      );
    });

    test('a leaf first learnt before the window does not count when '
        'repeated inside it', () {
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-08-15'),
        _learn(2, 'Mishnah Berakhot 1:1', '2026-10-02'),
      ], trackingStartDate: '2026-08-01').projection!;
      expect(p.velocityPerDay, 0);
    });

    test('before-tracking leaves are excluded', () {
      expect(
        velocity([
          engineGround(1, berakhot1, minutes: _recordedMinutes),
          _learn(2, 'Mishnah Berakhot 1:1', '2026-10-02'),
          _learn(3, 'Mishnah Peah 1:1', '2026-10-02'),
        ]),
        1 / 14,
      );
    });

    test('chazara (a stage above the first) is excluded', () {
      expect(
        velocity([
          _learn(1, 'Mishnah Berakhot 1:1', '2026-10-02', stage: 2),
          _learn(2, 'Mishnah Peah 1:1', '2026-10-02'),
        ]),
        1 / 14,
      );
    });

    test('catch_up, free-tick and sub-track learns count', () {
      expect(
        velocity([
          _learn(
            1,
            'Mishnah Berakhot 1:1',
            '2026-10-02',
            dateState: DateState.catchUp,
          ),
          _learn(2, 'Mishnah Berakhot 1:2', '2026-10-02', stage: null),
          _learn(
            3,
            'Mishnah Berakhot 1:3',
            '2026-10-02',
            source: engineUlid(77),
          ),
        ]),
        3 / 14,
      );
    });

    test('a voided learn does not count', () {
      expect(
        velocity([
          _learn(1, 'Mishnah Berakhot 1:1', '2026-10-02'),
          _learn(2, 'Mishnah Peah 1:1', '2026-10-02'),
          engineVoid(3, 2, minutes: _recordedMinutes + 1),
        ]),
        1 / 14,
      );
    });
  });

  group('status against the deadline', () {
    final events = [
      for (final (i, ref) in [
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 1:3',
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
        'Mishnah Peah 1:1',
        'Mishnah Peah 1:2',
      ].indexed)
        _learn(i + 1, ref, '2026-10-0${i + 1}'),
    ];
    // 7 new leaves over 14 days = 0.5/day; 2 left → finish 2026-10-13.

    DeadlineGoal deadline(String target) =>
        DeadlineGoal(curriculumId: engineCurriculum, targetDate: target);

    test('on track when the finish is on or before target_date', () {
      final p = _run(
        events,
        trackingStartDate: '2026-09-27',
        deadline: deadline('2026-10-13'),
      ).projection!;
      expect(p.projectedFinish, '2026-10-13');
      expect(p.status, ProjectionStatus.onTrack);
    });

    test('behind pace when the finish is after target_date', () {
      final p = _run(
        events,
        trackingStartDate: '2026-09-27',
        deadline: deadline('2026-10-12'),
      ).projection!;
      expect(p.status, ProjectionStatus.behindPace);
    });

    test('zero velocity with leaves left is behind pace with no finish', () {
      final p = _run(
        const [],
        trackingStartDate: '2026-09-01',
        deadline: deadline('2026-12-31'),
      ).projection!;
      expect(p.velocityPerDay, 0);
      expect(p.projectedFinish, isNull);
      expect(p.status, ProjectionStatus.behindPace);
    });
  });

  test('there is no pace-reset input: goal and intent changes do not '
      'restart the window', () {
    final events = [
      _learn(1, 'Mishnah Berakhot 1:1', '2026-09-20'),
      _learn(2, 'Mishnah Berakhot 1:2', '2026-10-05'),
    ];
    final base = _run(events, trackingStartDate: '2026-08-01').projection!;
    final withChanges = _run(
      events,
      trackingStartDate: '2026-08-01',
      pace: const PaceGoal(
        curriculumId: engineCurriculum,
        paceValue: 9,
        paceUnit: 'per_day',
        paceGranularity: 'mishnah',
      ),
      history: [
        ChangeLogEntry(
          id: engineUlid(90),
          entity: GovernedEntity.goal,
          entityId: '${engineCurriculum}_pace',
          actionId: engineUlid(90),
          before: {'goals/${engineCurriculum}_pace.pace_value': 1},
          after: {'goals/${engineCurriculum}_pace.pace_value': 9},
          at: DateTime.utc(2026, 10, 1),
          actor: parentActor,
        ),
      ],
    ).projection!;
    expect(withChanges, base);
  });
}
