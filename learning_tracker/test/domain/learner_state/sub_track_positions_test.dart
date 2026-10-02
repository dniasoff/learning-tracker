// Mirror test for `lib/domain/learner_state/sub_track_positions.dart`
// (DNI-493 AC-2, AC-3: per-sub-track position, ticked count and remaining
// path, AD-33/AD-34).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_positions.dart';

import '../../helpers/learner_state/chumash_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

const _today = '2026-10-01';

SubTrack _sub(
  int id,
  List<NodeEntry> ground, {
  String curriculumId = engineCurriculum,
  String start = '2026-09-01',
  String? end,
  bool ended = false,
}) => SubTrack(
  id: engineUlid(id),
  curriculumId: curriculumId,
  name: 'Sub $id',
  type: SubTrackType.ongoing,
  windowStart: start,
  windowEnd: end,
  ratePerWeek: 2,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: engineUlid(id + 1),
  endedAt: ended ? engineAt(1) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

Map<String, SubTrackState> _states(
  List<SubTrack> subTracks,
  List<LearningEvent> learns, {
  String? deadline,
}) => subTrackStates(
  subTracks: subTracks,
  corpus: mishnayosCorpus(),
  countedLearns: learns,
  today: _today,
  deadline: deadline,
);

void main() {
  final school = _sub(10, const [berakhot]);
  final rebbe = _sub(20, const [berakhot2, peah]);

  test('with no events the position is the first ground leaf and the '
      'remaining path is the whole expanded ground', () {
    final s = _states([rebbe], const [])[rebbe.id]!;
    expect(s.position, 'Mishnah Berakhot 2:1');
    expect(s.ticked, 0);
    expect(s.remainingPath, [
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
      'Mishnah Peah 1:1',
      'Mishnah Peah 1:2',
    ]);
    expect(s.groundExhausted, isFalse);
    expect(s.holdsGround, isTrue);
    expect(s.onHome, isTrue);
    expect(s.inForecast, isTrue);
  });

  test('position is the first leaf not ticked from this source; remaining '
      'runs from it to the end, including leaves learnt elsewhere', () {
    final s = _states(
      [school],
      [
        engineLearn(1, 'Mishnah Berakhot 1:1', source: school.id),
        engineLearn(2, 'Mishnah Berakhot 1:3', source: school.id),
        // Learnt from main: learnt globally, but not ticked in School.
        engineLearn(3, 'Mishnah Berakhot 1:2', stage: 1),
      ],
    )[school.id]!;
    expect(s.position, 'Mishnah Berakhot 1:2');
    expect(s.ticked, 2);
    expect(s.remainingPath, [
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
    ]);
  });

  test('AC-3: a Rebbe event on a shared leaf advances Rebbe only', () {
    final states = _states(
      [school, rebbe],
      [engineLearn(1, 'Mishnah Berakhot 2:1', source: rebbe.id)],
    );
    expect(states[rebbe.id]!.position, 'Mishnah Berakhot 2:2');
    expect(states[rebbe.id]!.ticked, 1);
    expect(states[school.id]!.position, 'Mishnah Berakhot 1:1');
    expect(states[school.id]!.ticked, 0);
  });

  test('repeats from the same source count one distinct ticked leaf; '
      'ticks outside the ground count nothing', () {
    final s = _states(
      [rebbe],
      [
        engineLearn(1, 'Mishnah Berakhot 2:1', source: rebbe.id),
        engineLearn(2, 'Mishnah Berakhot 2:1', source: rebbe.id, minutes: 1),
        engineLearn(3, 'Mishnah Shabbat 1:1', source: rebbe.id, minutes: 2),
      ],
    )[rebbe.id]!;
    expect(s.ticked, 1);
    expect(s.position, 'Mishnah Berakhot 2:2');
  });

  test('every ground leaf ticked: no position, empty path, exhausted', () {
    final s = _states(
      [
        _sub(30, const [berakhot2]),
      ],
      [
        engineLearn(1, 'Mishnah Berakhot 2:2', source: engineUlid(30)),
        engineLearn(2, 'Mishnah Berakhot 2:1', source: engineUlid(30)),
      ],
    )[engineUlid(30)]!;
    expect(s.position, isNull);
    expect(s.ticked, 2);
    expect(s.remainingPath, isEmpty);
    expect(s.groundExhausted, isTrue);
  });

  test('a groundless sub-track has no position and is not exhausted', () {
    final s = _states([_sub(40, const [])], const [])[engineUlid(40)]!;
    expect(s.position, isNull);
    expect(s.ticked, 0);
    expect(s.remainingPath, isEmpty);
    expect(s.groundExhausted, isFalse);
  });

  test('a later tick does not move a position behind it back', () {
    // Ticks skipping ahead: position stays at the earliest unticked leaf.
    final s = _states(
      [school],
      [engineLearn(1, 'Mishnah Berakhot 2:2', source: school.id)],
    )[school.id]!;
    expect(s.position, 'Mishnah Berakhot 1:1');
    expect(s.remainingPath, hasLength(5));
    expect(s.ticked, 1);
  });

  test('node entries at masechta, perek and leaf level, overlapping, '
      'expand once in list order', () {
    final s = _states([
      _sub(50, const [
        NodeEntry(level: 'mishnah', ref: 'Mishnah Peah 1:2'),
        berakhot2,
        berakhot,
      ]),
    ], const [])[engineUlid(50)]!;
    expect(s.remainingPath, [
      'Mishnah Peah 1:2',
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
    ]);
  });

  test('tombstoned and future sub-tracks get states with their '
      'predicates', () {
    final ended = _sub(60, const [peah], ended: true);
    final future = _sub(70, const [shabbat], start: '2027-01-01');
    final states = _states(
      [ended, future],
      [engineLearn(1, 'Mishnah Peah 1:1', source: ended.id)],
      deadline: '2026-12-31',
    );
    final e = states[ended.id]!;
    expect((e.holdsGround, e.onHome, e.inForecast), (false, false, false));
    expect(e.position, 'Mishnah Peah 1:2');
    expect(e.ticked, 1);
    final f = states[future.id]!;
    // Holds now; capacity interval [2027-01-01, 2026-12-31] is empty.
    expect((f.holdsGround, f.onHome, f.inForecast), (true, false, false));
    expect(f.position, 'Mishnah Shabbat 1:1');
  });

  test('sub-tracks of another curriculum are left out', () {
    final other = _sub(80, const [genesis], curriculumId: chumashCurriculum);
    expect(_states([other], const []), isEmpty);
  });

  test('a non-Mishnayos curriculum derives positions over its own '
      'levels', () {
    final shiur = _sub(90, [
      exodus,
      genesis2,
      verse('Genesis 1:3'),
    ], curriculumId: chumashCurriculum);
    final states = subTrackStates(
      subTracks: [shiur],
      corpus: chumashCorpus(),
      countedLearns: [
        engineLearn(
          1,
          'Exodus 1:1',
          curriculumId: chumashCurriculum,
          source: shiur.id,
        ),
      ],
      today: _today,
      deadline: null,
    );
    final s = states[shiur.id]!;
    expect(s.position, 'Exodus 1:2');
    expect(s.ticked, 1);
    expect(s.remainingPath, [
      'Exodus 1:2',
      'Genesis 2:1',
      'Genesis 2:2',
      'Genesis 1:3',
    ]);
  });

  test('DNI-501: recordedAhead holds the remaining-path leaves already '
      'ticked in this source, not leaves learnt elsewhere', () {
    final s = _states(
      [school],
      [
        engineLearn(1, 'Mishnah Berakhot 1:1', source: school.id),
        engineLearn(2, 'Mishnah Berakhot 1:3', source: school.id),
        engineLearn(3, 'Mishnah Berakhot 1:2', stage: 1),
        engineLearn(4, 'Mishnah Berakhot 2:1', source: rebbe.id),
      ],
    )[school.id]!;
    expect(s.recordedAhead, {'Mishnah Berakhot 1:3'});
    expect(s.recordedAhead, isNot(contains(s.position)));
    expect(() => s.recordedAhead.add('x'), throwsUnsupportedError);
    final exhausted = _states(
      [rebbe],
      [
        for (final (i, ref) in [
          'Mishnah Berakhot 2:1',
          'Mishnah Berakhot 2:2',
          'Mishnah Peah 1:1',
          'Mishnah Peah 1:2',
        ].indexed)
          engineLearn(i + 10, ref, source: rebbe.id),
      ],
    )[rebbe.id]!;
    expect(exhausted.recordedAhead, isEmpty);
  });

  test('the remaining path is unmodifiable', () {
    final s = _states([school], const [])[school.id]!;
    expect(() => s.remainingPath.add('x'), throwsUnsupportedError);
  });
}
