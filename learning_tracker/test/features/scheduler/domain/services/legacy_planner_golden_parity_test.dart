/// Golden parity of the planner on LearnerState against the frozen legacy
/// planner (DNI-477 AC-2; fixture: DNI-522 / G0, orchestrator ruling B7).
///
/// `test/fixtures/planner_golden/legacy_planner_golden.json` freezes what the
/// pre-cutover planner produced (captured at [_kCaptureSha]) for four
/// no-sub-track, non-calendar Mishnayos learners. This test swaps only the
/// input adapter: each scenario's frozen inputs — scoped corpus, default
/// stages, every-day study pattern, goal, tracking start and learnt set
/// `{ref, learned_on}` — become learning events and governed intent, run
/// through the real [LearnerStateEngine], and the planner
/// ([planCurriculumTasks]) lays the result out. The outputs are compared
/// with the frozen JSON:
///
/// * `projection_tasks` — the planner's new-learning tasks;
/// * `chazara_tasks` — its reviews (`reviewsDue(today)`);
/// * `daily_tasks` — both, priority-sorted as `allDailyTasksProvider`
///   composes them (no skips).
///
/// ## Two replays of the same learnt set
///
/// Three scenarios date every learnt row `today` (`mid_masechta_pace`,
/// `masechta_boundary_pace`, `deadline_mid_masechta`). The legacy planner's
/// new learning does not depend on `learned_on` within `[tracking start,
/// today]`: at the capture SHA the legacy projection filters the schedule
/// by the set of learnt refs (`completionRefs`) and dates only the
/// completions before the track anchor. The planner on LearnerState
/// anchors a day's batch at the start of the day (`mainTrackAtStartOf`),
/// so leaves learnt today count against today's batch and the list never
/// refills. So each scenario is replayed twice:
///
/// * **as dated** — exactly the frozen rows. Chazara is compared here
///   (it depends on the dates). New learning is the start-of-day batch
///   less what was learnt today: for the three scenarios above every
///   learner already learnt at least today's batch today, so none is left
///   (asserted).
/// * **layout** — the same learnt set with the rows dated `today` moved to
///   the day before (no row is moved before the tracking start). The
///   legacy output is the same frozen list; this compares the planner's
///   order, FR-12a boundary and presentation fields with it.
///
/// `chazara_due` has no row dated `today`, so its two replays are the same
/// learner.
///
/// ## Intentional divergence (AD-49), documented in DNI-477
///
/// `masechta_boundary_pace` (FR-12a transition day) and `chazara_due`
/// (including its chazara: `reviewsDue(today)` reproduces the legacy due
/// dates, stage names and "overdue by N day(s)" reasons) match the fixture
/// exactly.
///
/// `mid_masechta_pace` and `deadline_mid_masechta` diverge by design. The
/// legacy planner accrued its own self-paced schedule from the track start
/// and showed the unlearnt part of past days as
/// "Behind pace" overdue tasks on top of today's batch, deriving a deadline
/// pace from the whole scope (74 leaves / 10 study days = 8). AD-49 retires
/// that: "the planner never computes a quantity". It lays out the engine's
/// `paceRate` (3) or `dailyTarget` (AD-44: ceil(64 remaining / 10 study
/// days at the start of today) = 7) leaves from `schedulableRefs`. What
/// stays identical is the order and every presentation field: in the
/// layout replay the new list is exactly the first N leaves of the legacy
/// list, each shown as today's new learning. The divergence table
/// [_kDivergence] pins N and the reason per scenario; any other difference
/// fails. This divergence is tracked for PO/architect sign-off in bead
/// learning-tracker-fyh.231 (AC-2 / ruling B7 wording).
///
/// ## Regenerating the fixture
///
/// Never from this test: it runs post-cutover code. The fixture pins the
/// LEGACY planner; regenerate it only with the G0 version of this test
/// (commit bf9c6c14f) in a worktree at the capture SHA:
///
/// ```sh
/// git worktree add ../lt-golden ddb9eb971
/// git show bf9c6c14f:learning_tracker/test/features/scheduler/domain/services/legacy_planner_golden_parity_test.dart \
///   > ../lt-golden/learning_tracker/test/features/scheduler/domain/services/legacy_planner_golden_parity_test.dart
/// cd ../lt-golden/learning_tracker && flutter pub get &&
///   UPDATE_GOLDENS=1 flutter test test/features/scheduler/domain/services/legacy_planner_golden_parity_test.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

/// dev HEAD whose production planner the fixture pins (pre-cutover).
const _kCaptureSha = 'ddb9eb971da145ba46a4800735f7c6670d2eb6db';

const _kFixturePath = 'test/fixtures/planner_golden/legacy_planner_golden.json';

const _kCurriculum = CurriculumId.mishnayos;

/// The planner's display toggles at capture: English labels, Ashkenazi
/// transliteration (`_kPlannerLabelSetting` of the G0 test).
const _kLabelSetting = (
  useHebrewTerms: false,
  variant: TransliterationVariant.ashkenazi,
);

/// The scenarios whose new learning diverges from the legacy planner by
/// design (AD-49): the engine quantity N (the new list is the first N
/// leaves of the legacy list) and where N comes from.
const _kDivergence = <String, (int, String)>{
  'mid_masechta_pace': (3, 'paceRate 3/day; legacy added 3 "Behind pace"'),
  'deadline_mid_masechta': (
    7,
    'dailyTarget ceil(64/10); legacy derived 8/day from the 74-leaf scope '
        'and added 6 "Behind pace"',
  ),
};

/// Whether the replay moves rows dated `today` to the day before (see the
/// library doc).
enum _Replay { asDated, layout }

/// The production track-label seam (`curriculumLabelTextFromRef`, as
/// `plannedTasksForDateProvider` passes it), evaluated through a real Ref.
final _trackLabelProvider = Provider.family<String, CurriculumId>(
  (ref, curriculum) => curriculumLabelTextFromRef(ref, curriculum: curriculum),
);

// ─── Input adapter: frozen inputs → LearnerState ───────────────────────────

/// The fixture's scoped corpus as an engine corpus. The scope is exactly
/// these leaves, so no `curriculum_scopes` doc is needed.
Corpus _corpus(List<Map<String, dynamic>> rows) {
  final seder = <String, Map<String, Map<String, List<String>>>>{};
  for (final r in rows) {
    seder
        .putIfAbsent(r['level1'] as String, () => {})
        .putIfAbsent(r['level2'] as String, () => {})
        .putIfAbsent(r['level3'] as String, () => [])
        .add(r['ref'] as String);
  }
  return InMemoryCorpus(_kCurriculum.storageKey, [
    for (final MapEntry(key: s, value: masechtos) in seder.entries)
      CorpusNode(NodeEntry(level: 'seder', ref: s), [
        for (final MapEntry(key: m, value: perakim) in masechtos.entries)
          CorpusNode(NodeEntry(level: 'masechta', ref: m), [
            for (final MapEntry(key: p, value: leaves) in perakim.entries)
              CorpusNode(NodeEntry(level: 'chapter', ref: '$m $p'), [
                for (final leaf in leaves)
                  CorpusNode(NodeEntry(level: 'mishnah', ref: leaf)),
              ]),
          ]),
      ]),
  ]);
}

DateTime _noon(String civilDate) {
  final d = DateTime.parse(civilDate);
  return DateTime.utc(d.year, d.month, d.day, 12);
}

/// The scenario's learnt set as dated main-track learn events at the first
/// stage, in fixture order. Each keeps its `learned_on`; all are recorded
/// early on `today` (in fixture order), so no Shabbos lock window (AD-36)
/// ignores a row the legacy planner counted — the legacy planner had no
/// locks, and a Friday/Shabbos `learned_on` is ordinary catch-up recording.
///
/// The [_Replay.layout] replay moves rows dated `today` to the day before.
List<LearningEvent> _events(Map<String, dynamic> scenario, _Replay replay) {
  final learnt = (scenario['learnt'] as List).cast<Map<String, dynamic>>();
  final today = scenario['today'] as String;
  final recorded = _noon(today).subtract(const Duration(hours: 6));
  final dayBefore = DateTime.parse(
    today,
  ).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
  return [
    for (final (i, row) in learnt.indexed)
      LearningEvent.learn(
        id: engineUlid(i + 1),
        curriculumId: _kCurriculum.storageKey,
        ref: row['ref'] as String,
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
        learnedOn: replay == _Replay.layout && row['learned_on'] == today
            ? dayBefore
            : row['learned_on'] as String,
        stage: 1,
        recordedAt: recorded.add(Duration(seconds: i)),
        actor: parentActor,
      ),
  ];
}

/// Whether [scenario] dates any learnt row `today`.
bool _learntToday(Map<String, dynamic> scenario) => [
  for (final r in scenario['learnt'] as List) (r as Map)['learned_on'],
].contains(scenario['today']);

MainTrackIntent _intent(
  Map<String, dynamic> shared,
  Map<String, dynamic> scenario,
) {
  final c = _kCurriculum.storageKey;
  return MainTrackIntent(
    curriculumId: c,
    track: MainTrack(curriculumId: c, state: MainTrackState.active),
    program: MainTrackProgram(
      curriculumId: c,
      trackingStartDate: scenario['tracking_start_date'] as String,
    ),
    stages: [
      for (final s in (shared['stages'] as List).cast<Map<String, dynamic>>())
        MainTrackConfigDoc(
          collection: MainTrackConfigDoc.stages,
          docId: '${c}_${s['stage_order']}',
          curriculumId: c,
          fields: {
            'stage_order': s['stage_order'],
            'schedule_type': s['schedule_type'],
            'delay_days': s['delay_days'],
          },
        ),
    ],
    studyDays: [
      for (final dow in (shared['study_weekdays'] as List).cast<int>())
        MainTrackConfigDoc(
          collection: MainTrackConfigDoc.studyDays,
          docId: '${c}_$dow',
          curriculumId: c,
          fields: {'day_of_week': dow, 'day_type': 'study'},
        ),
    ],
  );
}

CurriculumGoals _goals(Map<String, dynamic> goal) {
  final c = _kCurriculum.storageKey;
  return switch (goal['type']) {
    'pace' => CurriculumGoals(
      pace: PaceGoal(
        curriculumId: c,
        paceValue: goal['pace_value'] as int,
        paceUnit: goal['pace_period'] as String,
        // A granularity at the leaf level counts leaves.
        paceGranularity: 'mishnah',
      ),
    ),
    'deadline' => CurriculumGoals(
      deadline: DeadlineGoal(
        curriculumId: c,
        targetDate: goal['target_date'] as String,
      ),
    ),
    _ => throw ArgumentError('unknown goal ${goal['type']}'),
  };
}

typedef _Plan = ({
  List<DailyTask> projection,
  List<DailyTask> chazara,
  List<DailyTask> daily,
});

_Plan _plan(
  Map<String, dynamic> shared,
  Map<String, dynamic> scenario,
  Corpus corpus,
  String trackLabel,
  _Replay replay,
) {
  final today = scenario['today'] as String;
  final trackingStart = scenario['tracking_start_date'] as String;
  if (replay == _Replay.layout &&
      _learntToday(scenario) &&
      trackingStart.compareTo(today) >= 0) {
    throw StateError('a layout replay never moves a row before tracking');
  }
  final state = const LearnerStateEngine().run(
    LearnerStateInputs(
      events: _events(scenario, replay),
      subTracks: const [],
      mainTrackIntent: {_kCurriculum.storageKey: _intent(shared, scenario)},
      goals: {
        _kCurriculum.storageKey: _goals(
          scenario['goal'] as Map<String, dynamic>,
        ),
      },
      intentHistory: const [],
      settingsHistory: c0SettingsHistory(),
      calendars: const {},
      corpora: {_kCurriculum.storageKey: corpus},
      nowUtc: _noon(today),
    ),
  );
  final tasks = planCurriculumTasks(
    curriculum: _kCurriculum,
    state: state[_kCurriculum.storageKey]!,
    corpus: corpus,
    date: today,
    presentation: CurriculumTaskPresentation(
      trackLabel: trackLabel,
      stageNames: {
        for (final s in (shared['stages'] as List).cast<Map<String, dynamic>>())
          s['stage_order'] as int: s['stage_name'] as String,
      },
      studyDay: true,
    ),
  );
  return (
    projection: tasks.learning,
    chazara: tasks.reviews,
    daily: _daily(tasks.learning, tasks.reviews),
  );
}

/// allDailyTasksProvider's composition with no skips.
List<DailyTask> _daily(List<DailyTask> learning, List<DailyTask> reviews) =>
    [...learning, ...reviews]
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));

// ─── Serialization (the G0 field map) ──────────────────────────────────────

Map<String, Object?> _taskJson(DailyTask t) => {
  'curriculum_id': t.curriculumId.storageKey,
  'ref': t.contentItemSefariaRef,
  'stage_order': t.stageOrder,
  'priority': t.priority.name,
  'is_overdue': t.isOverdue,
  'reason': t.reason,
  'stage_name': t.stageName,
  'track_label': t.trackLabel,
  'estimated_effort_minutes': t.estimatedEffortMinutes,
  'unit_display_he': t.unitDisplayHe,
  'unit_display_en': t.unitDisplayEn,
};

List<Object?> _json(List<DailyTask> tasks) =>
    jsonDecode(jsonEncode(tasks.map(_taskJson).toList())) as List<Object?>;

/// A frozen legacy new-learning task as the planner presents today's new
/// learning (AD-49 divergence: no "Behind pace" bucket).
Map<String, Object?> _asTodaysLearning(Map<String, dynamic> legacy) => {
  ...legacy,
  'priority': DailyTaskPriority.newLearning.name,
  'is_overdue': false,
  'reason': 'Due today',
};

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late Map<String, dynamic> fixture;
  late Map<String, dynamic> shared;
  late Corpus corpus;
  late String trackLabel;

  setUpAll(() async {
    final file = File(_kFixturePath);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$_kFixturePath is missing — regenerate it from SHA $_kCaptureSha '
          '(see this file\'s library doc), never from post-cutover code.',
    );
    fixture = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    shared = fixture['shared_inputs'] as Map<String, dynamic>;
    corpus = _corpus((shared['corpus'] as List).cast<Map<String, dynamic>>());
    final labels = ProviderContainer(
      overrides: [
        effectiveUseHebrewTermsProvider.overrideWithValue(
          _kLabelSetting.useHebrewTerms,
        ),
        currentTransliterationVariantProvider.overrideWithValue(
          _kLabelSetting.variant,
        ),
      ],
    );
    trackLabel = labels.read(_trackLabelProvider(_kCurriculum));
    labels.dispose();
  });

  test('the fixture is the frozen legacy capture', () {
    final header = fixture['_header'] as Map<String, dynamic>;
    expect(header['captured_at_sha'], _kCaptureSha);
    expect(header['consumer'], contains('DNI-477'));
    expect(shared['calendar_program'], isFalse);
    expect(
      (shared['track_label_by_display_setting'] as Map)['en_ashkenazi'],
      trackLabel,
    );
  });

  test('the frozen corpus is still the ContentIndex scope it names', () async {
    final raw = await File(
      'assets/content/hierarchy/${_kCurriculum.storageKey}.json',
    ).readAsString();
    final masechtos = (shared['scope_masechtos'] as List).cast<String>();
    final leaves =
        ((jsonDecode(raw) as Map<String, dynamic>)['items'] as List)
            .cast<Map<String, dynamic>>()
            .where(
              (j) => j['isLeaf'] == true && masechtos.contains(j['level2']),
            )
            .toList()
          ..sort(
            (a, b) => (a['sortOrder'] as int).compareTo(b['sortOrder'] as int),
          );
    expect(
      [for (final j in leaves) j['sefariaRef']],
      [for (final r in (shared['corpus'] as List)) (r as Map)['ref']],
    );
    expect(corpus.leaves, [for (final j in leaves) j['sefariaRef']]);
  });

  for (final scenario
      in (jsonDecode(File(_kFixturePath).readAsStringSync())
              as Map<String, dynamic>)['scenarios']
          as List) {
    final s = scenario as Map<String, dynamic>;
    final id = s['id'] as String;
    group(id, () {
      late _Plan asDated;
      late _Plan plan;
      late Map<String, dynamic> expected;

      setUpAll(() {
        asDated = _plan(shared, s, corpus, trackLabel, _Replay.asDated);
        plan = _plan(shared, s, corpus, trackLabel, _Replay.layout);
        expected = s['expected'] as Map<String, dynamic>;
      });

      test('chazara equals the frozen legacy chazara', () {
        expect(_json(asDated.chazara), expected['chazara_tasks']);
      });

      if (_learntToday(s)) {
        test('as dated: today\'s learning already covers today\'s batch, so '
            'no new learning is left (the batch never refills)', () {
          expect(asDated.projection, isEmpty);
          expect(_json(asDated.daily), _json(asDated.chazara));
        });
      } else {
        test('as dated is the layout replay', () {
          expect(_json(asDated.projection), _json(plan.projection));
          expect(_json(asDated.chazara), _json(plan.chazara));
        });
      }

      final divergence = _kDivergence[id];
      if (divergence == null) {
        test('new learning and the daily list equal the frozen fixture', () {
          expect(_json(plan.projection), expected['projection_tasks']);
          expect(
            _json(_daily(plan.projection, asDated.chazara)),
            expected['daily_tasks'],
          );
        });
      } else {
        final (quantity, why) = divergence;
        test('AD-49 divergence: the first $quantity legacy leaves, as '
            'today\'s new learning ($why)', () {
          final legacy = (expected['projection_tasks'] as List)
              .cast<Map<String, dynamic>>();
          expect(legacy.length, greaterThan(quantity));
          expect(legacy.where((t) => t['reason'] == 'Behind pace'), isNotEmpty);
          final want = [
            for (final t in legacy.take(quantity)) _asTodaysLearning(t),
          ];
          expect(_json(plan.projection), want);
          // No chazara in these scenarios: the daily list is the new
          // learning.
          expect(asDated.chazara, isEmpty);
          expect(_json(_daily(plan.projection, asDated.chazara)), want);
        });
      }

      test('stays inside the masechtos the scenario claims (FR-12a)', () {
        final masechtaOf = {
          for (final r in (shared['corpus'] as List))
            (r as Map)['ref']: r['level2'],
        };
        final claimed = {
          for (final t in expected['projection_tasks'] as List)
            masechtaOf[(t as Map)['ref']],
        };
        expect({
          for (final t in plan.projection) masechtaOf[t.contentItemSefariaRef],
        }, divergence == null ? claimed : everyElement(isIn(claimed)));
      });
    });
  }
}
