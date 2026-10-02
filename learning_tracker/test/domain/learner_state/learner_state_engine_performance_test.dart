// DNI-494 (Story 2.3) AC-7 / AD-54 perf gate: the engine benchmark sized
// on the largest corpus (Arukh HaShulchan, 25,097 ContentIndex leaves):
// 20 learners × (40,000 leaf events + 200 node events), each with two
// sub-tracks and a deadline goal. Each learner's warm recompute (the full
// FR-19 run from a warm in-memory log) must stay under kRecomputeBudget.
// The cold first run is measured and printed, not gated (AD-54).
//
// Budgets are provisional on CI hardware (ruling B12); the named-device
// run is part of the release verification sweep.
//
// Tagged `perf` (ruling B12): excluded from the blocking main lane
// (Makefile `test:`) and run by `make test-perf` in the non-blocking CI
// `perf` job, so runner speed variance never fails a merge. It also skips
// unless `CI` is set or `LT_PERF=1` (perfGateSkipReason), so a plain
// `flutter test` on a shared, loaded host never runs it; run it locally
// with `LT_PERF=1 make test-perf`.
@Tags(['perf'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../benchmark/perf_budget.dart';
import '../../helpers/learner_state/bundled_corpus.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

const _curriculum = 'arukh_hashulchan';
const _learners = 20;
const _leafEvents = 40000;
const _nodeEvents = 200;
const _warmRuns = 3;

/// 2026-10-01 12:00Z, after two years of history.
final _now = DateTime.utc(2026, 10, 1, 12);

/// History starts 2024-10-01: 730 days of events.
final _historyStart = DateTime.utc(2024, 10, 1);
const _historyDays = 730;

String _civil(DateTime d) => d.toIso8601String().substring(0, 10);

/// The distinct parents of the leaves, in ContentIndex order. In the
/// bundled Arukh HaShulchan these are its five volumes (its siman
/// containers carry no `level2`, so the adapter drops them as leafless).
List<NodeEntry> _leafParents(Corpus corpus) {
  final seen = <NodeEntry>{};
  return [
    for (final leaf in corpus.leaves)
      if (corpus.parentOf(corpus.nodeForRef(leaf)!) case final parent?
          when seen.add(parent))
        parent,
  ];
}

/// [count] leaf-level ground entries from leaf index [from].
List<NodeEntry> _leafEntries(Corpus corpus, int from, int count) => [
  for (final leaf in corpus.leaves.skip(from).take(count))
    corpus.nodeForRef(leaf)!,
];

/// One learner's complete inputs, deterministic in [learner].
LearnerStateInputs _learnerInputs(int learner, Corpus corpus) {
  final random = Random(learner);
  final leaves = corpus.leaves;
  final volumes = _leafParents(corpus);
  final events = <LearningEvent>[];
  var id = 1;
  // 40,000 leaf events: a main-track walk through the corpus with chazara
  // repeats and some sub-track-sourced learns, spread over two years.
  for (var i = 0; i < _leafEvents; i++) {
    final day = i * _historyDays ~/ _leafEvents;
    final at = _historyStart.add(Duration(days: day, hours: 9 + i % 8));
    final repeat = random.nextInt(4) == 0;
    final leaf = leaves[(repeat ? random.nextInt(i + 1) : i) % leaves.length];
    events.add(
      LearningEvent.learn(
        id: engineUlid(id++),
        curriculumId: _curriculum,
        ref: leaf,
        source: i % 10 == 0
            ? engineUlid(900000 + learner * 2)
            : LearningEvent.sourceMain,
        dateState: DateState.dated,
        learnedOn: _civil(at),
        stage: i % 10 == 0 ? null : (repeat ? 2 : 1),
        recordedAt: at,
        actor: _actor,
      ),
    );
  }
  // 200 node events: before-tracking volumes (thousands of leaves each:
  // a heavier node expansion than any real perek or siman).
  for (var i = 0; i < _nodeEvents; i++) {
    final node = volumes[i % 2 + learner % 3];
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
  SubTrack subTrack(int n, List<NodeEntry> ground, SubTrackType type) =>
      SubTrack(
        id: engineUlid(900000 + learner * 2 + n),
        curriculumId: _curriculum,
        name: 'Sub-track $n',
        type: type,
        academicYear: type == SubTrackType.schoolYear ? 2026 : null,
        windowStart: '2026-09-01',
        windowEnd: type == SubTrackType.schoolYear ? '2027-07-31' : null,
        ratePerWeek: 10.0 + n,
        weeksPerYear: 39,
        learnsOnShabbos: false,
        ground: ground,
        lastChangeId: engineUlid(1),
      );
  final start = random.nextInt(leaves.length - 600);
  return LearnerStateInputs(
    events: events,
    subTracks: [
      subTrack(0, _leafEntries(corpus, start, 300), SubTrackType.schoolYear),
      subTrack(1, [
        // A whole volume (any level), then leaf entries.
        volumes[4 - learner % 2],
        ..._leafEntries(corpus, start + 300, 100),
      ], SubTrackType.ongoing),
    ],
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

final _actor = engineLearn(0, 'x').actor;

void main() {
  test(
    'AD-54: warm FR-19 recompute < $kRecomputeBudget per learner '
    '($_learners learners × $_leafEvents leaf + $_nodeEvents node '
    'events, 2 sub-tracks; $kReferenceDevice)',
    () {
      final corpus = bundledCorpus(_curriculum);
      expect(corpus.leaves.length, greaterThan(25000));
      const engine = LearnerStateEngine();
      final warm = <Duration>[];
      for (var learner = 0; learner < _learners; learner++) {
        final inputs = _learnerInputs(learner, corpus);
        expect(inputs.events, hasLength(_leafEvents + _nodeEvents));
        final cold = Stopwatch()..start();
        final first = engine.run(inputs);
        cold.stop();
        final state = first[_curriculum]!;
        expect(state.dailyTarget, isNotNull);
        expect(state.subTracks, hasLength(2));
        expect(state.subTracks.values.every((s) => s.capacity != null), isTrue);
        var best = const Duration(days: 1);
        for (var run = 0; run < _warmRuns; run++) {
          final sw = Stopwatch()..start();
          final again = engine.run(inputs)[_curriculum]!;
          sw.stop();
          expect(again.dailyTarget, state.dailyTarget);
          if (sw.elapsed < best) best = sw.elapsed;
        }
        warm.add(best);
        // ignore: avoid_print
        print(
          'learner $learner: cold ${cold.elapsedMilliseconds} ms, '
          'warm ${best.inMilliseconds} ms, dailyTarget ${state.dailyTarget}',
        );
      }
      final worst = warm.reduce((a, b) => a > b ? a : b);
      // ignore: avoid_print
      print(
        'AD-54 worst warm recompute: ${worst.inMilliseconds} ms '
        '(budget ${kRecomputeBudget.inMilliseconds} ms, $kReferenceDevice)',
      );
      for (final (learner, d) in warm.indexed) {
        expect(
          d,
          lessThan(kRecomputeBudget),
          reason: 'learner $learner warm recompute',
        );
      }
    },
    skip: perfGateSkipReason(),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
