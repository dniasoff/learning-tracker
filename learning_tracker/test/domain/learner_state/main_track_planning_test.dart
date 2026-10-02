// DNI-467 AC-3: schedulableRefs, mainTrackRemaining, current masechta and
// position over O = orderedLeaves(...), counted events, holdsGround
// sub-tracks and tracking_start_ref (AD-33, AD-34, FR-12a).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

/// `engineAt(10000)` is 2026-09-07 (UTC learner).
const _today = '2026-09-07';

SubTrack _sub(
  int id,
  List<NodeEntry> ground, {
  String start = '2026-09-01',
  String? end,
  bool ended = false,
}) => SubTrack(
  id: engineUlid(id),
  curriculumId: engineCurriculum,
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

const _peah1 = NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1');

CurriculumState _run({
  List<LearningEvent> events = const [],
  List<SubTrack> subTracks = const [],
  String? start,
  int startMinutes = 0,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    subTracks: subTracks,
    intents: {engineCurriculum: engineIntent(trackingStartRef: start)},
    intentHistory: [
      if (start != null) engineStartEntry(800, start, minutes: startMinutes),
    ],
  ),
)[engineCurriculum]!;

void main() {
  test('fixture today is $_today', () {
    expect(engineAt(10000).toIso8601String(), startsWith(_today));
  });

  test('schedulable = unlearnt leaves of O not held, at/after start first; '
      'remaining is its length', () {
    final state = _run(
      start: 'Mishnah Peah 1:1',
      events: [engineLearn(1, 'Mishnah Shabbat 1:1', minutes: 5, stage: 1)],
      subTracks: [
        _sub(10, const [berakhot2]),
      ],
    );
    expect(state.schedulableRefs, [
      'Mishnah Peah 1:1',
      'Mishnah Peah 1:2',
      'Mishnah Shabbat 1:2',
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
    ]);
    expect(state.mainTrackRemaining, state.schedulableRefs.length);
  });

  test('counted learns of any source leave the schedulable set; a voided '
      'learn does not', () {
    final state = _run(
      events: [
        engineLearn(1, 'Mishnah Berakhot 1:1', stage: 1),
        engineLearn(2, 'Mishnah Berakhot 1:2', source: engineUlid(77)),
        engineLearn(3, 'Mishnah Berakhot 1:3', stage: 1, minutes: 2),
        engineVoid(4, 3, minutes: 3),
        engineGround(5, peah),
      ],
    );
    expect(state.schedulableRefs, [
      'Mishnah Berakhot 1:3',
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
      'Mishnah Shabbat 1:1',
      'Mishnah Shabbat 1:2',
    ]);
    expect(state.mainTrackRemaining, 5);
  });

  group('holdsGround sub-tracks', () {
    test('a future-start sub-track already holds its ground', () {
      final state = _run(
        subTracks: [
          _sub(10, const [peah], start: '2026-12-01'),
        ],
      );
      expect(state.schedulableRefs, isNot(contains('Mishnah Peah 1:1')));
      expect(state.mainTrackRemaining, 7);
    });

    test('an open-ended sub-track holds; an ended or past-window one does '
        'not', () {
      final state = _run(
        subTracks: [
          _sub(10, const [peah]),
          _sub(20, const [shabbat], ended: true),
          _sub(30, const [berakhot1], start: '2026-01-01', end: '2026-09-06'),
        ],
      );
      expect(state.schedulableRefs, [
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 1:3',
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
        'Mishnah Shabbat 1:1',
        'Mishnah Shabbat 1:2',
      ]);
    });

    test('a leaf held by two sub-tracks is excluded once', () {
      final state = _run(
        subTracks: [
          _sub(10, const [peah]),
          _sub(20, const [_peah1, berakhot2]),
        ],
      );
      expect(state.mainTrackRemaining, 9 - 4);
      expect(state.schedulableRefs.toSet(), hasLength(5));
    });

    test('a sub-track of another curriculum holds nothing here', () {
      final other = SubTrack(
        id: engineUlid(40),
        curriculumId: 'bavli',
        name: 'Other',
        type: SubTrackType.ongoing,
        windowStart: '2026-09-01',
        ratePerWeek: 1,
        weeksPerYear: 40,
        learnsOnShabbos: false,
        ground: const [peah],
        lastChangeId: engineUlid(41),
      );
      expect(_run(subTracks: [other]).mainTrackRemaining, 9);
    });
  });

  group('FR-12a: one masechta at a time', () {
    test('position is the start while nothing newer is captured', () {
      final state = _run(start: 'Mishnah Berakhot 2:1', startMinutes: 1);
      expect(state.currentUnit, berakhot);
      expect(state.mainTrackPosition, 'Mishnah Berakhot 2:1');
    });

    test('returned earlier ground in the current masechta comes before the '
        'next masechta', () {
      // Berakhot perek 1 was held by a sub-track that has now ended. The
      // learner started at 2:1 and finished perek 2 on the main track.
      final state = _run(
        start: 'Mishnah Berakhot 2:1',
        startMinutes: 1,
        subTracks: [
          _sub(10, const [berakhot1], ended: true),
        ],
        events: [
          engineLearn(1, 'Mishnah Berakhot 2:1', minutes: 5, stage: 1),
          engineLearn(2, 'Mishnah Berakhot 2:2', minutes: 6, stage: 1),
        ],
      );
      // Returned leaves sort after everything at/after the start ...
      expect(state.schedulableRefs, [
        'Mishnah Peah 1:1',
        'Mishnah Peah 1:2',
        'Mishnah Shabbat 1:1',
        'Mishnah Shabbat 1:2',
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 1:3',
      ]);
      // ... but the current masechta is finished first.
      expect(state.currentUnit, berakhot);
      expect(state.mainTrackPosition, 'Mishnah Berakhot 1:1');
    });

    test('returned ground of an earlier masechta waits until the current '
        'masechta is exhausted, then follows the leaves after start', () {
      final returned = _sub(10, const [berakhot], ended: true);
      final midway = _run(
        start: 'Mishnah Peah 1:1',
        startMinutes: 1,
        subTracks: [returned],
        events: [engineLearn(1, 'Mishnah Peah 1:1', minutes: 5, stage: 1)],
      );
      expect(midway.currentUnit, peah);
      expect(midway.mainTrackPosition, 'Mishnah Peah 1:2');
      expect(
        midway.schedulableRefs.indexOf('Mishnah Berakhot 1:1'),
        greaterThan(midway.schedulableRefs.indexOf('Mishnah Peah 1:2')),
      );

      final exhausted = _run(
        start: 'Mishnah Peah 1:1',
        startMinutes: 1,
        subTracks: [returned],
        events: [
          engineLearn(1, 'Mishnah Peah 1:1', minutes: 5, stage: 1),
          engineLearn(2, 'Mishnah Peah 1:2', minutes: 6, stage: 1),
        ],
      );
      expect(exhausted.currentUnit, isNull);
      expect(exhausted.mainTrackPosition, 'Mishnah Shabbat 1:1');
      expect(exhausted.schedulableRefs.last, 'Mishnah Berakhot 2:2');
    });

    test('a later main-track capture moves the current masechta', () {
      final state = _run(
        start: 'Mishnah Berakhot 1:1',
        startMinutes: 1,
        events: [engineLearn(1, 'Mishnah Shabbat 1:1', minutes: 5, stage: 1)],
      );
      expect(state.currentUnit, shabbat);
      expect(state.mainTrackPosition, 'Mishnah Shabbat 1:2');
    });
  });

  test('live order docs reorder O for position, schedulable and remaining; '
      'ended docs do not', () {
    MainTrackOrderEntry order(NodeEntry node, int sort, {bool ended = false}) =>
        MainTrackOrderEntry(
          docId: '${engineCurriculum}_${node.level}_${node.ref}',
          curriculumId: engineCurriculum,
          level: node.level,
          ref: node.ref,
          userSortOrder: sort,
          lastChangeId: engineUlid(900),
          endedAt: ended ? engineAt(2) : null,
        );
    final intent = MainTrackIntent(
      curriculumId: engineCurriculum,
      track: engineIntent().track,
      order: [order(moed, 0), order(peah, 0), order(berakhot2, 0, ended: true)],
    );
    final state = const LearnerStateEngine().run(
      engineInputs(
        intents: {engineCurriculum: intent},
        events: [engineLearn(1, 'Mishnah Shabbat 1:1', minutes: 5, stage: 1)],
      ),
    )[engineCurriculum]!;
    expect(state.schedulableRefs, [
      'Mishnah Shabbat 1:2',
      'Mishnah Peah 1:1',
      'Mishnah Peah 1:2',
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
    ]);
    expect(state.mainTrackRemaining, 8);
    expect(state.currentUnit, shabbat);
    expect(state.mainTrackPosition, 'Mishnah Shabbat 1:2');
  });

  test('every planning output is deterministic for identical inputs', () {
    CurriculumState run() => _run(
      start: 'Mishnah Peah 1:1',
      subTracks: [
        _sub(10, const [berakhot2]),
      ],
      events: [engineLearn(1, 'Mishnah Peah 1:1', minutes: 5, stage: 1)],
    );
    final a = run();
    final b = run();
    expect(b.schedulableRefs, a.schedulableRefs);
    expect(b.mainTrackRemaining, a.mainTrackRemaining);
    expect(b.currentUnit, a.currentUnit);
    expect(b.mainTrackPosition, a.mainTrackPosition);
  });
}
