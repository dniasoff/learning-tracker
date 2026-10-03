// DNI-490 (Story 1.28) AC-5 / AD-54 perf gate for the cutover release.
//
// Workload: 20 learners × (40,000 leaf events + 200 node events) on the
// largest bundled ContentIndex corpus (picked by leaf count, not assumed),
// in the cutover shape (Epic 1 ships no sub-tracks): one active main track
// with a deadline goal, main-source learns with chazara repeats and voids
// over two years, and 200 before-tracking node events.
//
// Gate: for every learner, the warm engine recompute (the full FR-19 run
// from a warm in-memory log) plus reading its `dailyTarget` stays under
// kRecomputeBudget (one second). The cold first load (decoding the stored
// log through the AD-52 codec, then the first engine run) is measured and
// written to the run record (build/perf/learner_state_engine_benchmark.json),
// never gated (AD-54 "Read cost").
//
// Budgets are provisional on CI hardware (ruling B12,
// test/benchmark/perf_budget.dart); the named reference-device run is a
// release precondition (docs/planning/releases/1.28-cutover-release-
// checklist.md, P9).
//
// Tagged `perf`: excluded from the blocking main lane (Makefile `test:`),
// run by `make test-perf` in the non-blocking CI `perf` job and, as a
// blocking release gate, by deploy-play-store.yml's `perf-gate` job. It
// skips unless `CI` is set or `LT_PERF=1` (perfGateSkipReason).
@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../helpers/learner_state/bundled_corpus.dart';
import '../helpers/learner_state/c0_fixtures.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state_fixtures.dart';
import 'engine_benchmark_record.dart';
import 'perf_budget.dart';

const _learners = 20;
const _leafEvents = 40000;
const _nodeEvents = 200;
const _warmRuns = 3;

/// Where the run record is written (relative to learning_tracker/).
const _recordPath = 'build/perf/learner_state_engine_benchmark.json';

/// 2026-10-01 12:00Z, after two years of history.
final _now = DateTime.utc(2026, 10, 1, 12);
final _historyStart = DateTime.utc(2024, 10, 1);
const _historyDays = 730;

String _civil(DateTime d) => d.toIso8601String().substring(0, 10);

/// Every bundled ContentIndex curriculum.
List<String> _bundledCurricula() => [
  for (final f in Directory('assets/content/hierarchy').listSync())
    if (f is File && f.path.endsWith('.json'))
      f.uri.pathSegments.last.replaceAll('.json', ''),
]..sort();

/// The distinct parents of [corpus]'s leaves, in ContentIndex order.
List<NodeEntry> _leafParents(Corpus corpus) {
  final seen = <NodeEntry>{};
  return [
    for (final leaf in corpus.leaves)
      if (corpus.parentOf(corpus.nodeForRef(leaf)!) case final parent?
          when seen.add(parent))
        parent,
  ];
}

/// One learner's events, deterministic in [learner].
List<LearningEvent> _events(int learner, Corpus corpus) {
  final random = Random(490 + learner);
  final leaves = corpus.leaves;
  final parents = _leafParents(corpus);
  final curriculum = corpus.curriculumId;
  final events = <LearningEvent>[];
  var id = 1;
  var learns = 0;
  for (var i = 0; learns < _leafEvents; i++) {
    final day = learns * _historyDays ~/ _leafEvents;
    final at = _historyStart.add(Duration(days: day, hours: 9 + i % 8));
    final repeat = random.nextInt(4) == 0;
    final leaf = leaves[(repeat ? random.nextInt(i + 1) : i) % leaves.length];
    events.add(
      LearningEvent.learn(
        id: engineUlid(id++),
        curriculumId: curriculum,
        ref: leaf,
        source: LearningEvent.sourceMain,
        dateState: i % 13 == 0 ? DateState.catchUp : DateState.dated,
        learnedOn: _civil(at),
        stage: repeat ? 2 : 1,
        recordedAt: at,
        actor: parentActor,
      ),
    );
    learns++;
    // Void one learn in 100 (a correction), as the cutover's capture and
    // correction paths write them.
    if (i % 100 == 50) {
      events.add(
        LearningEvent.voidOf(
          id: engineUlid(id++),
          targetId: events.last.id,
          recordedAt: at.add(const Duration(minutes: 5)),
          actor: parentActor,
        ),
      );
    }
  }
  for (var i = 0; i < _nodeEvents; i++) {
    final node = parents[random.nextInt(parents.length)];
    events.add(
      LearningEvent.learn(
        id: engineUlid(id++),
        curriculumId: curriculum,
        ref: node.ref,
        level: node.level,
        source: LearningEvent.sourceMain,
        dateState: DateState.beforeTracking,
        learnedOn: null,
        recordedAt: _historyStart.add(Duration(minutes: i)),
        actor: parentActor,
      ),
    );
  }
  return events;
}

LearnerStateInputs _inputs(List<LearningEvent> events, Corpus corpus) {
  final c = corpus.curriculumId;
  return LearnerStateInputs(
    events: events,
    subTracks: const [],
    mainTrackIntent: {
      c: MainTrackIntent(
        curriculumId: c,
        track: MainTrack(curriculumId: c, state: MainTrackState.active),
        program: MainTrackProgram(
          curriculumId: c,
          trackingStartDate: _civil(_historyStart),
        ),
      ),
    },
    goals: {
      c: CurriculumGoals(
        deadline: DeadlineGoal(curriculumId: c, targetDate: '2029-03-14'),
      ),
    },
    intentHistory: const [],
    settingsHistory: c0SettingsHistory(),
    calendars: const {},
    corpora: {c: corpus},
    nowUtc: _now,
  );
}

void main() {
  test(
    'AD-54 cutover gate: warm recompute + dailyTarget < '
    '${kRecomputeBudget.inMilliseconds} ms per learner ($_learners learners '
    '× $_leafEvents leaf + $_nodeEvents node events, largest corpus; '
    '$kReferenceDevice); cold first load recorded, not gated',
    () {
      // The largest corpus, by ContentIndex leaf count.
      final corpora = [for (final c in _bundledCurricula()) bundledCorpus(c)]
        ..sort((a, b) => b.leaves.length.compareTo(a.leaves.length));
      final corpus = corpora.first;
      expect(corpus.leaves.length, greaterThan(20000));
      final curriculum = corpus.curriculumId;
      const engine = LearnerStateEngine();

      final timings = <LearnerTiming>[];
      for (var learner = 0; learner < _learners; learner++) {
        final events = _events(learner, corpus);
        expect(
          events.where((e) => e.isLearn && e.level == null),
          hasLength(_leafEvents),
        );
        expect(
          events.where((e) => e.isLearn && e.level != null),
          hasLength(_nodeEvents),
        );
        // The stored log, as Firestore holds it (encoded outside timing).
        final stored = [for (final e in events) (e.id, e.toStorage())];

        // Cold first load: decode the stored log, then the first run.
        final cold = Stopwatch()..start();
        final decoded = [
          for (final (id, map) in stored) LearningEvent.fromStorage(id, map),
        ];
        final first = engine.run(_inputs(decoded, corpus))[curriculum]!;
        final target = first.dailyTarget;
        cold.stop();
        expect(target, isNotNull, reason: 'a deadline goal has a target');

        // Warm: recompute from the in-memory log, best of [_warmRuns].
        final inputs = _inputs(decoded, corpus);
        var warm = const Duration(days: 1);
        for (var run = 0; run < _warmRuns; run++) {
          final sw = Stopwatch()..start();
          final again = engine.run(inputs)[curriculum]!.dailyTarget;
          sw.stop();
          expect(again, target);
          if (sw.elapsed < warm) warm = sw.elapsed;
        }
        timings.add(
          LearnerTiming(
            learner: learner,
            warm: warm,
            cold: cold.elapsed,
            dailyTarget: target,
          ),
        );
      }

      final record = EngineBenchmarkRecord(
        corpus: curriculum,
        corpusLeaves: corpus.leaves.length,
        leafEvents: _leafEvents,
        nodeEvents: _nodeEvents,
        device: kReferenceDevice,
        budget: kRecomputeBudget,
        timings: timings,
      );
      File(_recordPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(record.toJson()),
        );
      // ignore: avoid_print
      print(
        'DNI-490 AD-54: $curriculum (${corpus.leaves.length} leaves), '
        'worst warm ${record.worstWarm.inMilliseconds} ms (budget '
        '${kRecomputeBudget.inMilliseconds} ms), worst cold '
        '${record.worstCold.inMilliseconds} ms (recorded, not gated); '
        '$kReferenceDevice; record: $_recordPath',
      );
      expect(record.gateFailures(), isEmpty);
    },
    skip: perfGateSkipReason(),
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
