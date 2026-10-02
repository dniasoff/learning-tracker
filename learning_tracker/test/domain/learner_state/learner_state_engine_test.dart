// Mirror test for `lib/domain/learner_state/learner_state_engine.dart`
// (DNI-465): AC-1, AC-2, AC-4, AC-5 and AC-6 of Story 1.3, plus the
// story's edge coverage. AC-3 is in expand_ground_test.dart and AC-7 in
// completed_units_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  const engine = LearnerStateEngine();
  const b11 = 'Mishnah Berakhot 1:1';
  const b12 = 'Mishnah Berakhot 1:2';
  final subTrack = engineUlid(900);

  CurriculumState stateOf(LearnerStateInputs inputs) =>
      engine.run(inputs)[engineCurriculum]!;

  group('AC-1', () {
    test('is pure and limits plan evaluation to active tracks', () {
      final retiredCorpus = InMemoryCorpus('retired', const [
        CorpusNode(NodeEntry(level: 'sefer', ref: 'R'), [
          CorpusNode(NodeEntry(level: 'chapter', ref: 'R 1')),
        ]),
      ]);
      final inputs = engineInputs(
        events: [
          engineLearn(1, b11, stage: 1),
          engineLearn(2, 'R 1', curriculumId: 'retired', stage: 1),
          engineLearn(3, 'Berakhot 2a', curriculumId: 'bavli'),
        ],
        intents: {
          engineCurriculum: engineIntent(),
          'retired': engineIntent(
            curriculumId: 'retired',
            state: MainTrackState.retired,
          ),
          'ended': engineIntent(curriculumId: 'ended', endedAt: engineAt(1)),
        },
        corpora: {
          engineCurriculum: mishnayosCorpus(),
          'retired': retiredCorpus,
        },
      );
      final first = engine.run(inputs);
      final second = engine.run(inputs);
      expect(first.curricula.keys, second.curricula.keys);
      for (final c in first.curricula.keys) {
        expect(first[c], second[c], reason: c);
      }
      expect(first.countedEventIds, second.countedEventIds);
      expect(first.lockIgnoredEventIds, second.lockIgnoredEventIds);
      expect(first.nowUtc, inputs.nowUtc);

      expect(first.curricula.keys, [
        'bavli',
        'ended',
        engineCurriculum,
        'retired',
      ]);
      final active = first[engineCurriculum]!;
      expect(active.evaluated, isTrue);
      expect(active.mainTrackPosition, b12);

      // Inactive / ended tracks get no plan, position or streak...
      for (final c in ['retired', 'ended', 'bavli']) {
        final s = first[c]!;
        expect(s.evaluated, isFalse, reason: c);
        expect(s.mainTrackPosition, isNull, reason: c);
        expect(s.schedulableRefs, isEmpty, reason: c);
        expect(s.currentUnit, isNull, reason: c);
        expect(s.dailyTarget, isNull, reason: c);
        expect(s.streak, isNull, reason: c);
      }
      // ...but their events still count for the learnt set and siyum.
      final retired = first['retired']!;
      expect(retired.learntLeaves, {'R 1'});
      expect(retired.completedUnits.single.unit.ref, 'R');
      expect(first.countedEventIds, hasLength(3));
      // A curriculum without a corpus resolves nothing.
      expect(first['bavli']!.learntLeaves, isEmpty);
    });
  });

  group('AC-2', () {
    test('counts learnt leaves across sources and normalizes void targets', () {
      final state = engine.run(
        engineInputs(
          events: [
            // Any source, stage or date state counts.
            engineLearn(1, b11, stage: 1),
            engineLearn(2, b12, source: subTrack),
            engineLearn(3, 'Mishnah Berakhot 1:3', stage: 2),
            engineLearn(
              4,
              'Mishnah Berakhot 2:1',
              dateState: DateState.catchUp,
            ),
            engineLearn(
              5,
              'Mishnah Berakhot 2:2',
              dateState: DateState.beforeTracking,
            ),
            // Voided learn does not count; duplicate voids are idempotent.
            engineLearn(6, 'Mishnah Peah 1:1'),
            engineVoid(7, 6),
            engineVoid(8, 6),
            // A void of a void is ignored: Peah 1:2 stays learnt.
            engineLearn(9, 'Mishnah Peah 1:2'),
            engineVoid(10, 9),
            engineVoid(11, 10),
            engineLearn(12, 'Mishnah Peah 1:2', minutes: 1),
            // A void whose target is absent is harmless.
            engineVoid(13, 999),
            // A void of a learn in another curriculum (outside the corpus).
            engineLearn(14, 'Berakhot 2a', curriculumId: 'bavli'),
            engineVoid(15, 14),
          ],
        ),
      );
      final s = state[engineCurriculum]!;
      expect(s.learntLeaves, {
        b11,
        b12,
        'Mishnah Berakhot 1:3',
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
        'Mishnah Peah 1:2',
      });
      expect(state.countedEventIds, {
        for (final i in [1, 2, 3, 4, 5, 12]) engineUlid(i),
      });
      expect(state['bavli'], isNull);
    });

    test('a void chain keeps its learn voided', () {
      final s = stateOf(
        engineInputs(
          events: [
            engineLearn(1, b11),
            engineVoid(2, 1),
            engineVoid(3, 2),
            engineVoid(4, 3),
          ],
        ),
      );
      expect(s.learntLeaves, isEmpty);
    });

    test('malformed or unknown refs never become learnt', () {
      final s = stateOf(
        engineInputs(
          events: [
            engineLearn(1, 'Mishnah Nope 1:1'),
            engineLearn(2, 'Mishnah Berakhot'), // container as a leaf event
            engineLearn(
              3,
              'Mishnah Nope',
              level: 'masechta',
              dateState: DateState.beforeTracking,
            ),
            engineLearn(
              4,
              'Mishnah Berakhot',
              level: 'seder', // level mismatch
              dateState: DateState.beforeTracking,
            ),
          ],
        ),
      );
      expect(s.learntLeaves, isEmpty);
      expect(s.distinctLearnt, 0);
    });

    test('empty events and an empty corpus are well defined', () {
      final empty = stateOf(engineInputs());
      expect(empty.learntLeaves, isEmpty);
      expect(empty.completedUnits, isEmpty);
      expect(empty.mainTrackPosition, 'Mishnah Berakhot 1:1');

      final noCorpus = stateOf(
        engineInputs(
          events: [engineLearn(1, b11)],
          corpora: {
            engineCurriculum: InMemoryCorpus(engineCurriculum, const []),
          },
        ),
      );
      expect(noCorpus.learntLeaves, isEmpty);
      expect(noCorpus.schedulableRefs, isEmpty);
      expect(noCorpus.mainTrackPosition, isNull);
      expect(noCorpus.triState(zeraim), TriState.empty);
    });
  });

  group('AC-4', () {
    test('progress counts distinct in-scope leaves', () {
      final events = [
        engineLearn(1, b11, stage: 1, minutes: 1),
        engineLearn(2, b11, stage: 2, minutes: 2),
        engineLearn(3, b11, source: subTrack, minutes: 3),
        engineLearn(4, b12, dateState: DateState.beforeTracking),
      ];
      final s = stateOf(engineInputs(events: events));
      expect(s.distinctLearnt, 2);
      expect(s.learntLeaves, {b11, b12});

      // Repeats add nothing.
      final more = stateOf(
        engineInputs(
          events: [...events, engineLearn(5, b11, stage: 1, minutes: 9)],
        ),
      );
      expect(more.distinctLearnt, 2);
    });

    test('the corpus is ContentIndex ∩ curriculum_scope', () {
      final s = stateOf(
        engineInputs(
          events: [
            engineLearn(1, b11),
            engineLearn(2, 'Mishnah Peah 1:1'),
            engineLearn(3, 'Mishnah Shabbat 1:1'),
          ],
          intents: {
            engineCurriculum: engineIntent(
              scope: engineScope({
                'scope_level': 1,
                'scope_value': 'Seder Moed',
              }),
            ),
          },
        ),
      );
      // The scope excludes the otherwise-learnt Zeraim leaves.
      expect(s.learntLeaves, {'Mishnah Shabbat 1:1'});
      expect(s.distinctLearnt, 1);
      expect(s.schedulableRefs, ['Mishnah Shabbat 1:2']);
      expect(s.mainTrackRemaining, 1);
      expect(s.triState(berakhot), TriState.empty);
    });
  });

  group('AC-5', () {
    test('triState aggregates descendants', () {
      final s = stateOf(
        engineInputs(
          events: [
            engineLearn(1, 'Mishnah Berakhot 2:1'),
            engineGround(2, peah),
          ],
        ),
      );
      expect(s.triState(berakhot2), TriState.partial);
      expect(s.triState(berakhot), TriState.partial);
      expect(s.triState(zeraim), TriState.partial);
      expect(s.triState(peah), TriState.complete);
      expect(
        s.triState(const NodeEntry(level: 'mishnah', ref: 'Mishnah Peah 1:1')),
        TriState.complete,
      );
      expect(s.triState(berakhot1), TriState.empty);
      expect(s.triState(moed), TriState.empty);
      // Boundary: a node outside the corpus has no leaves and is empty.
      expect(
        s.triState(const NodeEntry(level: 'masechta', ref: 'Mishnah Nope')),
        TriState.empty,
      );
    });
  });

  group('AC-6', () {
    const b21 = 'Mishnah Berakhot 2:1';
    const peah1 = 'Mishnah Peah 1:1';

    test('derives current unit and position from main intent', () {
      final s = stateOf(
        engineInputs(
          intents: {engineCurriculum: engineIntent(trackingStartRef: b21)},
          intentHistory: [engineStartEntry(100, b21, minutes: 10)],
        ),
      );
      expect(s.currentUnit, berakhot);
      expect(s.mainTrackPosition, b21);
      expect(s.schedulableRefs.first, b21);
      expect(s.schedulableRefs.last, 'Mishnah Berakhot 1:3');
      expect(s.mainTrackRemaining, mishnayosCorpus().leaves.length);
    });

    test('the later of the latest main event and the start wins', () {
      final intents = {engineCurriculum: engineIntent(trackingStartRef: b21)};
      final history = [engineStartEntry(100, b21, minutes: 10)];

      final eventLater = stateOf(
        engineInputs(
          events: [engineLearn(1, peah1, stage: 1, minutes: 20)],
          intents: intents,
          intentHistory: history,
        ),
      );
      expect(eventLater.currentUnit, peah);
      expect(eventLater.mainTrackPosition, 'Mishnah Peah 1:2');

      final startLater = stateOf(
        engineInputs(
          events: [engineLearn(1, peah1, stage: 1, minutes: 5)],
          intents: intents,
          intentHistory: history,
        ),
      );
      expect(startLater.currentUnit, berakhot);
      expect(startLater.mainTrackPosition, b21);

      // A catch_up event anchors like a dated one; effectiveAt is used.
      final catchUp = stateOf(
        engineInputs(
          events: [
            engineLearn(
              1,
              peah1,
              stage: 1,
              dateState: DateState.catchUp,
              minutes: 30,
              originalMinutes: 5,
            ),
          ],
          intents: intents,
          intentHistory: history,
        ),
      );
      expect(catchUp.currentUnit, berakhot);
    });

    test('only a counted main dated/catch_up event moves it', () {
      final s = stateOf(
        engineInputs(
          events: [
            engineLearn(1, peah1, stage: 1, minutes: 1),
            // Sub-track and free-tick events elsewhere do not move it.
            engineLearn(2, 'Mishnah Shabbat 1:1', source: subTrack, minutes: 2),
            engineLearn(3, 'Mishnah Berakhot 1:1', minutes: 3),
            // A voided main event does not count.
            engineLearn(4, 'Mishnah Berakhot 2:1', stage: 1, minutes: 4),
            engineVoid(5, 4, minutes: 5),
            // Nor does a before_tracking event.
            engineGround(6, berakhot1, minutes: 6),
          ],
        ),
      );
      expect(s.currentUnit, peah);
      expect(s.mainTrackPosition, 'Mishnah Peah 1:2');
    });

    test('an exhausted unit falls back to the first schedulable ref', () {
      final s = stateOf(
        engineInputs(
          events: [
            engineLearn(1, peah1, stage: 1, minutes: 1),
            engineLearn(2, 'Mishnah Peah 1:2', stage: 1, minutes: 2),
          ],
        ),
      );
      expect(s.currentUnit, isNull);
      expect(s.mainTrackPosition, 'Mishnah Berakhot 1:1');
      expect(s.mainTrackRemaining, mishnayosCorpus().leaves.length - 2);
    });

    test('tied effectiveAt values resolve by event id', () {
      LearnerStateInputs inputs(int peahId, int shabbatId) => engineInputs(
        events: [
          engineLearn(peahId, peah1, stage: 1, minutes: 7),
          engineLearn(shabbatId, 'Mishnah Shabbat 1:1', stage: 1, minutes: 7),
        ],
      );
      expect(stateOf(inputs(1, 2)).currentUnit, shabbat);
      expect(stateOf(inputs(2, 1)).currentUnit, peah);
    });

    test('a start outside the corpus is not an anchor and rotates nothing', () {
      final s = stateOf(
        engineInputs(
          intents: {
            engineCurriculum: engineIntent(
              trackingStartRef: 'Mishnah Nope 1:1',
            ),
          },
        ),
      );
      expect(s.currentUnit, isNull);
      expect(s.mainTrackPosition, 'Mishnah Berakhot 1:1');
    });
  });

  test('CalendarAssignment compares by value', () {
    const node = NodeEntry(level: 'daf', ref: 'Berakhot 2');
    expect(
      const CalendarAssignment('2026-09-01', node),
      const CalendarAssignment('2026-09-01', node),
    );
    expect(
      const CalendarAssignment('2026-09-01', node),
      isNot(const CalendarAssignment('2026-09-02', node)),
    );
  });

  test('no inputs give no curricula', () {
    final state = engine.run(
      engineInputs(intents: const {}, corpora: const {}),
    );
    expect(state.curricula, isEmpty);
    expect(state.countedEventIds, isEmpty);
  });
}
