// DNI-493 (Story 2.2) engine acceptance: sub-track positions, held ground
// and ground return through `LearnerStateEngine.run` (AD-33, AD-34, AD-35,
// FR-12, FR-12a, FR-13, prd-deviations #4 and #12).
//
// Kept apart from `learner_state_engine_test.dart` (a merge hotspot shared
// by the Epic 1 engine stories) so the sub-track matrix lands in one file.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/chumash_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

/// `engineAt(10000)` is 2026-09-07 (UTC learner).
const _today = '2026-09-07';

SubTrack _sub(
  int id,
  List<NodeEntry> ground, {
  String curriculumId = engineCurriculum,
  String start = '2026-09-01',
  String? end,
  SubTrackEndReason? endReason,
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
  endedAt: endReason == null ? null : engineAt(1),
  endReason: endReason,
);

LearnerState _run({
  List<LearningEvent> events = const [],
  List<SubTrack> subTracks = const [],
  MainTrackIntent? intent,
  String? start,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    subTracks: subTracks,
    intents: {
      engineCurriculum: intent ?? engineIntent(trackingStartRef: start),
    },
    intentHistory: [
      if (start != null) engineStartEntry(800, start, minutes: 1),
    ],
  ),
);

CurriculumState _mishnayos(LearnerState s) => s[engineCurriculum]!;

const _allLeaves = [
  'Mishnah Berakhot 1:1',
  'Mishnah Berakhot 1:2',
  'Mishnah Berakhot 1:3',
  'Mishnah Berakhot 2:1',
  'Mishnah Berakhot 2:2',
  'Mishnah Peah 1:1',
  'Mishnah Peah 1:2',
  'Mishnah Shabbat 1:1',
  'Mishnah Shabbat 1:2',
];

void main() {
  test('fixture today is $_today', () {
    expect(engineAt(10000).toIso8601String(), startsWith(_today));
  });

  group('AC-2: one sub-track position, count and remaining path', () {
    test('derived from its own counted events, never from storage', () {
      final shiur = _sub(10, const [berakhot]);
      final state = _mishnayos(
        _run(
          subTracks: [shiur],
          events: [
            engineLearn(1, 'Mishnah Berakhot 1:1', source: shiur.id),
            engineLearn(2, 'Mishnah Berakhot 1:1', source: shiur.id),
            engineLearn(3, 'Mishnah Berakhot 1:2', stage: 1),
            engineLearn(4, 'Mishnah Berakhot 1:3', source: shiur.id),
            // A voided tick does not count for the sub-track either.
            engineLearn(5, 'Mishnah Berakhot 1:2', source: shiur.id),
            engineVoid(6, 5, minutes: 1),
          ],
        ),
      );
      final s = state.subTracks[shiur.id]!;
      expect(s.position, 'Mishnah Berakhot 1:2');
      expect(s.ticked, 2);
      expect(s.remainingPath, [
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 1:3',
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
      ]);
      expect(s.groundExhausted, isFalse);
    });

    test('no derived field is part of the sub-track storage shape', () {
      final shiur = _sub(10, const [berakhot]);
      final stored = shiur.toStorage();
      for (final derived in [
        'position',
        'ticked',
        'remaining',
        'remaining_path',
        'schedulable_refs',
        'current_unit',
      ]) {
        expect(SubTrack.storageKeys, isNot(contains(derived)));
        expect(stored.keys, isNot(contains(derived)));
      }
    });
  });

  test('AC-3: School and Rebbe share a leaf; a Rebbe event advances Rebbe '
      'only, and the leaf is learnt once for progress and tri-state', () {
    final school = _sub(10, const [berakhot]);
    final rebbe = _sub(20, const [berakhot2]);
    final state = _mishnayos(
      _run(
        subTracks: [school, rebbe],
        events: [engineLearn(1, 'Mishnah Berakhot 2:1', source: rebbe.id)],
      ),
    );
    expect(state.subTracks[rebbe.id]!.position, 'Mishnah Berakhot 2:2');
    expect(state.subTracks[school.id]!.position, 'Mishnah Berakhot 1:1');
    expect(state.subTracks[school.id]!.ticked, 0);
    expect(state.learntLeaves, {'Mishnah Berakhot 2:1'});
    expect(state.distinctLearnt, 1);
    expect(state.triState(berakhot2), TriState.partial);
    expect(state.triState(berakhot1), TriState.empty);
  });

  group('AC-4: held ground is off the main track', () {
    test('a future-start sub-track holds its expanded ground now', () {
      final future = _sub(10, const [
        berakhot2,
        NodeEntry(level: 'mishnah', ref: 'Mishnah Shabbat 1:2'),
      ], start: '2026-12-01');
      final state = _mishnayos(_run(subTracks: [future]));
      const held = [
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
        'Mishnah Shabbat 1:2',
      ];
      for (final leaf in held) {
        expect(state.schedulableRefs, isNot(contains(leaf)));
      }
      expect(state.mainTrackRemaining, _allLeaves.length - held.length);
      expect(held, isNot(contains(state.mainTrackPosition)));
      final s = state.subTracks[future.id]!;
      expect((s.holdsGround, s.onHome), (true, false));
      expect(s.position, 'Mishnah Berakhot 2:1');
    });
  });

  group('AC-5: ending a sub-track returns its unlearnt ground', () {
    // Each way a sub-track stops holding: explicit end, delete, and a
    // window that ended before today.
    final endings = <String, SubTrack Function(int, List<NodeEntry>)>{
      'end_reason ended': (id, g) =>
          _sub(id, g, endReason: SubTrackEndReason.ended),
      'end_reason deleted': (id, g) =>
          _sub(id, g, endReason: SubTrackEndReason.deleted),
      'today > window_end': (id, g) =>
          _sub(id, g, start: '2026-01-01', end: '2026-09-06'),
    };

    for (final MapEntry(key: how, value: make) in endings.entries) {
      test('$how: unlearnt leaves re-enter at their orderedLeaves position; '
          'learnt ones stay off; events still count', () {
        final s = make(10, const [berakhot2, peah]);
        final events = [
          engineLearn(1, 'Mishnah Berakhot 2:1', source: s.id),
          engineLearn(2, 'Mishnah Peah 1:2', source: s.id, minutes: 1),
        ];
        final before = List<LearningEvent>.of(events);
        final whole = _run(subTracks: [s], events: events);
        final state = _mishnayos(whole);
        expect(state.schedulableRefs, [
          'Mishnah Berakhot 1:1',
          'Mishnah Berakhot 1:2',
          'Mishnah Berakhot 1:3',
          'Mishnah Berakhot 2:2',
          'Mishnah Peah 1:1',
          'Mishnah Shabbat 1:1',
          'Mishnah Shabbat 1:2',
        ]);
        expect(state.mainTrackRemaining, 7);
        expect(state.learntLeaves, {
          'Mishnah Berakhot 2:1',
          'Mishnah Peah 1:2',
        });
        expect(whole.countedEventIds, {engineUlid(1), engineUlid(2)});
        expect(events, before);
        expect(state.subTracks[s.id]!.holdsGround, isFalse);
      });
    }

    test('a leaf held by a second sub-track stays off until neither holds '
        'it', () {
      final ended = _sub(10, const [
        berakhot2,
      ], endReason: SubTrackEndReason.ended);
      final stillHolding = _sub(20, const [
        NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 2:2'),
      ]);
      final one = _mishnayos(_run(subTracks: [ended, stillHolding]));
      expect(one.schedulableRefs, contains('Mishnah Berakhot 2:1'));
      expect(one.schedulableRefs, isNot(contains('Mishnah Berakhot 2:2')));

      final bothEnded = _mishnayos(
        _run(
          subTracks: [
            ended,
            _sub(20, const [
              NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 2:2'),
            ], endReason: SubTrackEndReason.ended),
          ],
        ),
      );
      expect(bothEnded.schedulableRefs, _allLeaves);
    });

    test('a leaf learnt by any source never returns, even when two '
        'sub-tracks held it', () {
      final a = _sub(10, const [berakhot2], endReason: SubTrackEndReason.ended);
      final b = _sub(20, const [berakhot2], endReason: SubTrackEndReason.ended);
      final state = _mishnayos(
        _run(
          subTracks: [a, b],
          events: [
            engineLearn(1, 'Mishnah Berakhot 2:1', source: b.id),
            engineLearn(2, 'Mishnah Berakhot 2:2', minutes: 1),
          ],
        ),
      );
      expect(state.schedulableRefs, isNot(contains('Mishnah Berakhot 2:1')));
      expect(state.schedulableRefs, isNot(contains('Mishnah Berakhot 2:2')));
    });

    test('FR-12a: returned leaves before the current unit wait until the '
        "current unit's schedulable leaves are done", () {
      // Started at Berakhot 1:1 with perek 2 held by a shiur, the learner
      // finished perek 1 and moved into Peah. Then the shiur ended.
      final shiur = _sub(10, const [
        berakhot2,
      ], endReason: SubTrackEndReason.ended);
      final mainSoFar = [
        engineLearn(1, 'Mishnah Berakhot 1:1', minutes: 2, stage: 1),
        engineLearn(2, 'Mishnah Berakhot 1:2', minutes: 3, stage: 1),
        engineLearn(3, 'Mishnah Berakhot 1:3', minutes: 4, stage: 1),
        engineLearn(4, 'Mishnah Peah 1:1', minutes: 5, stage: 1),
      ];
      final midway = _mishnayos(
        _run(
          start: 'Mishnah Berakhot 1:1',
          subTracks: [shiur],
          events: mainSoFar,
        ),
      );
      // Returned at their order position, not appended ...
      expect(midway.schedulableRefs, [
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
        'Mishnah Peah 1:2',
        'Mishnah Shabbat 1:1',
        'Mishnah Shabbat 1:2',
      ]);
      // ... but the current masechta comes first.
      expect(midway.currentUnit, peah);
      expect(midway.mainTrackPosition, 'Mishnah Peah 1:2');

      final peahDone = _mishnayos(
        _run(
          start: 'Mishnah Berakhot 1:1',
          subTracks: [shiur],
          events: [
            ...mainSoFar,
            engineLearn(5, 'Mishnah Peah 1:2', minutes: 6, stage: 1),
          ],
        ),
      );
      expect(peahDone.currentUnit, isNull);
      expect(peahDone.mainTrackPosition, 'Mishnah Berakhot 2:1');
    });
  });

  group('AC-6: a curriculum that is not evaluated', () {
    final intents = <String, MainTrackIntent>{
      'state retired': engineIntent(state: MainTrackState.retired),
      'state archived': engineIntent(state: MainTrackState.archived),
      'active with ended_at': engineIntent(endedAt: engineAt(2)),
    };
    for (final MapEntry(key: how, value: intent) in intents.entries) {
      test('$how: no position, exclusion or forecast; events still count', () {
        final shiur = _sub(10, const [berakhot]);
        final whole = _run(
          intent: intent,
          subTracks: [shiur],
          events: [
            for (var i = 0; i < 5; i++)
              engineLearn(i + 1, _allLeaves[i], source: shiur.id, minutes: i),
          ],
        );
        final state = _mishnayos(whole);
        expect(state.evaluated, isFalse);
        expect(state.subTracks, isEmpty);
        expect(state.schedulableRefs, isEmpty);
        expect(state.mainTrackRemaining, 0);
        expect(state.mainTrackPosition, isNull);
        // Lifetime and siyum still see the sub-track's events.
        expect(state.distinctLearnt, 5);
        expect(state.triState(berakhot), TriState.complete);
        expect(state.completedUnits.map((u) => u.unit), contains(berakhot));
        expect(whole.countedEventIds, hasLength(5));
      });
    }
  });

  group('AC-7: matrix', () {
    test('ground already learnt (chazara) stays off the main track and '
        'keeps the sub-track position until ticked there', () {
      final chazara = _sub(10, const [berakhot1]);
      final state = _mishnayos(
        _run(
          subTracks: [chazara],
          events: [
            engineLearn(1, 'Mishnah Berakhot 1:1', stage: 1),
            engineLearn(2, 'Mishnah Berakhot 1:2', stage: 1, minutes: 1),
          ],
        ),
      );
      final s = state.subTracks[chazara.id]!;
      expect(s.position, 'Mishnah Berakhot 1:1');
      expect(s.ticked, 0);
      expect(s.remainingPath, hasLength(3));
      expect(state.schedulableRefs, isNot(contains('Mishnah Berakhot 1:3')));
      expect(state.mainTrackRemaining, 9 - 3);
    });

    test('overlapping ground across two live tracks is excluded once and '
        'each keeps its own position', () {
      final a = _sub(10, const [zeraim]);
      final b = _sub(20, const [peah, shabbat]);
      final state = _mishnayos(
        _run(
          subTracks: [a, b],
          events: [
            engineLearn(1, 'Mishnah Peah 1:1', source: b.id),
            engineLearn(2, 'Mishnah Berakhot 1:1', source: a.id),
          ],
        ),
      );
      expect(state.schedulableRefs, isEmpty);
      expect(state.subTracks[a.id]!.position, 'Mishnah Berakhot 1:2');
      expect(state.subTracks[a.id]!.remainingPath, hasLength(6));
      expect(state.subTracks[b.id]!.position, 'Mishnah Peah 1:2');
      expect(state.subTracks[b.id]!.remainingPath, [
        'Mishnah Peah 1:2',
        'Mishnah Shabbat 1:1',
        'Mishnah Shabbat 1:2',
      ]);
    });

    test('an ended track with partly learnt ground keeps its position over '
        'its own events', () {
      final s = _sub(10, const [
        berakhot2,
        peah,
      ], endReason: SubTrackEndReason.ended);
      final state = _mishnayos(
        _run(
          subTracks: [s],
          events: [engineLearn(1, 'Mishnah Berakhot 2:1', source: s.id)],
        ),
      );
      final st = state.subTracks[s.id]!;
      expect((st.holdsGround, st.onHome, st.inForecast), (false, false, false));
      expect(st.position, 'Mishnah Berakhot 2:2');
      expect(st.ticked, 1);
    });

    test('a non-Mishnayos curriculum (Chumash) holds, positions and returns '
        'by its own levels and sefer units', () {
      final shiur = _sub(10, [
        genesis2,
        verse('Exodus 1:1'),
      ], curriculumId: chumashCurriculum);
      LearnerState run(List<SubTrack> subTracks) =>
          const LearnerStateEngine().run(
            engineInputs(
              subTracks: subTracks,
              intents: {chumashCurriculum: chumashIntent()},
              corpora: {chumashCurriculum: chumashCorpus()},
              events: [
                engineLearn(
                  1,
                  'Genesis 2:1',
                  curriculumId: chumashCurriculum,
                  source: shiur.id,
                ),
                engineLearn(
                  2,
                  'Genesis 1:1',
                  curriculumId: chumashCurriculum,
                  stage: 1,
                  minutes: 1,
                ),
              ],
            ),
          );

      final holding = run([shiur])[chumashCurriculum]!;
      expect(holding.schedulableRefs, [
        'Genesis 1:2',
        'Genesis 1:3',
        'Exodus 1:2',
      ]);
      expect(holding.currentUnit, genesis);
      expect(holding.mainTrackPosition, 'Genesis 1:2');
      final s = holding.subTracks[shiur.id]!;
      expect(s.position, 'Genesis 2:2');
      expect(s.ticked, 1);
      expect(s.remainingPath, ['Genesis 2:2', 'Exodus 1:1']);

      final ended = _sub(
        10,
        [genesis2, verse('Exodus 1:1')],
        curriculumId: chumashCurriculum,
        endReason: SubTrackEndReason.ended,
      );
      final returned = run([ended])[chumashCurriculum]!;
      expect(returned.schedulableRefs, [
        'Genesis 1:2',
        'Genesis 1:3',
        'Genesis 2:2',
        'Exodus 1:1',
        'Exodus 1:2',
      ]);
    });
  });
}
