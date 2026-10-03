// Story 4.3 (DNI-511) AC-7 / AD-54 perf gate: My talmidim at the largest
// envelope — 20 talmidim, each with 40,000 leaf events and 200 node events —
// renders each learner's FR-29 row (engine status plus the FR-19 daily
// target) from a warm in-memory log in under kRecomputeBudget per learner.
// The cold first load is measured and printed, never gated.
//
// Fixture (deterministic, Random(511 + learner)): per learner, the bundled
// Mishnayos corpus, two years of dated / catch-up learns with repeats and
// voids, 1 in 7 from an ongoing "Rebbe" sub-track holding 300 leaves of
// ground (ticked within its first 200), 200 before-tracking node events, and a live deadline goal.
//
// Measurement per learner: the engine run plus the row projection
// (`buildTalmidRowState`) and the FR-19 `dailyTarget` read — what one
// visible row costs. Warm = best of [_warmRuns] reruns over the same
// in-memory inputs (AD-54 "the perf gate measures recompute from a warm
// in-memory log"). A second test pumps the screen over the 20 heavy learners
// and checks that only rows on screen or about to scroll on ran the engine.
//
// Tagged `perf` (ruling B12): excluded from the blocking main lane and run by
// `make test-perf` in the CI `perf` job — the Epic 4 release gate for this
// story. It also skips unless `CI` is set or `LT_PERF=1`
// (perfGateSkipReason). Budgets are provisional on CI hardware; the
// named-device run belongs to the release verification sweep.
@Tags(['perf'])
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/use_cases/build_talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_row_state_provider.dart';

import '../features/sub_tracks/talmidim_fixtures.dart';
import '../helpers/learner_state/bundled_corpus.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import 'perf_budget.dart';

const _curriculum = 'mishnayos';
const _learners = 20;
const _leafEvents = 40000;
const _nodeEvents = 200;
const _warmRuns = 3;

/// 2026-10-01 12:00Z, after two years of history.
final _now = DateTime.utc(2026, 10, 1, 12);
final _historyStart = DateTime.utc(2024, 10, 1);
const _historyDays = 730;

String _civil(DateTime d) => d.toIso8601String().substring(0, 10);

final _actor = engineLearn(0, 'x').actor;

LearnerStateInputs _inputs(Corpus corpus, int learner) {
  final random = Random(511 + learner);
  final leaves = corpus.leaves;
  final rebbe = SubTrack(
    id: engineUlid(900000 + learner),
    curriculumId: _curriculum,
    name: 'Rebbe',
    type: SubTrackType.ongoing,
    windowStart: '2025-09-01',
    ratePerWeek: 5,
    weeksPerYear: 39,
    learnsOnShabbos: false,
    ground: [
      for (final leaf in leaves.skip(2000).take(300)) corpus.nodeForRef(leaf)!,
    ],
    lastChangeId: engineUlid(1),
  );
  final events = <LearningEvent>[];
  var id = 1;
  for (var i = 0; i < _leafEvents; i++) {
    final day = i * _historyDays ~/ _leafEvents;
    final at = _historyStart.add(Duration(days: day, hours: 9 + i % 8));
    final repeat = random.nextInt(4) == 0;
    final fromRebbe = i % 7 == 0;
    final ref = fromRebbe
        // The first 200 of its 300 ground leaves: the track has a next one.
        ? rebbe.ground[random.nextInt(200)].ref
        : leaves[(repeat ? random.nextInt(i + 1) : i) % leaves.length];
    events.add(
      LearningEvent.learn(
        id: engineUlid(id++),
        curriculumId: _curriculum,
        ref: ref,
        source: fromRebbe ? rebbe.id : LearningEvent.sourceMain,
        dateState: i % 13 == 0 ? DateState.catchUp : DateState.dated,
        learnedOn: _civil(at),
        stage: fromRebbe ? null : (repeat ? 2 : 1),
        recordedAt: at,
        actor: _actor,
      ),
    );
    if (i % 100 == 50) {
      events.add(
        LearningEvent.voidOf(
          id: engineUlid(id++),
          targetId: events.last.id,
          recordedAt: at.add(const Duration(minutes: 5)),
          actor: _actor,
        ),
      );
    }
  }
  final parents = <NodeEntry>{
    for (final leaf in leaves)
      if (corpus.parentOf(corpus.nodeForRef(leaf)!) case final parent?) parent,
  }.toList();
  for (var i = 0; i < _nodeEvents; i++) {
    final node = parents[random.nextInt(parents.length)];
    events.add(
      LearningEvent.learn(
        id: engineUlid(id++),
        curriculumId: _curriculum,
        ref: node.ref,
        level: node.level,
        source: LearningEvent.sourceMain,
        dateState: DateState.beforeTracking,
        learnedOn: null,
        recordedAt: _historyStart.add(Duration(minutes: i)),
        actor: _actor,
      ),
    );
  }
  return LearnerStateInputs(
    events: events,
    subTracks: [rebbe],
    mainTrackIntent: {
      _curriculum: MainTrackIntent(
        curriculumId: _curriculum,
        track: MainTrack(
          curriculumId: _curriculum,
          state: MainTrackState.active,
        ),
        program: MainTrackProgram(
          curriculumId: _curriculum,
          trackingStartDate: _civil(_historyStart),
        ),
      ),
    },
    goals: {
      _curriculum: const CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: _curriculum,
          targetDate: '2029-03-14',
        ),
      ),
    },
    intentHistory: const [],
    settingsHistory: engineInputs().settingsHistory,
    calendars: const {},
    corpora: {_curriculum: corpus},
    nowUtc: _now,
  );
}

/// One visible row's work: the engine, the row projection and the FR-19
/// daily target.
(LearnerState, TalmidRowReady, int?) _row(LearnerStateInputs inputs) {
  final state = const LearnerStateEngine().run(inputs);
  final row = buildTalmidRowState(state);
  return (state, row, state[_curriculum]?.dailyTarget);
}

void main() {
  test(
    'AD-54: 20 talmidim × ($_leafEvents leaf + $_nodeEvents node events): '
    'warm FR-29 row + FR-19 target < ${kRecomputeBudget.inMilliseconds} ms '
    'per learner; cold first load recorded ($kReferenceDevice)',
    () {
      final corpus = bundledCorpus(_curriculum);
      var worstWarm = Duration.zero;
      var worstCold = Duration.zero;
      var totalCold = Duration.zero;
      for (var learner = 0; learner < _learners; learner++) {
        final inputs = _inputs(corpus, learner);
        expect(
          inputs.events.where((e) => e.isLearn && e.level == null).length,
          _leafEvents,
        );
        expect(
          inputs.events.where((e) => e.isLearn && e.level != null).length,
          _nodeEvents,
        );

        final cold = Stopwatch()..start();
        final (_, first, target) = _row(inputs);
        cold.stop();
        // A deadline learner with a live Rebbe track: a status chip, the
        // track's next position and a daily target.
        expect(first.status, isNotNull);
        expect(first.line, isA<TalmidTrackNext>());
        expect(target, isNotNull);

        var warm = const Duration(days: 1);
        for (var run = 0; run < _warmRuns; run++) {
          final sw = Stopwatch()..start();
          final (_, again, _) = _row(inputs);
          sw.stop();
          expect(again, first);
          if (sw.elapsed < warm) warm = sw.elapsed;
        }
        expect(
          warm,
          lessThan(kRecomputeBudget),
          reason: 'learner $learner warm FR-29 row + FR-19 target',
        );
        if (warm > worstWarm) worstWarm = warm;
        if (cold.elapsed > worstCold) worstCold = cold.elapsed;
        totalCold += cold.elapsed;
      }
      // ignore: avoid_print
      print(
        'DNI-511 AD-54 talmidim: $_learners learners; worst warm row '
        '${worstWarm.inMilliseconds} ms (budget '
        '${kRecomputeBudget.inMilliseconds} ms, gated); cold first load '
        'worst ${worstCold.inMilliseconds} ms, total '
        '${totalCold.inMilliseconds} ms (recorded, not gated); '
        '$kReferenceDevice',
      );
    },
    skip: perfGateSkipReason(),
    timeout: const Timeout(Duration(minutes: 15)),
  );

  testWidgets(
    'AD-35 tutor list: only rows on screen or about to scroll on run the '
    'engine at the 20-learner envelope',
    (tester) async {
      final corpus = bundledCorpus(_curriculum);
      final inputs = <LearnerScope, LearnerStateInputs>{
        for (var n = 1; n <= _learners; n++) talmidScope(n): _inputs(corpus, n),
      };
      final evaluated = <LearnerScope>[];
      final fake = FakeTalmidInputs();
      await pumpTalmidim(
        tester,
        repo: ScriptedTutorRosterRepository([
          [for (var n = 1; n <= _learners; n++) talmidEntry(n, name: 'T $n')],
        ]),
        inputs: fake,
        size: const Size(412, 915),
        fakeState: false,
        extra: [
          talmidLearnerStateProvider.overrideWith((ref, scope) {
            evaluated.add(scope);
            return AsyncData(const LearnerStateEngine().run(inputs[scope]!));
          }),
        ],
      );
      expect(evaluated, isNotEmpty);
      expect(evaluated.toSet().length, lessThan(_learners));
      expect(evaluated, isNot(contains(talmidScope(_learners))));
      expect(find.byKey(const Key('talmidStatusChip-grant-1')), findsOneWidget);
    },
    skip: perfGateSkipReason() != null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
