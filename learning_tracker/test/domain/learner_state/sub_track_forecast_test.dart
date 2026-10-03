// Mirror test for `lib/domain/learner_state/sub_track_forecast.dart`: the
// AD-44 deadline forecast over `holdsGround` sub-tracks (DNI-494). Capacity
// is made trivially countable: 10/wk x 36.5 weeks/yr over a 365-day ongoing
// window is exactly one leaf per day of the capacity interval.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_forecast.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

const _today = '2026-09-07';

/// Three days [_today .. 2026-09-09]: capacity 3.
const _target = '2026-09-09';

const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';
const _b21 = 'Mishnah Berakhot 2:1';
const _b22 = 'Mishnah Berakhot 2:2';
const _p11 = 'Mishnah Peah 1:1';
const _p12 = 'Mishnah Peah 1:2';

SubTrack _track(
  int n,
  List<NodeEntry> ground, {
  double ratePerWeek = 10,
  String? windowEnd,
  DateTime? endedAt,
}) => SubTrack(
  id: engineUlid(n),
  curriculumId: engineCurriculum,
  name: 'Track $n',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  windowEnd: windowEnd,
  ratePerWeek: ratePerWeek,
  weeksPerYear: 36.5,
  learnsOnShabbos: true,
  ground: ground,
  lastChangeId: engineUlid(900),
  endedAt: endedAt,
);

SubTrackState _state(SubTrack s, List<LeafRef> path, {String? name}) =>
    SubTrackState(
      subTrackId: s.id,
      holdsGround: true,
      inForecast: true,
      onHome: true,
      remainingPath: path,
      name: name ?? s.name,
    );

DeadlineForecast _forecast(
  List<SubTrack> tracks,
  Map<String, SubTrackState> states, {
  Set<LeafRef> learnt = const {},
  bool Function(LeafRef)? inScope,
  int mainTrackRemaining = 10,
  String today = _today,
  String target = _target,
}) => deriveDeadlineForecast(
  subTracks: tracks,
  states: states,
  corpus: mishnayosCorpus(),
  isLearnt: learnt.contains,
  inScope: inScope ?? (_) => true,
  mainTrackRemaining: mainTrackRemaining,
  today: today,
  targetDate: target,
);

void main() {
  group('deriveDeadlineForecast', () {
    test('a path longer than capacity leaves a shortfall', () {
      final s = _track(1, [berakhot]);
      final f = _forecast(
        [s],
        {
          s.id: _state(s, [_b11, _b12, _b13, _b21, _b22]),
        },
      );
      final sf = f.subTracks[s.id]!;
      expect(sf.capacity, 3);
      expect(sf.expectedNewGround, 0);
      expect(sf.shortfallLeaves, [_b21, _b22]);
      expect(sf.lastShortfallNode, berakhot);
      expect(f.mainTrackRemaining, 10);
      expect(f.expectedNewGround, 0);
      expect(f.shortfall, 2);
      expect(f.numerator, 12);
    });

    test('spare capacity is expected new ground, with no shortfall', () {
      final s = _track(1, [peah]);
      final f = _forecast(
        [s],
        {
          s.id: _state(s, [_p11, _p12]),
        },
      );
      final sf = f.subTracks[s.id]!;
      expect(sf.capacity, 3);
      expect(sf.expectedNewGround, 1);
      expect(sf.shortfallLeaves, isEmpty);
      expect(sf.lastShortfallNode, isNull);
      expect(f.numerator, 10 - 1);
    });

    test('a path that exactly fits capacity has neither', () {
      final s = _track(1, [berakhot1]);
      final f = _forecast(
        [s],
        {
          s.id: _state(s, [_b11, _b12, _b13]),
        },
      );
      expect(f.subTracks[s.id]!.expectedNewGround, 0);
      expect(f.subTracks[s.id]!.shortfallLeaves, isEmpty);
      expect(f.numerator, 10);
    });

    test('learnt leaves past capacity are not shortfall', () {
      final s = _track(1, [berakhot]);
      final f = _forecast(
        [s],
        {
          s.id: _state(s, [_b11, _b12, _b13, _b21, _b22]),
        },
        learnt: {_b21},
      );
      expect(f.subTracks[s.id]!.shortfallLeaves, [_b22]);
    });

    test('out-of-scope leaves use no capacity and are never shortfall', () {
      final s = _track(1, [berakhot]);
      final f = _forecast(
        [s],
        {
          s.id: _state(s, [_b11, _b12, _b13, _b21, _b22]),
        },
        // Dropping b11 shifts the reached set to b12..b21.
        inScope: (ref) => ref != _b11 && ref != _b22,
      );
      final sf = f.subTracks[s.id]!;
      expect(sf.shortfallLeaves, isEmpty);
      expect(sf.expectedNewGround, 0);
    });

    test(
      'lastShortfallNode is the last ground entry holding a shortfall leaf',
      () {
        final s = _track(1, [berakhot2, berakhot1]);
        // Path in ground order: b21 b22 b11 b12 b13; capacity 3 reaches up to
        // b11, shortfall b12 b13 sits in berakhot1 (the last entry).
        final f = _forecast(
          [s],
          {
            s.id: _state(s, [_b21, _b22, _b11, _b12, _b13]),
          },
        );
        expect(f.subTracks[s.id]!.lastShortfallNode, berakhot1);

        final t = _track(2, [berakhot1, berakhot2]);
        // Shortfall b11..? path b11 b12 b13 b21 b22, shortfall in berakhot2.
        final g = _forecast(
          [t],
          {
            t.id: _state(t, [_b11, _b12, _b13, _b21, _b22]),
          },
        );
        expect(g.subTracks[t.id]!.lastShortfallNode, berakhot2);
      },
    );

    test('a leaf another holder reaches within capacity is not shortfall', () {
      final a = _track(1, [berakhot], ratePerWeek: 10 / 3);
      final b = _track(2, [berakhot2]);
      // A: capacity 1, path b11 b12 b13 b21 b22. B: capacity 3, path b21 b22.
      final f = _forecast(
        [a, b],
        {
          a.id: _state(a, [_b11, _b12, _b13, _b21, _b22]),
          b.id: _state(b, [_b21, _b22]),
        },
      );
      expect(f.subTracks[a.id]!.capacity, 1);
      expect(f.subTracks[a.id]!.shortfallLeaves, [_b12, _b13]);
      expect(f.subTracks[b.id]!.shortfallLeaves, isEmpty);
      // Expected new ground is additive per track: B has 1 spare.
      expect(f.expectedNewGround, 1);
      expect(f.numerator, 10 - 1 + 2);
    });

    test(
      'a shortfall leaf shared by holders is counted once, under the first id',
      () {
        final a = _track(1, [berakhot2], ratePerWeek: 0);
        final b = _track(2, [berakhot2], ratePerWeek: 0);
        final f = _forecast(
          [b, a],
          {
            a.id: _state(a, [_b21, _b22]),
            b.id: _state(b, [_b21, _b22]),
          },
        );
        expect(f.subTracks[a.id]!.capacity, 0);
        expect(f.subTracks[a.id]!.shortfallLeaves, [_b21, _b22]);
        expect(f.subTracks[b.id]!.shortfallLeaves, isEmpty);
        expect(f.shortfall, 2);
      },
    );

    test('an empty capacity interval puts the whole path in shortfall', () {
      final s = _track(1, [peah]);
      final f = _forecast(
        [s],
        {
          s.id: _state(s, [_p11, _p12]),
        },
        today: '2026-09-10',
        target: '2026-09-09',
      );
      expect(f.subTracks[s.id]!.capacity, 0);
      expect(f.subTracks[s.id]!.shortfallLeaves, [_p11, _p12]);
      expect(f.subTracks[s.id]!.lastShortfallNode, peah);
    });

    test('only sub-tracks holding ground with a state take part', () {
      final live = _track(1, [peah]);
      final ended = _track(2, [peah], endedAt: DateTime.utc(2026, 9, 2));
      final passed = _track(3, [peah], windowEnd: '2026-09-06');
      final noState = _track(4, [peah]);
      final f = _forecast(
        [live, ended, passed, noState],
        {
          live.id: _state(live, [_p11, _p12]),
          ended.id: _state(ended, [_p11, _p12]),
          passed.id: _state(passed, [_p11, _p12]),
        },
      );
      expect(f.subTracks.keys, [live.id]);
    });

    test('no sub-track is the plain main-track remaining', () {
      final f = _forecast(const [], const {}, mainTrackRemaining: 7);
      expect(f.subTracks, isEmpty);
      expect(f.numerator, 7);
      expect(() => f.subTracks['x'] = _noForecast, throwsUnsupportedError);
    });
  });

  group('withForecast', () {
    test('fills AD-44 fields of forecast tracks and keeps the rest', () {
      final s = _track(1, [berakhot]);
      final other = _track(2, [peah]);
      final states = {
        s.id: _state(s, [_b11, _b12, _b13, _b21, _b22], name: 'Rebbe'),
        other.id: _state(other, [_p11]),
      };
      final f = _forecast([s], states);
      final out = withForecast(states, f);

      final filled = out[s.id]!;
      expect(filled.capacity, 3);
      expect(filled.expectedNewGround, 0);
      expect(filled.shortfall, 2);
      expect(filled.shortfallLeaves, [_b21, _b22]);
      expect(filled.lastShortfallNode, berakhot);
      expect(filled.name, 'Rebbe');
      expect(filled.remainingPath, states[s.id]!.remainingPath);
      expect(filled.holdsGround, isTrue);
      expect(filled.subTrackId, s.id);

      expect(out[other.id], same(states[other.id]));
      expect(out[other.id]!.capacity, isNull);
    });
  });
}

final _noForecast = SubTrackForecast(
  capacity: 0,
  expectedNewGround: 0,
  shortfallLeaves: const [],
);
