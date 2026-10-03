// DNI-506 (Story 3.3) T3: what the pure engine derives from the events a
// catch-up card writes (AC-2, AC-4, AC-5, AC-6, AC-7, AC-10).
//
// The learner is the no-location New York fallback of the DNI-505 harness:
// Shabbos 2026-10-10 locks Fri 12:00 to Sun 01:00 learner-local and its
// catch-up window runs to the end of Monday 2026-10-12. Main-track days
// are learnt Thu 10-08, Fri 10-09 (before the lock), Sun 10-11, Mon 10-12
// and Tue 10-13, each at 10:00 learner-local.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/tri_state.dart';

import '../../helpers/learner_state/catch_up_card_harness.dart';
import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

/// [hour]:[minute] learner-local on 2026-10-[day].
DateTime _at(int day, {int hour = 10, int minute = 0}) =>
    catchUpZone.at(DateTime.utc(2026, 10, day), hour: hour, minute: minute);

String _date(int day) => '2026-10-${day.toString().padLeft(2, '0')}';

var _next = 0;

const _child = Actor(uid: 'owner-uid', role: ActorRole.child, displayName: '');

LearningEvent _learn(
  String ref, {
  required int learnedOn,
  required DateTime at,
  DateState dateState = DateState.dated,
  String source = LearningEvent.sourceMain,
  Actor actor = parentActor,
  String? id,
}) => LearningEvent.learn(
  id: id ?? engineUlid(++_next),
  curriculumId: engineCurriculum,
  ref: ref,
  source: source,
  dateState: dateState,
  learnedOn: _date(learnedOn),
  stage: source == LearningEvent.sourceMain ? 1 : null,
  recordedAt: at,
  actor: actor,
);

/// The Shabbos catch-up of [ref], tapped at [at] (Sunday noon by default).
LearningEvent _catchUp(
  String ref, {
  DateTime? at,
  String source = LearningEvent.sourceMain,
  Actor actor = parentActor,
  String? id,
}) => _learn(
  ref,
  learnedOn: 10,
  at: at ?? catchUpSunday,
  dateState: DateState.catchUp,
  source: source,
  actor: actor,
  id: id,
);

/// A dated main-track day on [day] (recorded that morning).
LearningEvent _day(int day, [String ref = 'Mishnah Berakhot 1:1']) =>
    _learn(ref, learnedOn: day, at: _at(day));

LearningEvent _voidOf(LearningEvent target, DateTime at) =>
    LearningEvent.voidOf(
      id: engineUlid(++_next),
      targetId: target.id,
      recordedAt: at,
      actor: parentActor,
    );

/// The Rebbe sub-track over Peah, learning on Shabbos.
final _rebbe = SubTrack(
  id: ulidB,
  curriculumId: engineCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 7,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: const [peah],
  lastChangeId: ulidC,
);

LearnerState _run(
  List<LearningEvent> events, {
  required DateTime now,
  String? trackingStartDate,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    subTracks: [_rebbe],
    settingsHistory: catchUpHistory,
    nowUtc: now,
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
  ),
);

CurriculumState _mishnayos(LearnerState s) => s[engineCurriculum]!;

void main() {
  final week = [_day(8), _day(9), _day(11), _day(12), _day(13)];

  group('AC-2: a counted main catch_up keeps the streak across the lock', () {
    test('the locked day is a streak day, so the run is unbroken', () {
      final state = _run([
        ...week,
        _catchUp('Mishnah Berakhot 2:1'),
      ], now: _at(13, hour: 12));
      expect(
        _mishnayos(state).streak,
        const CurriculumStreak(current: 6, best: 6, lastDay: '2026-10-13'),
      );
    });

    test('without it, the run breaks at the locked day once the card ends', () {
      final state = _run(week, now: _at(13, hour: 12));
      expect(_mishnayos(state).streak!.current, 3);
      expect(_mishnayos(state).streak!.best, 3);
    });

    test('while the card is pending the locked day does not break it', () {
      final state = _run(week.take(3).toList(), now: _at(11, hour: 12));
      // Thu, Fri, (Sat pending), Sun.
      expect(_mishnayos(state).streak!.current, 3);
    });

    test('a catch_up recorded at 23:59 on the last day counts', () {
      final state = _run([
        ...week,
        _catchUp('Mishnah Berakhot 2:1', at: _at(12, hour: 23, minute: 59)),
      ], now: _at(13, hour: 12));
      expect(_mishnayos(state).streak!.current, 6);
    });

    test('a catch_up stamped after the window never fills the gap', () {
      final state = _run([
        ...week,
        _catchUp('Mishnah Berakhot 2:1', at: _at(13, minute: 1)),
      ], now: _at(13, hour: 12));
      expect(_mishnayos(state).streak!.current, 3);
      // ... though it still counts as learnt (it is a counted event).
      expect(_mishnayos(state).learntLeaves, contains('Mishnah Berakhot 2:1'));
    });
  });

  group('AC-2: sub-track catch_up counts for progress, never the streak', () {
    final peah11 = _catchUp('Mishnah Peah 1:1', source: ulidB);
    final peah12 = _catchUp('Mishnah Peah 1:2', source: ulidB);

    test('it never keeps the streak (FR-16)', () {
      final state = _run([...week, peah11, peah12], now: _at(13, hour: 12));
      expect(_mishnayos(state).streak!.current, 3);
    });

    test('it adds to the learnt count, fill, siyum and position', () {
      final before = _run(week, now: _at(13, hour: 12));
      final after = _run([...week, peah11, peah12], now: _at(13, hour: 12));
      final c = _mishnayos(after);
      expect(
        c.learntLeaves,
        containsAll(['Mishnah Peah 1:1', 'Mishnah Peah 1:2']),
      );
      expect(c.distinctLearnt, _mishnayos(before).distinctLearnt + 2);
      expect(c.triState(peah), TriState.complete);
      expect(c.completedUnits.map((u) => u.unit), contains(peah));
      expect(c.subTracks[ulidB]!.remainingPath, isEmpty);
    });

    test('a leaf learnt on both sources counts once (FR-14)', () {
      final state = _run([
        ...week,
        _catchUp('Mishnah Peah 1:1'),
        peah11,
      ], now: _at(13, hour: 12));
      final c = _mishnayos(state);
      final mainOnly = _mishnayos(
        _run([...week, _catchUp('Mishnah Peah 1:1')], now: _at(13, hour: 12)),
      );
      expect(c.distinctLearnt, mainOnly.distinctLearnt);
      // The main event still holds the streak day.
      expect(c.streak!.current, 6);
    });
  });

  group('AC-4: an expired card cannot be repaired from Browse', () {
    test('a later dated tick for the locked day counts but fills no gap', () {
      final backdated = _learn(
        'Mishnah Berakhot 2:1',
        learnedOn: 10,
        at: _at(13, hour: 9),
      );
      final state = _run([...week, backdated], now: _at(13, hour: 12));
      final c = _mishnayos(state);
      expect(c.learntLeaves, contains('Mishnah Berakhot 2:1'));
      expect(c.streak!.current, 3);
      // It is the leaf's first counted event, main and dated: it earns.
      expect(state.earningEventIds, contains(backdated.id));
    });
  });

  group('AC-5: a queued action that syncs after the window still counts', () {
    test('effectiveAt is the tap instant, not the sync time', () {
      // Tapped offline on Monday 22:00; evaluated on Wednesday.
      final tapped = _catchUp('Mishnah Berakhot 2:1', at: _at(12, hour: 22));
      final state = _run([...week, _day(14), tapped], now: _at(14, hour: 12));
      expect(_mishnayos(state).streak!.current, 7);
    });
  });

  group('AC-6: two devices record the same card', () {
    test('each leaf counts once; only the earliest event earns', () {
      final parent = [
        _catchUp('Mishnah Berakhot 2:1', at: _at(11, hour: 12)),
        _catchUp('Mishnah Peah 1:1', source: ulidB, at: _at(11, hour: 12)),
      ];
      final child = [
        _catchUp(
          'Mishnah Berakhot 2:1',
          at: _at(11, hour: 12, minute: 5),
          actor: _child,
        ),
        _catchUp(
          'Mishnah Peah 1:1',
          source: ulidB,
          at: _at(11, hour: 12, minute: 5),
          actor: _child,
        ),
      ];
      final both = _run([...week, ...parent, ...child], now: _at(13, hour: 12));
      final one = _run([...week, ...parent], now: _at(13, hour: 12));
      // NFR-1: every event is kept and counted.
      for (final e in [...parent, ...child]) {
        expect(both.countedEventIds, contains(e.id));
      }
      expect(_mishnayos(both).distinctLearnt, _mishnayos(one).distinctLearnt);
      expect(_mishnayos(both).streak, _mishnayos(one).streak);
      expect(both.earningEventIds, contains(parent.first.id));
      expect(both.earningEventIds, isNot(contains(child.first.id)));
      // Sub-track events never earn.
      expect(both.earningEventIds, isNot(contains(parent.last.id)));
    });
  });

  group('AC-7: undo of the action recomputes everything', () {
    test('voided catch-up events count for nothing', () {
      final action = [
        _catchUp('Mishnah Berakhot 2:1'),
        _catchUp('Mishnah Peah 1:1', source: ulidB),
      ];
      final undo = [
        for (final e in action) _voidOf(e, _at(11, hour: 12, minute: 1)),
      ];
      final state = _run([
        ...week.take(3),
        ...action,
        ...undo,
      ], now: _at(11, hour: 13));
      final c = _mishnayos(state);
      expect(c.learntLeaves, isNot(contains('Mishnah Berakhot 2:1')));
      expect(c.learntLeaves, isNot(contains('Mishnah Peah 1:1')));
      for (final e in action) {
        expect(state.countedEventIds, isNot(contains(e.id)));
        expect(state.earningEventIds, isNot(contains(e.id)));
      }
      // The card's day is pending again: Thu, Fri, Sun.
      expect(c.streak!.current, 3);
      final kept = _run([...week.take(3), ...action], now: _at(11, hour: 13));
      expect(_mishnayos(kept).streak!.current, 4);
    });
  });

  group('AC-10: projection recomputes from the locked days', () {
    test('catch-up leaves count in velocity on their learned_on day', () {
      final history = [
        for (var d = 1; d <= 9; d++)
          _learn('Mishnah Berakhot 1:1', learnedOn: d, at: _at(d)),
      ];
      final without = _mishnayos(
        _run(history, now: _at(11, hour: 13), trackingStartDate: '2026-09-25'),
      ).projection!;
      final withCatchUp = _mishnayos(
        _run(
          [
            ...history,
            _catchUp('Mishnah Berakhot 2:1'),
            _catchUp('Mishnah Berakhot 2:2'),
          ],
          now: _at(11, hour: 13),
          trackingStartDate: '2026-09-25',
        ),
      ).projection!;
      expect(withCatchUp.velocityPerDay, greaterThan(without.velocityPerDay!));
    });
  });
}
