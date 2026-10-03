// DNI-504 T8 (AC-2 / AC-3, NFR-5): after a planned-row capture on erev,
// the warm recompute of today's list and every planned section (the
// engine over the new event log, then the shared planner laid out in
// sequence over today and the locked days) stays under kRecomputeBudget.
//
// Fixture (deterministic): one learner with 4 active bundled ContentIndex
// curricula (mishnayos, mishneh_torah, mishna_berurah, chumash), 6,000
// dated main learns each (24,000 events over two years, a quarter of
// them chazara repeats at stage 2), deadline goals on two curricula and
// pace on the others, and the maximum lock chain: a diaspora two-day yom
// tov followed by Shabbos, so today plus three locked days are planned.
//
// Measurement: the capture appends one event (the next mishnayos leaf);
// best of [_warmRuns] warm runs of engine + planner. The small-state
// recompute is also asserted in the blocking lane by
// erev_planned_tasks_provider_test.dart.
//
// Tagged `perf` (ruling B12): runs only in CI or with LT_PERF=1.
@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

import '../../../benchmark/perf_budget.dart';
import '../../../helpers/learner_state/bundled_corpus.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/lock_fixtures.dart';

const _curricula = [
  CurriculumId.mishnayos,
  CurriculumId.mishnehTorah,
  CurriculumId.mishnaBerurah,
  CurriculumId.chumash,
];

const _learnsEach = 6000;
const _warmRuns = 5;

/// Wednesday 2027-04-21 16:00Z: erev of Pesach 2027 (Lakewood diaspora:
/// yom tov Thursday and Friday, then Shabbos).
final _now = DateTime.utc(2027, 4, 21, 16);
const _dates = ['2027-04-21', '2027-04-22', '2027-04-23', '2027-04-24'];
final _historyStart = DateTime.utc(2025, 4, 21);
const _historyDays = 730;

String _civil(DateTime d) => d.toIso8601String().substring(0, 10);

final _actor = engineLearn(0, 'x').actor;

final _tracks = [
  for (final c in _curricula)
    CurriculumTrackEntity(
      curriculumId: c,
      state: 'active',
      activatedAt: DateTime.utc(2025),
    ),
];

LearnerStateInputs _inputs(
  Map<String, Corpus> corpora,
  List<LearningEvent> events,
) => LearnerStateInputs(
  events: events,
  subTracks: const [],
  mainTrackIntent: {
    for (final c in _curricula)
      c.storageKey: MainTrackIntent(
        curriculumId: c.storageKey,
        track: MainTrack(
          curriculumId: c.storageKey,
          state: MainTrackState.active,
        ),
        program: MainTrackProgram(
          curriculumId: c.storageKey,
          trackingStartDate: _civil(_historyStart),
        ),
      ),
  },
  goals: {
    for (final c in _curricula.take(2))
      c.storageKey: CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: c.storageKey,
          targetDate: '2029-03-14',
        ),
      ),
  },
  intentHistory: const [],
  settingsHistory: constantHistory(lakewood),
  calendars: const {},
  corpora: corpora,
  nowUtc: _now,
);

List<LearningEvent> _history(Map<String, Corpus> corpora) {
  final events = <LearningEvent>[];
  var id = 1;
  for (final c in _curricula) {
    final leaves = corpora[c.storageKey]!.leaves;
    for (var i = 0; i < _learnsEach; i++) {
      final at = _historyStart.add(
        Duration(days: i * _historyDays ~/ _learnsEach, hours: 9 + i % 8),
      );
      final repeat = i % 4 == 3;
      events.add(
        LearningEvent.learn(
          id: engineUlid(id++),
          curriculumId: c.storageKey,
          ref: leaves[(repeat ? i ~/ 2 : i) % leaves.length],
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
          learnedOn: _civil(at),
          stage: repeat ? 2 : 1,
          recordedAt: at,
          actor: _actor,
        ),
      );
    }
  }
  return events;
}

Future<List<List<DailyTask>>> _plan(
  LearnerState state,
  Map<String, Corpus> corpora,
) => buildPlannedSequence(
  state: state,
  corpora: corpora,
  dates: _dates,
  activeCurricula: _curricula,
  activeTracks: _tracks,
  presentationFor: (c, _) async => CurriculumTaskPresentation(
    trackLabel: c.storageKey,
    stageNames: const {1: 'Learn', 2: 'Chazara'},
    studyDay: true,
  ),
);

void main() {
  test('a planned capture recomputes today and three locked days within '
      'budget', () async {
    final corpora = {
      for (final c in _curricula) c.storageKey: bundledCorpus(c.storageKey),
    };
    final history = _history(corpora);
    const engine = LearnerStateEngine();

    // Warm: the state and plan the erev view shows before the tick.
    final before = engine.run(_inputs(corpora, history));
    final shown = await _plan(before, corpora);
    final ticked = shown
        .expand((tasks) => tasks)
        .firstWhere(
          (t) =>
              t.curriculumId == CurriculumId.mishnayos &&
              t.priority == DailyTaskPriority.newLearning,
        );
    final capture = LearningEvent.learn(
      id: engineUlid(999999),
      curriculumId: ticked.curriculumId.storageKey,
      ref: ticked.contentItemSefariaRef,
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      learnedOn: _dates.first,
      // The planned row's stage, as the erev tick writes it.
      stage: ticked.stageOrder,
      recordedAt: _now,
      actor: _actor,
    );
    final after = [...history, capture];

    var best = const Duration(days: 1);
    late List<List<DailyTask>> lists;
    for (var run = 0; run < _warmRuns; run++) {
      final sw = Stopwatch()..start();
      final state = engine.run(_inputs(corpora, after));
      lists = await _plan(state, corpora);
      sw.stop();
      if (sw.elapsed < best) best = sw.elapsed;
    }

    // The captured leaf is in no section, and no leaf is in two.
    final keys = [for (final l in lists) ...l.map(plannedTaskKey)];
    expect(keys.toSet(), hasLength(keys.length));
    expect([
      for (final l in lists)
        for (final t in l)
          if (t.curriculumId == CurriculumId.mishnayos && t.stageOrder == 1)
            t.contentItemSefariaRef,
    ], isNot(contains(ticked.contentItemSefariaRef)));
    // ignore: avoid_print — the recorded measurement (T8).
    print(
      'erev recompute (engine + planner, 4 dates, '
      '${after.length} events): best ${best.inMilliseconds} ms of '
      '$_warmRuns on $kReferenceDevice',
    );
    expect(best, lessThan(kRecomputeBudget));
  }, skip: perfGateSkipReason());
}
