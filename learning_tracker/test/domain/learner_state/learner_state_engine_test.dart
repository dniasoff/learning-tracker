// Mirror test for `lib/domain/learner_state/learner_state_engine.dart`
// (DNI-465): AC-1, AC-2, AC-4, AC-5 and AC-6 of Story 1.3, plus the
// story's edge coverage. AC-3 is in expand_ground_test.dart and AC-7 in
// completed_units_test.dart.
//
// DNI-468 (Story 1.6) adds the points groups: AC-1 counted events, AC-2
// first-learning earning and AC-3 review earning.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/lock_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

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

  group('DNI-466 AC-4: lock-ignored events', () {
    // The fixture learner is UTC with no location, so the fail-closed
    // Shabbos lock is Fri 2026-09-04 12:00Z → Sun 2026-09-06 01:00Z
    // (engineAt(5040) → engineAt(7260)).
    const inLock = 6000;
    const b21 = 'Mishnah Berakhot 2:1';
    const b22 = 'Mishnah Berakhot 2:2';

    LearningEvent at(int id, String ref, DateTime recordedAt) =>
        LearningEvent.learn(
          id: engineUlid(id),
          curriculumId: engineCurriculum,
          ref: ref,
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
          learnedOn: '2026-09-04',
          stage: 1,
          recordedAt: recordedAt,
          actor: parentActor,
        );

    test('a locked event is excluded from every output and reported', () {
      final kept = [engineLearn(1, b11, stage: 1)];
      final locked = engineLearn(2, b12, stage: 1, minutes: inLock);
      // One corpus instance: curriculum states compare their corpus.
      final corpora = {engineCurriculum: mishnayosCorpus()};
      final withLocked = engine.run(
        engineInputs(events: [...kept, locked], corpora: corpora),
      );
      final without = engine.run(engineInputs(events: kept, corpora: corpora));

      expect(withLocked.lockIgnoredEventIds, {engineUlid(2)});
      expect(withLocked.countedEventIds, {engineUlid(1)});
      // Learnt set, progress, tri-state, position, completed units and
      // streak are exactly those of a log without the event.
      expect(withLocked[engineCurriculum], without[engineCurriculum]);
      expect(withLocked[engineCurriculum]!.learntLeaves, {b11});
      expect(without.lockIgnoredEventIds, isEmpty);
    });

    test('a locked event cannot be the completing event of a unit', () {
      // Masechta Peah is a unit of two mishnayos.
      final first = engineLearn(1, 'Mishnah Peah 1:1', stage: 1);
      LearnerState run(int minutes) => engine.run(
        engineInputs(
          events: [
            first,
            engineLearn(2, 'Mishnah Peah 1:2', stage: 1, minutes: minutes),
          ],
        ),
      );
      final completed = run(100)[engineCurriculum]!.completedUnits;
      expect(completed.map((u) => u.unit), contains(peah));

      final locked = run(inLock);
      expect(locked.lockIgnoredEventIds, {engineUlid(2)});
      final state = locked[engineCurriculum]!;
      expect(state.completedUnits.map((u) => u.unit), isNot(contains(peah)));
      expect(state.learntLeaves, {'Mishnah Peah 1:1'});
    });

    test('a locked void cancels nothing', () {
      final state = engine.run(
        engineInputs(
          events: [
            engineLearn(1, b11, stage: 1),
            engineVoid(2, 1, minutes: inLock),
          ],
        ),
      );
      expect(state.lockIgnoredEventIds, {engineUlid(2)});
      expect(state.countedEventIds, {engineUlid(1)});
      expect(state[engineCurriculum]!.learntLeaves, {b11});
    });

    test('both lock bounds are inside the lock; 1 µs outside counts', () {
      const us = Duration(microseconds: 1);
      final lockStart = DateTime.utc(2026, 9, 4, 12);
      final lockEnd = DateTime.utc(2026, 9, 6, 1);
      final state = engine.run(
        engineInputs(
          events: [
            at(1, b11, lockStart.subtract(us)),
            at(2, b12, lockStart),
            at(3, b21, lockEnd),
            at(4, b22, lockEnd.add(us)),
          ],
        ),
      );
      expect(state.lockIgnoredEventIds, {engineUlid(2), engineUlid(3)});
      expect(state.countedEventIds, {engineUlid(1), engineUlid(4)});
    });

    test('effectiveAt decides: original_recorded_at, not recorded_at', () {
      final state = engine.run(
        engineInputs(
          events: [
            // An undo copy recorded after the lock of a learn made inside it.
            engineLearn(1, b11, minutes: 8000, originalMinutes: inLock),
            // A copy recorded inside the lock of a learn made before it.
            engineLearn(2, b12, minutes: inLock, originalMinutes: 10),
          ],
        ),
      );
      expect(state.lockIgnoredEventIds, {engineUlid(1)});
      expect(state.countedEventIds, {engineUlid(2)});
    });

    test('each event is judged by the window of the settings in force', () {
      // Fri 13:00Z and Sat 20:00Z are inside the no-location fallback but
      // outside Jerusalem's computed Shabbos.
      final events = [
        at(1, b11, DateTime.utc(2026, 9, 4, 13)),
        at(2, b12, DateTime.utc(2026, 9, 5, 20)),
        at(3, b21, DateTime.utc(2026, 9, 5, 12)),
      ];
      final fallback = engine.run(engineInputs(events: events));
      expect(fallback.lockIgnoredEventIds, hasLength(3));

      final moved = engine.run(
        engineInputs(
          events: events,
          settingsHistory: movedHistory(
            lockSettings(timeZone: 'UTC'),
            DateTime.utc(2026, 9, 4),
            jerusalem,
          ),
        ),
      );
      expect(moved.lockIgnoredEventIds, {engineUlid(3)});
      expect(moved.countedEventIds, {engineUlid(1), engineUlid(2)});
    });
  });

  group('DNI-466 AC-6: per-curriculum streak', () {
    // UTC learner with no location: the Shabbos lock is Fri 09-04 12:00Z →
    // Sun 09-06 01:00Z, locked day Sat 09-05; Sunday holds locked
    // instants, so its catch-up runs to the end of Monday 09-07.
    // nowUtc is Mon 09-07 22:40Z.
    int day(int d) => (d - 1) * 1440 + 600; // 10:00Z on 2026-09-[d]
    String on(int d) => '2026-09-0$d';
    final other = InMemoryCorpus('other', const [
      CorpusNode(NodeEntry(level: 'sefer', ref: 'O'), [
        CorpusNode(NodeEntry(level: 'chapter', ref: 'O 1')),
      ]),
    ]);

    LearnerStateInputs inputs(List<LearningEvent> events) => engineInputs(
      events: events,
      intents: {
        engineCurriculum: engineIntent(),
        'other': engineIntent(curriculumId: 'other'),
      },
      corpora: {engineCurriculum: mishnayosCorpus(), 'other': other},
    );

    LearningEvent dated(int id, int d) =>
        engineLearn(id, b11, minutes: day(d), learnedOn: on(d));

    final excluded = [
      // Tue 09-01: a sub-track learn, a voided learn and a before-tracking
      // learn never make a streak day.
      engineLearn(20, b12, minutes: day(1), learnedOn: on(1), source: subTrack),
      engineLearn(21, b12, minutes: day(1), learnedOn: on(1)),
      engineVoid(22, 21, minutes: day(1) + 1),
      engineGround(23, berakhot1, minutes: day(1)),
    ];

    test('counts counted main events; a caught-up Shabbos keeps it', () {
      final state = engine.run(
        inputs([
          ...excluded,
          for (final d in [2, 3, 4]) dated(d, d),
          // Saturday 09-05 caught up on Sunday.
          engineLearn(
            5,
            b11,
            minutes: day(6),
            learnedOn: on(5),
            dateState: DateState.catchUp,
          ),
          dated(6, 6),
          dated(7, 7),
          engineLearn(
            8,
            'O 1',
            curriculumId: 'other',
            minutes: day(7),
            learnedOn: on(7),
          ),
        ]),
      );
      expect(
        state[engineCurriculum]!.streak,
        const CurriculumStreak(current: 6, best: 6, lastDay: '2026-09-07'),
      );
      // Per curriculum: the other curriculum has only its own Monday.
      expect(
        state['other']!.streak,
        const CurriculumStreak(current: 1, best: 1, lastDay: '2026-09-07'),
      );
    });

    test('a lock-ignored dated learn does not stand in for a catch-up', () {
      final state = engine.run(
        inputs([
          for (final d in [2, 3, 4]) dated(d, d),
          // Recorded on Shabbos itself (inside the lock).
          engineLearn(5, b11, minutes: day(5), learnedOn: on(5)),
          dated(6, 6),
          dated(7, 7),
        ]),
      );
      expect(state.lockIgnoredEventIds, {engineUlid(5)});
      // Saturday's catch-up window is still open on Monday night, so
      // Saturday is pending, not a streak day and not a break.
      expect(
        state[engineCurriculum]!.streak,
        const CurriculumStreak(current: 5, best: 5, lastDay: '2026-09-07'),
      );
    });

    test('an old catch-up event still finds the lock it catches up', () {
      // The Sunday catch-up is the earliest event and more than the
      // 21-day look-back before now, so only the catch-up reach brings the
      // Shabbos lock (ended Sun 01:00Z) into the run.
      final state = engine.run(
        engineInputs(
          events: [
            engineLearn(
              5,
              b11,
              minutes: day(6),
              learnedOn: on(5),
              dateState: DateState.catchUp,
            ),
            dated(6, 6),
            dated(7, 7),
            dated(8, 8),
          ],
          nowUtc: engineAt(40 * 1440),
        ),
      );
      expect(
        state[engineCurriculum]!.streak,
        const CurriculumStreak(current: 0, best: 4, lastDay: '2026-09-08'),
      );
    });

    test('an evaluated curriculum with no learning has a zero streak', () {
      final state = engine.run(inputs(const []));
      expect(
        state[engineCurriculum]!.streak,
        const CurriculumStreak(current: 0, best: 0),
      );
    });
  });

  group('DNI-468 AC-1: countedEventIds', () {
    // Inside the fixture learner's fail-closed Shabbos lock (see the
    // DNI-466 group below).
    const inLock = 6000;

    test('profile-wide learn events not voided and not lock-ignored', () {
      final state = engine.run(
        engineInputs(
          events: [
            engineLearn(1, b11, stage: 1),
            engineLearn(2, b12, stage: 1, minutes: 10),
            engineVoid(3, 2, minutes: 20),
            engineLearn(4, 'Mishnah Peah 1:1', minutes: inLock),
            engineLearn(5, 'R 1', curriculumId: 'retired'),
            engineVoid(6, 1, minutes: inLock),
          ],
        ),
      );
      // 2 is voided, 4 is lock-ignored, the lock-ignored void 6 cancels
      // nothing, and void events (3, 6) are never counted.
      expect(state.countedEventIds, {engineUlid(1), engineUlid(5)});
      expect(state.lockIgnoredEventIds, {engineUlid(4), engineUlid(6)});
    });

    test('a voided or lock-ignored event never earns', () {
      final state = engine.run(
        engineInputs(
          events: [
            engineLearn(1, b11, stage: 1),
            engineVoid(2, 1, minutes: 5),
            engineLearn(3, b12, stage: 1, minutes: inLock),
          ],
        ),
      );
      expect(state.countedEventIds, isEmpty);
      expect(state.earningEventIds, isEmpty);
    });
  });

  group('DNI-468 AC-2: first-learning earning', () {
    const nine = 9 * 60;
    const six = 18 * 60;

    Set<String> earning(List<LearningEvent> events) =>
        engine.run(engineInputs(events: events)).earningEventIds;

    test('a sub-track event at 09:00 blocks a main dated event at 18:00', () {
      expect(
        earning([
          engineLearn(1, b11, source: subTrack, minutes: nine),
          engineLearn(2, b11, stage: 1, minutes: six),
        ]),
        isEmpty,
      );
    });

    test('a before_tracking node event blocks every leaf under it', () {
      expect(
        earning([
          engineGround(1, berakhot1, minutes: nine),
          engineLearn(2, b11, stage: 1, minutes: six),
          engineLearn(3, 'Mishnah Berakhot 1:3', stage: 1, minutes: six),
          engineLearn(4, 'Mishnah Berakhot 2:1', stage: 1, minutes: six),
        ]),
        {engineUlid(4)},
      );
    });

    test('a before_tracking leaf event blocks that leaf', () {
      expect(
        earning([
          engineLearn(1, b11, dateState: DateState.beforeTracking),
          engineLearn(2, b11, stage: 1, minutes: six),
        ]),
        isEmpty,
      );
    });

    test('an eligible main first event earns and its repeats do not', () {
      expect(
        earning([
          engineLearn(1, b11, stage: 1, minutes: nine),
          engineLearn(2, b11, stage: 1, minutes: six),
          engineLearn(3, b11, source: subTrack, minutes: six + 1),
          engineLearn(4, b12, minutes: nine),
          engineLearn(5, 'Mishnah Peah 1:1', dateState: DateState.catchUp),
        ]),
        // A free tick (no stage) and a catch_up event are main events too.
        {engineUlid(1), engineUlid(4), engineUlid(5)},
      );
    });

    test('equal effective instants are ordered by event id', () {
      expect(
        earning([
          engineLearn(1, b11, stage: 1, minutes: nine),
          engineLearn(2, b11, source: subTrack, minutes: nine),
        ]),
        {engineUlid(1)},
      );
      expect(
        earning([
          engineLearn(2, b11, stage: 1, minutes: nine),
          engineLearn(1, b11, source: subTrack, minutes: nine),
        ]),
        isEmpty,
      );
    });

    test('a replacement or import is ordered by original_recorded_at', () {
      // Recorded at 18:00 as a copy of an 08:00 event: it is earlier than
      // the 09:00 sub-track tick.
      expect(
        earning([
          engineLearn(1, b11, source: subTrack, minutes: nine),
          engineLearn(2, b11, stage: 1, minutes: six, originalMinutes: 480),
        ]),
        {engineUlid(2)},
      );
      // A copy of a 10:00 event stays behind the 09:00 tick.
      expect(
        earning([
          engineLearn(1, b11, source: subTrack, minutes: nine),
          engineLearn(2, b11, stage: 1, minutes: six, originalMinutes: 600),
        ]),
        isEmpty,
      );
    });

    test('voiding the first event lets the next counted event decide', () {
      expect(
        earning([
          engineLearn(1, b11, source: subTrack, minutes: nine),
          engineVoid(2, 1, minutes: nine + 1),
          engineLearn(3, b11, stage: 1, minutes: six),
        ]),
        {engineUlid(3)},
      );
    });

    test('earning is profile-wide across curricula', () {
      final otherCorpus = InMemoryCorpus('other', const [
        CorpusNode(NodeEntry(level: 'sefer', ref: 'O'), [
          CorpusNode(NodeEntry(level: 'chapter', ref: 'O 1')),
        ]),
      ]);
      final state = engine.run(
        engineInputs(
          events: [
            engineLearn(1, b11, stage: 1),
            engineLearn(2, 'O 1', curriculumId: 'other'),
            engineLearn(3, 'Unknown 1', curriculumId: 'nocorpus'),
          ],
          corpora: {engineCurriculum: mishnayosCorpus(), 'other': otherCorpus},
        ),
      );
      // A curriculum without a corpus resolves no leaf, so nothing earns.
      expect(state.earningEventIds, {engineUlid(1), engineUlid(2)});
    });
  });

  test('no inputs give no curricula', () {
    final state = engine.run(
      engineInputs(intents: const {}, corpora: const {}),
    );
    expect(state.curricula, isEmpty);
    expect(state.countedEventIds, isEmpty);
    expect(state.earningEventIds, isEmpty);
  });
}
