// DNI-467 AC-7: projection velocity from distinct newly learnt leaves by
// learned_on, with the 14-day minimum and the 28-day trailing window.
// DNI-494 AC-6: projected finish = today + ⌈remaining corpus ÷ velocity⌉,
// the FR-18 single-burst fixture, and the lock-start snapshot (NFR-9,
// FR-23).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

import '../../helpers/learner_state/bundled_corpus.dart';
import '../../helpers/learner_state/c0_fixtures.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

/// Today is Thursday 2026-10-08 (no lock: see the lock group for a run
/// inside one).
final _now = DateTime.utc(2026, 10, 8, 12);

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

/// [offset] days after 2026-09-30.
String _day(int offset) => shiftCivilDate('2026-09-30', offset);

CurriculumState _run(
  List<LearningEvent> events, {
  String? trackingStartDate,
  DeadlineGoal? deadline,
  PaceGoal? pace,
  List<ChangeLogEntry> history = const [],
  DateTime? nowUtc,
  Corpus? corpus,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    nowUtc: nowUtc ?? _now,
    corpora: corpus == null ? null : {engineCurriculum: corpus},
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
        _learn(1, 'Mishnah Berakhot 1:1', '2026-09-26'),
      ], trackingStartDate: '2026-09-26').projection!;
      expect(p.status, ProjectionStatus.tooEarly);
      expect(p.velocityPerDay, isNull);
      expect(p.projectedFinish, isNull);
    });

    test('no tracked history at all: no projection', () {
      expect(_run(const []).projection!.status, ProjectionStatus.tooEarly);
    });

    test('14 days: velocity over all of it', () {
      // [2026-09-25, 2026-10-08] = 14 days; 5 distinct new leaves.
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-09-25'),
        _learn(2, 'Mishnah Berakhot 1:2', '2026-09-26'),
        _learn(3, 'Mishnah Berakhot 1:3', '2026-09-29'),
        _learn(4, 'Mishnah Berakhot 2:1', '2026-10-03'),
        _learn(5, 'Mishnah Berakhot 2:2', '2026-10-08'),
      ], trackingStartDate: '2026-09-25').projection!;
      expect(p.status, ProjectionStatus.noDeadline);
      expect(p.velocityPerDay, 5 / 14);
      // 4 left at 5/14 a day: today + ceil(11.2) = 12 days.
      expect(p.projectedFinish, '2026-10-20');
    });

    test('27 days: still all history', () {
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-09-12'),
      ], trackingStartDate: '2026-09-12').projection!;
      expect(p.velocityPerDay, 1 / 27);
    });

    test('28+ days: the trailing 28 days only, both ends inclusive', () {
      // Window [2026-09-11, 2026-10-08].
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-08-30'),
        _learn(2, 'Mishnah Peah 1:1', '2026-09-10'),
        _learn(3, 'Mishnah Berakhot 1:2', '2026-09-11'),
        _learn(4, 'Mishnah Berakhot 1:3', '2026-10-08'),
      ], trackingStartDate: '2026-07-30').projection!;
      expect(p.velocityPerDay, 2 / 28);
    });

    test('without tracking_start_date, history starts at the earliest '
        'dated learn', () {
      final early = _run([_learn(1, 'Mishnah Berakhot 1:1', '2026-09-26')]);
      expect(early.projection!.status, ProjectionStatus.tooEarly);
      final enough = _run([_learn(1, 'Mishnah Berakhot 1:1', '2026-09-25')]);
      expect(enough.projection!.velocityPerDay, 1 / 14);
    });
  });

  group('what counts as newly learnt', () {
    const start = '2026-09-25';

    double velocity(List<LearningEvent> events) =>
        _run(events, trackingStartDate: start).projection!.velocityPerDay!;

    test('a leaf learnt on several days counts once, on its first day', () {
      expect(
        velocity([
          _learn(1, 'Mishnah Berakhot 1:1', '2026-09-28'),
          _learn(2, 'Mishnah Berakhot 1:1', '2026-09-30'),
          _learn(3, 'Mishnah Berakhot 1:1', '2026-09-30'),
        ]),
        1 / 14,
      );
    });

    test('a leaf first learnt before the window does not count when '
        'repeated inside it', () {
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-08-13'),
        _learn(2, 'Mishnah Berakhot 1:1', '2026-09-30'),
      ], trackingStartDate: '2026-07-30').projection!;
      expect(p.velocityPerDay, 0);
    });

    test('before-tracking leaves are excluded', () {
      expect(
        velocity([
          engineGround(1, berakhot1, minutes: _recordedMinutes),
          _learn(2, 'Mishnah Berakhot 1:1', '2026-09-30'),
          _learn(3, 'Mishnah Peah 1:1', '2026-09-30'),
        ]),
        1 / 14,
      );
    });

    test('chazara (a stage above the first) is excluded', () {
      expect(
        velocity([
          _learn(1, 'Mishnah Berakhot 1:1', '2026-09-30', stage: 2),
          _learn(2, 'Mishnah Peah 1:1', '2026-09-30'),
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
            '2026-09-30',
            dateState: DateState.catchUp,
          ),
          _learn(2, 'Mishnah Berakhot 1:2', '2026-09-30', stage: null),
          _learn(
            3,
            'Mishnah Berakhot 1:3',
            '2026-09-30',
            source: engineUlid(77),
          ),
        ]),
        3 / 14,
      );
    });

    test('a voided learn does not count', () {
      expect(
        velocity([
          _learn(1, 'Mishnah Berakhot 1:1', '2026-09-30'),
          _learn(2, 'Mishnah Peah 1:1', '2026-09-30'),
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
        _learn(i + 1, ref, _day(i - 1)),
    ];
    // 7 new leaves over 14 days = 0.5/day; 2 left → today + ⌈2 ÷ 0.5⌉ =
    // 2026-10-12.

    DeadlineGoal deadline(String target) =>
        DeadlineGoal(curriculumId: engineCurriculum, targetDate: target);

    test('on track when the finish is on or before target_date', () {
      final p = _run(
        events,
        trackingStartDate: '2026-09-25',
        deadline: deadline('2026-10-12'),
      ).projection!;
      expect(p.projectedFinish, '2026-10-12');
      expect(p.status, ProjectionStatus.onTrack);
    });

    test('behind pace when the finish is after target_date', () {
      final p = _run(
        events,
        trackingStartDate: '2026-09-25',
        deadline: deadline('2026-10-11'),
      ).projection!;
      expect(p.status, ProjectionStatus.behindPace);
    });

    test('zero velocity with leaves left is behind pace with no finish', () {
      final p = _run(
        const [],
        trackingStartDate: '2026-08-30',
        deadline: deadline('2026-12-29'),
      ).projection!;
      expect(p.velocityPerDay, 0);
      expect(p.projectedFinish, isNull);
      expect(p.status, ProjectionStatus.behindPace);
    });
  });

  test('there is no pace-reset input: goal and intent changes do not '
      'restart the window', () {
    final events = [
      _learn(1, 'Mishnah Berakhot 1:1', '2026-09-18'),
      _learn(2, 'Mishnah Berakhot 1:2', '2026-10-03'),
    ];
    final base = _run(events, trackingStartDate: '2026-07-30').projection!;
    final withChanges = _run(
      events,
      trackingStartDate: '2026-07-30',
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

  group('FR-18: one 60-leaf day after 27 quiet days', () {
    final corpus = bundledCorpus(engineCurriculum);
    List<LearningEvent> burst(String day) => [
      for (final (i, leaf) in corpus.leaves.take(60).indexed)
        _learn(i + 1, leaf, day),
    ];
    // Window [2026-09-11, 2026-10-08]: velocity 60 / 28; 4,132 left →
    // ⌈4132 × 28 ÷ 60⌉ = 1,929 days → 2032-01-19.
    const finish = '2032-01-19';

    DeadlineGoal deadline(String target) =>
        DeadlineGoal(curriculumId: engineCurriculum, targetDate: target);

    Projection project(List<LearningEvent> events, String target) => _run(
      events,
      corpus: corpus,
      trackingStartDate: '2026-08-01',
      deadline: deadline(target),
    ).projection!;

    test('before the burst there is no velocity: behind pace', () {
      expect(project(const [], finish).status, ProjectionStatus.behindPace);
    });

    test('flips to on track when the trailing-28-day projection reaches the '
        'deadline', () {
      final p = project(burst('2026-10-08'), finish);
      expect(p.velocityPerDay, 60 / 28);
      expect(p.projectedFinish, finish);
      expect(p.status, ProjectionStatus.onTrack);
    });

    test('does not flip when the projection still misses the deadline', () {
      expect(
        project(burst('2026-10-08'), '2032-01-18').status,
        ProjectionStatus.behindPace,
      );
    });

    test('a burst just outside the trailing window changes nothing', () {
      final p = project(burst('2026-09-10'), finish);
      expect(p.velocityPerDay, 0);
      expect(p.status, ProjectionStatus.behindPace);
    });
  });

  group('during a configured-location lock', () {
    // Leaf A on 2026-09-12 is inside the 28-day window that ends on Friday
    // 2026-10-09 (the lock's start day) but outside the one ending on
    // Saturday 2026-10-10.
    final events = [
      _learn(1, 'Mishnah Berakhot 1:1', '2026-09-12'),
      _learn(2, 'Mishnah Berakhot 1:2', '2026-10-08'),
    ];
    const goal = DeadlineGoal(
      curriculumId: engineCurriculum,
      targetDate: '2027-02-01',
    );

    Projection at(DateTime nowUtc) => _run(
      events,
      trackingStartDate: '2026-08-01',
      deadline: goal,
      nowUtc: nowUtc,
    ).projection!;

    test('keeps the lock-start projection fixed until the lock ends', () {
      final lock = lockWindows(
        c0SettingsHistory(),
        DateTime.utc(2026, 10, 9),
        DateTime.utc(2026, 10, 11),
      ).single;
      final atStart = at(lock.startUtc);
      expect(at(lock.startUtc.add(const Duration(microseconds: 1))), atStart);
      expect(at(lock.endUtc), atStart);
      expect(
        at(lock.endUtc.add(const Duration(microseconds: 1))),
        isNot(atStart),
      );
    });

    test('re-evaluates after the lock ends', () {
      final after = at(DateTime.utc(2026, 10, 11, 2));
      // Window [2026-09-14, 2026-10-11]: 1 leaf; 2026-10-11 + 196.
      expect(after.velocityPerDay, 1 / 28);
      expect(after.projectedFinish, '2027-04-24');
      expect(after.status, ProjectionStatus.behindPace);
    });
  });

  group('DNI-502: the deadline and today\'s new leaves', () {
    const goal = DeadlineGoal(
      curriculumId: engineCurriculum,
      targetDate: '2027-02-01',
    );

    test('carries the live deadline in every status', () {
      final tooEarly = _run(
        const [],
        trackingStartDate: '2026-10-01',
        deadline: goal,
      ).projection!;
      expect(tooEarly.status, ProjectionStatus.tooEarly);
      expect(tooEarly.deadline, '2027-02-01');
      final judged = _run(
        [_learn(1, 'Mishnah Berakhot 1:1', '2026-10-08')],
        trackingStartDate: '2026-09-01',
        deadline: goal,
      ).projection!;
      expect(judged.status, isNot(ProjectionStatus.tooEarly));
      expect(judged.deadline, '2027-02-01');
    });

    test('no deadline: none is carried', () {
      final p = _run(const [], trackingStartDate: '2026-09-01').projection!;
      expect(p.status, ProjectionStatus.noDeadline);
      expect(p.deadline, isNull);
    });

    test('counts distinct new leaves dated today, under 14 days too', () {
      final p = _run([
        _learn(1, 'Mishnah Berakhot 1:1', '2026-10-07'),
        _learn(2, 'Mishnah Berakhot 1:2', '2026-10-08'),
        _learn(3, 'Mishnah Berakhot 1:3', '2026-10-08'),
        // A repeat of an earlier leaf is not new today.
        _learn(4, 'Mishnah Berakhot 1:1', '2026-10-08'),
        // Chazara is never new learning.
        _learn(5, 'Mishnah Berakhot 2:1', '2026-10-08', stage: 2),
      ], trackingStartDate: '2026-10-07').projection!;
      expect(p.status, ProjectionStatus.tooEarly);
      expect(p.newlyLearntToday, 2);
    });
  });
}
