// DNI-516 (Story 5.1) AC-10 / AR-11 / NFR-5: the full `LearnerState`,
// report projection included, of one representative learner stays under
// kRecomputeBudget, and the report stage adds at most
// kProjectionDeltaBudget over the engine baseline.
//
// Fixture (deterministic, Random(516)): one learner with 40,000 leaf
// events and 200 before-tracking node events over 6 bundled ContentIndex
// curricula (one of them retired), plus voids of some learns, chazara
// repeats, and 15 sub-tracks: 8 "School" school years (7 ended) sharing
// one roll-up group, and 7 more, one deleted.
//
// Measurement: the warm engine run (best of [_warmRuns]) is the total;
// the report stage (`deriveReportProjection` for every curriculum, from
// the engine's own counted events and learnt sets) is timed on its own as
// the projection delta; baseline = total − delta. Budgets are provisional
// on CI hardware (ruling B12, test/benchmark/perf_budget.dart); the
// named-device run is part of the release verification sweep.
//
// Tagged `perf` (ruling B12): excluded from the blocking main lane and run
// by `make test-perf` in the non-blocking CI `perf` job.
@Tags(['perf'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/projection.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../benchmark/perf_budget.dart';
import '../../helpers/learner_state/bundled_corpus.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

const _curricula = [
  'arukh_hashulchan',
  'mishna_berurah',
  'mishneh_torah',
  'shulchan_arukh',
  'mishnayos',
  'chumash',
];

/// The curriculum whose track is retired: counted for lifetime, not
/// evaluated.
const _retired = 'chumash';

const _leafEvents = 40000;
const _nodeEvents = 200;
const _warmRuns = 5;

/// 2026-10-01 12:00Z, after two years of history.
final _now = DateTime.utc(2026, 10, 1, 12);
final _historyStart = DateTime.utc(2024, 10, 1);
const _historyDays = 730;

String _civil(DateTime d) => d.toIso8601String().substring(0, 10);

final _actor = engineLearn(0, 'x').actor;

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

List<NodeEntry> _leafEntries(Corpus corpus, int from, int count) => [
  for (final leaf in corpus.leaves.skip(from).take(count))
    corpus.nodeForRef(leaf)!,
];

/// The 15 sub-tracks: 8 "School" years on mishnayos (2019–2026, all but
/// the last ended), and 7 more across the other curricula.
List<SubTrack> _subTracks(Map<String, Corpus> corpora) {
  var n = 900000;
  SubTrack track(
    String curriculum,
    String name, {
    int? year,
    String windowStart = '2025-09-01',
    String? windowEnd,
    DateTime? endedAt,
    SubTrackEndReason? endReason,
    int from = 0,
  }) => SubTrack(
    id: engineUlid(n++),
    curriculumId: curriculum,
    name: name,
    type: year == null ? SubTrackType.ongoing : SubTrackType.schoolYear,
    academicYear: year,
    windowStart: year == null ? windowStart : '$year-09-01',
    windowEnd: year == null ? windowEnd : '${year + 1}-06-30',
    ratePerWeek: 10,
    weeksPerYear: 39,
    learnsOnShabbos: false,
    ground: _leafEntries(corpora[curriculum]!, from, 200),
    lastChangeId: engineUlid(1),
    endedAt: endedAt,
    endReason: endReason,
  );
  return [
    for (var year = 2019; year <= 2026; year++)
      track(
        'mishnayos',
        // Same group after trimming and case-folding.
        year.isEven ? 'School' : 'school ',
        year: year,
        endedAt: year < 2026 ? DateTime.utc(year + 1, 7) : null,
        endReason: year < 2026 ? SubTrackEndReason.ended : null,
        from: (year - 2019) * 200,
      ),
    track('mishnayos', 'Rebbe', from: 2000),
    track('chumash', 'Parsha'),
    track(
      'chumash',
      'Camp',
      windowStart: '2025-07-01',
      windowEnd: '2025-08-31',
      endedAt: DateTime.utc(2025, 9),
      endReason: SubTrackEndReason.ended,
    ),
    track('arukh_hashulchan', 'Chabura', from: 1000),
    track(
      'mishna_berurah',
      'Daf group',
      endedAt: DateTime.utc(2026, 3),
      endReason: SubTrackEndReason.deleted,
    ),
    track('mishneh_torah', 'Rambam', from: 500),
    track('shulchan_arukh', 'Halacha', from: 300),
  ];
}

LearnerStateInputs _inputs(Map<String, Corpus> corpora) {
  final random = Random(516);
  final subTracks = _subTracks(corpora);
  final events = <LearningEvent>[];
  var id = 1;
  for (final (c, curriculum) in _curricula.indexed) {
    final leaves = corpora[curriculum]!.leaves;
    final sources = [
      for (final s in subTracks)
        if (s.curriculumId == curriculum) s.id,
    ];
    final count = _leafEvents ~/ _curricula.length + (c == 0 ? 4 : 0);
    for (var i = 0; i < count; i++) {
      final day = i * _historyDays ~/ count;
      final at = _historyStart.add(Duration(days: day, hours: 9 + i % 8));
      final repeat = random.nextInt(4) == 0;
      final leaf = leaves[(repeat ? random.nextInt(i + 1) : i) % leaves.length];
      final fromSub = sources.isNotEmpty && i % 7 == 0;
      events.add(
        LearningEvent.learn(
          id: engineUlid(id++),
          curriculumId: curriculum,
          ref: leaf,
          source: fromSub
              ? sources[random.nextInt(sources.length)]
              : LearningEvent.sourceMain,
          dateState: i % 13 == 0 ? DateState.catchUp : DateState.dated,
          learnedOn: _civil(at),
          stage: fromSub ? null : (repeat ? 2 : 1),
          recordedAt: at,
          actor: _actor,
        ),
      );
      // Void one learn in 100.
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
  }
  expect(
    events.where((e) => e.isLearn).length,
    _leafEvents,
    reason: 'leaf event count',
  );
  // 200 before-tracking node events over the leaf parents.
  final parentsOf = {for (final c in _curricula) c: _leafParents(corpora[c]!)};
  for (var i = 0; i < _nodeEvents; i++) {
    final curriculum = _curricula[i % _curricula.length];
    final parents = parentsOf[curriculum]!;
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
        actor: _actor,
      ),
    );
  }
  return LearnerStateInputs(
    events: events,
    subTracks: subTracks,
    mainTrackIntent: {
      for (final c in _curricula)
        c: MainTrackIntent(
          curriculumId: c,
          track: MainTrack(
            curriculumId: c,
            state: c == _retired
                ? MainTrackState.retired
                : MainTrackState.active,
          ),
          program: MainTrackProgram(
            curriculumId: c,
            trackingStartDate: _civil(_historyStart),
          ),
        ),
    },
    goals: {
      for (final c in _curricula.take(3))
        c: CurriculumGoals(
          deadline: DeadlineGoal(curriculumId: c, targetDate: '2029-03-14'),
        ),
    },
    intentHistory: const [],
    settingsHistory: engineInputs().settingsHistory,
    calendars: const {},
    corpora: corpora,
    nowUtc: _now,
  );
}

/// The report stage alone, for every curriculum, from the engine's own
/// outputs (counted events, learnt sets) and the AD-35 velocity inputs it
/// shares with the projection (computed outside the timing, as in the
/// engine).
Duration _reportStage(
  LearnerStateInputs inputs,
  LearnerState state, {
  required void Function(Map<String, ReportProjection>) check,
}) {
  final counted = countEvents(
    inputs.events,
    isLockIgnored: (e) => state.lockIgnoredEventIds.contains(e.id),
  );
  final learnsBy = <String, List<LearningEvent>>{};
  for (final e in counted.learns) {
    (learnsBy[e.curriculumId!] ??= []).add(e);
  }
  final today = civilDate(inputs.nowUtc, inputs.settingsHistory);
  final stage = <String, ReportVelocityBasis?>{};
  final scopes = <String, Set<LeafRef>>{};
  for (final c in _curricula) {
    final corpus = inputs.corpora[c]!;
    final learns = learnsBy[c] ?? const [];
    final scope = scopes[c] = corpus.leaves.toSet();
    stage[c] = state[c]!.evaluated
        ? ReportVelocityBasis(
            newlyLearnt: newlyLearntOn(
              countedLearns: learns,
              corpus: corpus,
              inScope: scope.contains,
              firstStage: 1,
            ),
            trackingStart: _civil(_historyStart),
            today: today,
            firstStage: 1,
            projection: state[c]!.projection,
          )
        : null;
  }
  final sw = Stopwatch()..start();
  final reports = {
    for (final c in _curricula)
      c: deriveReportProjection(
        curriculumId: c,
        countedLearns: learnsBy[c] ?? const [],
        corpus: inputs.corpora[c]!,
        inScope: scopes[c]!.contains,
        learntLeaves: state[c]!.learntLeaves,
        subTracks: [
          for (final s in inputs.subTracks)
            if (s.curriculumId == c) s,
        ],
        civilDayOf: (t) => civilDate(t, inputs.settingsHistory),
        velocity: stage[c],
      ),
  };
  sw.stop();
  check(reports);
  return sw.elapsed;
}

void main() {
  test('AR-11/NFR-5: full LearnerState with the report projection < '
      '${kRecomputeBudget.inMilliseconds} ms; report stage ≤ '
      '${kProjectionDeltaBudget.inMilliseconds} ms ($_leafEvents leaf + '
      '$_nodeEvents node events, ${_curricula.length} curricula, 15 '
      'sub-tracks; $kReferenceDevice)', () {
    final corpora = {for (final c in _curricula) c: bundledCorpus(c)};
    final inputs = _inputs(corpora);
    expect(inputs.subTracks, hasLength(15));
    expect(
      inputs.subTracks.where((s) => reportGroupKey(s.name) == 'school'),
      hasLength(8),
    );
    expect(
      inputs.events.where((e) => e.isLearn && e.level != null),
      hasLength(_nodeEvents),
    );
    const engine = LearnerStateEngine();

    final cold = Stopwatch()..start();
    final state = engine.run(inputs);
    cold.stop();
    final school = state['mishnayos']!.report.groups.firstWhere(
      (g) => g.key == 'school',
    );
    expect(school.members, hasLength(8));
    expect(state[_retired]!.report.allSources, isNull);
    for (final c in _curricula) {
      expect(state[c]!.report.distinctLearnt, state[c]!.distinctLearnt);
    }

    var total = const Duration(days: 1);
    for (var run = 0; run < _warmRuns; run++) {
      final sw = Stopwatch()..start();
      final again = engine.run(inputs);
      sw.stop();
      expect(again['mishnayos']!.report, state['mishnayos']!.report);
      if (sw.elapsed < total) total = sw.elapsed;
    }

    var delta = const Duration(days: 1);
    for (var run = 0; run < _warmRuns; run++) {
      final d = _reportStage(
        inputs,
        state,
        check: (reports) {
          for (final c in _curricula) {
            expect(reports[c], state[c]!.report, reason: c);
          }
        },
      );
      if (d < delta) delta = d;
    }
    final baseline = total - delta;
    // ignore: avoid_print
    print(
      'DNI-516 AR-11: cold ${cold.elapsedMilliseconds} ms, warm total '
      '${total.inMilliseconds} ms (budget ${kRecomputeBudget.inMilliseconds} '
      'ms), baseline ${baseline.inMilliseconds} ms, report stage '
      '${delta.inMilliseconds} ms (budget '
      '${kProjectionDeltaBudget.inMilliseconds} ms); $kReferenceDevice',
    );
    expect(total, lessThan(kRecomputeBudget), reason: 'warm total');
    expect(
      delta,
      lessThanOrEqualTo(kProjectionDeltaBudget),
      reason: 'report projection delta',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
