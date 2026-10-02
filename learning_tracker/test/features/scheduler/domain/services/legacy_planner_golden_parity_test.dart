/// Legacy planner golden-parity fixture (DNI-522 / G0, orchestrator ruling B7).
///
/// Freezes what the pre-cutover planner produces for a small set of
/// non-calendar learners, so the learning-event cutover (DNI-477, story 1.15
/// "Planner onto LearnerState", AC-2) can prove parity: it swaps only the
/// input adapter (learnt set → learning events → LearnerState) and asserts
/// equality with the same JSON.
///
/// ## What is captured
///
/// For every scenario the fixture records three ordered task lists:
///
/// * `projection_tasks` — the output of the pure entry point
///   [buildProjectionTasks] (overdue + due-today new learning). Every
///   scenario is expected to match this list exactly after the cutover.
/// * `chazara_tasks` — the chazara/review tasks `allDailyTasksProvider`
///   keeps from [buildFreshPlan] (`overdueChazara` / `scheduledChazara`
///   priorities only). Only the `chazara_due` scenario has any; it is the one
///   scenario DNI-477 may mark as an intentional divergence, and only if the
///   `reviewsDue(today)` semantics of its AC-1 differ (documented there).
/// * `daily_tasks` — the full list exactly as `allDailyTasksProvider`
///   (`scheduler_providers.dart`) composes it from the two above on a fresh
///   day: projection + chazara, completion filter, priority sort. No skipped
///   or previously-skipped refs, no cached snapshot.
///
/// [DailyTask] is freezed without `toJson`, so tasks are serialized by the
/// explicit field-map helper [_taskJson] below.
///
/// ## Inputs survive the cutover
///
/// Inputs are expressed only in terms that exist on both sides of the
/// cutover: a non-calendar curriculum (Mishnayos) scoped to two masechtos
/// (Orlah, Bikkurim — real ContentIndex leaves and sort orders read from
/// `assets/content/hierarchy/mishnayos.json`), a learnt set of
/// `{ref, learned_on}` with real dates only (no `before_tracking` /
/// bulk-prior sentinel rows — DNI-473 changes their meaning), one goal per
/// scenario (deadline → dailyTarget, or pace → paceRate), the default stage
/// config, an explicit every-day study pattern, and a fixed `today`.
///
/// ## Regenerating
///
/// `UPDATE_GOLDENS=1 flutter test <this file>` rewrites the fixture. The
/// fixture pins the LEGACY planner: regenerate it only from code at or
/// before [_kCaptureSha]. After the cutover, never regenerate from
/// post-cutover code — instead:
///
/// ```sh
/// git worktree add ../lt-golden ddb9eb971
/// cp <this test> ../lt-golden/learning_tracker/test/features/scheduler/domain/services/
/// cd ../lt-golden/learning_tracker && flutter pub get &&
///   UPDATE_GOLDENS=1 flutter test test/features/scheduler/domain/services/legacy_planner_golden_parity_test.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/dashboard/data/repositories/firestore_study_day_reader_adapter.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

// ─── Capture metadata ───────────────────────────────────────────────────────

/// dev HEAD whose production planner this fixture pins (pre-cutover).
const _kCaptureSha = 'ddb9eb971da145ba46a4800735f7c6670d2eb6db';

const _kFixturePath = 'test/fixtures/planner_golden/legacy_planner_golden.json';

const _kFixtureVersion = 1;

const _kCurriculum = CurriculumId.mishnayos;

/// The two masechtos the fixture corpus is scoped to (ContentIndex level2).
const _kScopedMasechtos = ['Mishnah Orlah', 'Mishnah Bikkurim'];

/// Every instant the legacy planner reads (`now`, completion `completedAt`,
/// track `activatedAt`, goal `targetDate`) is placed at this UTC hour on its
/// civil date, so `LocalDayUtils.extractLocalDate` resolves the same civil
/// date on any machine whose UTC offset is within ±11h.
const _kInstantHourUtc = 12;

/// Default stage config: the three stages a newly activated curriculum is
/// seeded with (`_defaultStages` in
/// `lib/data/repositories/firestore_stage_definition_repository.dart`).
final _kDefaultStages = <({int stageOrder, String stageName, int delayDays})>[
  (stageOrder: 1, stageName: kLimudStageName, delayDays: 0),
  (stageOrder: 2, stageName: 'חזרה א׳', delayDays: 1),
  (stageOrder: 3, stageName: 'חזרה ב׳', delayDays: 7),
];

/// Explicit study-day config: every weekday (ISO 1..7) is a study day.
///
/// Explicit rather than "no config" on purpose: with no config the legacy
/// `FirestoreStudyDayReaderAdapter.countStudyDaysInInclusiveDateRange`
/// returns 0, which collapses a deadline goal to a 1-per-week fallback pace
/// and would make the deadline scenario meaningless.
final _kStudyWeekdays = <int>[1, 2, 3, 4, 5, 6, 7];

/// First stage order — learnt-set rows are first-stage (learn) completions.
const _kLearnStageOrder = 1;

// ─── Scenarios ──────────────────────────────────────────────────────────────

sealed class _Goal {
  const _Goal();
  Map<String, Object?> toJson();
  GoalEntity toEntity(DateTime createdAt);
}

final class _PaceGoal extends _Goal {
  const _PaceGoal(this.value, this.period);
  final int value;
  final String period;

  @override
  Map<String, Object?> toJson() => {
    'type': 'pace',
    'pace_value': value,
    'pace_period': period,
  };

  @override
  GoalEntity toEntity(DateTime createdAt) => GoalEntity(
    curriculumId: _kCurriculum,
    goalType: 'pace',
    paceValue: value,
    pacePeriod: period,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

final class _DeadlineGoal extends _Goal {
  const _DeadlineGoal(this.targetDate);
  final String targetDate;

  @override
  Map<String, Object?> toJson() => {
    'type': 'deadline',
    'target_date': targetDate,
  };

  @override
  GoalEntity toEntity(DateTime createdAt) => GoalEntity(
    curriculumId: _kCurriculum,
    goalType: 'deadline',
    targetDate: _instant(targetDate),
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

class _Scenario {
  const _Scenario({
    required this.id,
    required this.description,
    required this.covers,
    required this.today,
    required this.trackingStartDate,
    required this.goal,
    required this.learnt,
    required this.expectChazara,
    required this.expectedMasechtos,
  });

  final String id;
  final String description;
  final List<String> covers;
  final String today;
  final String trackingStartDate;
  final _Goal goal;

  /// `(leaf index in scoped corpus order, learned_on)` pairs. Resolved to
  /// refs against the corpus so the scenario reads in positions.
  final List<(int, String)> learnt;

  /// Sanity guards independent of the golden: does the scenario actually
  /// exercise what its id claims?
  final bool expectChazara;
  final List<String> expectedMasechtos;
}

/// Index ranges `[from, to]` inclusive, all learned on [learnedOn].
List<(int, String)> _range(int from, int to, String learnedOn) => [
  for (var i = from; i <= to; i++) (i, learnedOn),
];

const _kToday = '2026-06-15'; // a Monday

final _scenarios = <_Scenario>[
  _Scenario(
    id: 'mid_masechta_pace',
    description:
        'Pace goal 3/day, tracking since 3 days ago. The child caught up on '
        'the first 6 mishnayos today; the rest of the 2 missed days is '
        'behind pace and today\'s 3 are due — all inside Orlah.',
    covers: ['mid_masechta', 'pace_goal'],
    today: _kToday,
    trackingStartDate: '2026-06-12',
    goal: const _PaceGoal(3, 'per_day'),
    // Learnt today only: under the default stage config nothing learnt
    // today has a chazara due today, so this scenario carries no reviews.
    learnt: _range(0, 5, _kToday),
    expectChazara: false,
    expectedMasechtos: ['Mishnah Orlah'],
  ),
  _Scenario(
    id: 'masechta_boundary_pace',
    description:
        'FR-12a transition day. Pace goal 3/day, tracking since 11 days ago, '
        'all 33 scheduled mishnayos learnt. Today\'s batch finishes Orlah '
        '(3:8, 3:9) and begins Bikkurim (1:1).',
    covers: ['masechta_finish_next_begins', 'pace_goal'],
    today: _kToday,
    trackingStartDate: '2026-06-04',
    goal: const _PaceGoal(3, 'per_day'),
    learnt: _range(0, 32, _kToday),
    expectChazara: false,
    expectedMasechtos: ['Mishnah Orlah', 'Mishnah Bikkurim'],
  ),
  _Scenario(
    id: 'deadline_mid_masechta',
    description:
        'Deadline goal 2026-06-24 (10 study days incl. today) over the '
        '74-leaf scope, tracking since 2 days ago, 10 mishnayos learnt. '
        'The legacy planner derives 56/week (8 per study day) from the '
        'deadline; 6 are behind pace and today\'s 8 are due, inside Orlah.',
    covers: ['deadline_goal', 'mid_masechta'],
    today: _kToday,
    trackingStartDate: '2026-06-13',
    goal: const _DeadlineGoal('2026-06-24'),
    learnt: _range(0, 9, _kToday),
    expectChazara: false,
    expectedMasechtos: ['Mishnah Orlah'],
  ),
  _Scenario(
    id: 'chazara_due',
    description:
        'Pace goal 2/day, tracking since 5 days ago, learnt on pace '
        '(2 per day, 06-10 .. 06-14). Today\'s 2 are due; chazara A is '
        'overdue for everything learnt before yesterday and due today for '
        'yesterday\'s 2.',
    covers: ['chazara_due', 'pace_goal', 'mid_masechta'],
    today: _kToday,
    trackingStartDate: '2026-06-10',
    goal: const _PaceGoal(2, 'per_day'),
    learnt: [
      ..._range(0, 1, '2026-06-10'),
      ..._range(2, 3, '2026-06-11'),
      ..._range(4, 5, '2026-06-12'),
      ..._range(6, 7, '2026-06-13'),
      ..._range(8, 9, '2026-06-14'),
    ],
    expectChazara: true,
    expectedMasechtos: ['Mishnah Orlah'],
  ),
];

// ─── Date helpers ───────────────────────────────────────────────────────────

/// Civil date `YYYY-MM-DD` → the instant the legacy planner is fed.
DateTime _instant(String civilDate) {
  final d = DateTime.parse(civilDate);
  return DateTime.utc(d.year, d.month, d.day, _kInstantHourUtc);
}

// ─── Corpus ─────────────────────────────────────────────────────────────────

/// Scoped corpus: the ContentIndex leaves of [_kScopedMasechtos], in
/// ContentIndex sortOrder.
Future<List<ContentItem>> _loadScopedCorpus() async {
  final raw = await File(
    'assets/content/hierarchy/${_kCurriculum.storageKey}.json',
  ).readAsString();
  final items = (jsonDecode(raw) as Map<String, dynamic>)['items'] as List;
  final leaves =
      items
          .cast<Map<String, dynamic>>()
          .where(
            (j) =>
                j['isLeaf'] == true && _kScopedMasechtos.contains(j['level2']),
          )
          .map(
            (j) => ContentItem(
              curriculumId: j['curriculumId'] as String,
              level1: j['level1'] as String,
              level2: j['level2'] as String?,
              level3: j['level3'] as String?,
              level4: j['level4'] as String?,
              displayNameHe: j['displayNameHe'] as String,
              displayNameEn: j['displayNameEn'] as String,
              sefariaRef: j['sefariaRef'] as String,
              sortOrder: j['sortOrder'] as int,
              isLeaf: true,
            ),
          )
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return leaves;
}

// ─── Test doubles (in-memory, mirroring daily_task_projection_service_test) ─

class _Content implements SchedulerContentRepository {
  _Content(this.corpus);
  final List<ContentItem> corpus;

  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async => [
    if (id == _kCurriculum)
      for (final c in corpus)
        SchedulerContentItem(
          sefariaRef: c.sefariaRef,
          sortOrder: c.sortOrder,
          level1: c.level1,
          level2: c.level2,
          level3: c.level3,
          level4: c.level4,
        ),
  ];
}

class _Completions implements SchedulerCompletionRepository {
  _Completions(this.rows);
  final List<SchedulerCompletion> rows;

  @override
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId id) async =>
      id == _kCurriculum ? rows : const [];
}

class _Order implements SchedulerLearningOrderRepository {
  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId id) async => const [];
}

class _Stages implements SchedulerStageRepository {
  @override
  Future<List<SchedulerStage>> getStages(CurriculumId id) async => [
    for (final s in _kDefaultStages)
      SchedulerStage(
        stageOrder: s.stageOrder,
        stageName: s.stageName,
        delayDays: s.delayDays,
      ),
  ];
}

class _StageDefinitions implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async => [
    for (final s in _kDefaultStages)
      StageDefinition(
        curriculumId: curriculumId,
        stageOrder: s.stageOrder,
        stageName: s.stageName,
        delayDays: s.delayDays,
        isDefault: true,
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Only getStagesForCurriculum is used by the legacy planner.',
  );
}

class _Goals implements GoalRepository {
  _Goals(this.goal);
  final GoalEntity goal;

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async =>
      curriculumId == _kCurriculum ? [goal] : const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Only getGoals is used by the legacy planner.');
}

class _NoPrograms implements ProfileProgramRepository {
  @override
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Only getProgram is used by the legacy planner.',
  );
}

class _NoCalendar implements LocalCalendarEngine {
  @override
  Future<CalendarProgramEntry?> getEntry(String id, DateTime date) async =>
      null;

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String id,
    DateTime startDate,
    DateTime endDate,
  ) async => const [];

  @override
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async =>
      const [];

  @override
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) async => null;
}

/// The real study-day reader with only its config source replaced, so the
/// derived counts (`countStudyDaysInInclusiveDateRange`, `studyDaysPerWeek`)
/// run the production derivation over [_kStudyWeekdays].
class _StudyDays extends FirestoreStudyDayReaderAdapter {
  _StudyDays({required super.ref});

  @override
  Future<List<StudyDayConfigEntry>> getConfigsForCurriculum(
    CurriculumId curriculumId,
  ) async => [
    for (final day in _kStudyWeekdays)
      StudyDayConfigEntry(dayOfWeek: day, dayType: DayType.study),
  ];
}

final _studyDaysProvider = Provider<_StudyDays>((ref) => _StudyDays(ref: ref));

// ─── Legacy plan ────────────────────────────────────────────────────────────

typedef _LegacyPlan = ({
  List<DailyTask> projection,
  List<DailyTask> chazara,
  List<DailyTask> daily,
});

Future<_LegacyPlan> _runLegacyPlanner(
  _Scenario scenario,
  List<ContentItem> corpus,
  FirestoreStudyDayReaderAdapter studyDayReader,
) async {
  final now = _instant(scenario.today);
  final completionRepo = _Completions([
    for (final (index, learnedOn) in scenario.learnt)
      SchedulerCompletion(
        sefariaRef: corpus[index].sefariaRef,
        stageOrder: _kLearnStageOrder,
        trackType: 'personal',
        completedAt: _instant(learnedOn),
      ),
  ]);
  final engine = SchedulerEngine(
    contentRepository: _Content(corpus),
    completionRepository: completionRepo,
    stageRepository: _Stages(),
    learningOrderRepository: _Order(),
  );
  final trackStart = _instant(scenario.trackingStartDate);
  const activeCurricula = [_kCurriculum];
  final activeTracks = [
    CurriculumTrackEntity(
      curriculumId: _kCurriculum,
      state: 'active',
      stateChangedAt: trackStart,
      activatedAt: trackStart,
    ),
  ];
  final goals = _Goals(scenario.goal.toEntity(trackStart));
  final programs = _NoPrograms();
  final stageRepository = _StageDefinitions();
  final calendarService = CalendarProgramService(_NoCalendar());
  String trackLabelFor(CurriculumId curriculum) => curriculum.storageKey;
  Future<List<ContentItem>> getScopedContent(CurriculumId _) async => corpus;

  // ── Step 1 of allDailyTasksProvider: the pure projection. ───────────────
  final projection = await buildProjectionTasks(
    trackLabelFor: trackLabelFor,
    activeCurricula: activeCurricula,
    activeTracks: activeTracks,
    completionRepository: completionRepo,
    profileProgramRepository: programs,
    goalRepository: goals,
    studyDayReader: studyDayReader,
    stageRepository: stageRepository,
    engine: engine,
    now: now,
    calendarService: calendarService,
    getScopedContent: getScopedContent,
    programRepository: LearningProgramRepository.instance,
  );

  // ── Step 2: chazara/review tasks from the fresh plan. ───────────────────
  final freshPlan = await buildFreshPlan(
    trackLabelFor: trackLabelFor,
    activeCurricula: activeCurricula,
    activeTracks: activeTracks,
    goalRepository: goals,
    profileProgramRepository: programs,
    studyDayReader: studyDayReader,
    stageRepository: stageRepository,
    generator: DailyTaskGenerator(engine: engine),
    engine: engine,
    now: now,
    calendarService: calendarService,
    getScopedContent: getScopedContent,
    programRepository: LearningProgramRepository.instance,
  );
  final chazara = freshPlan
      .where(
        (t) =>
            t.priority == DailyTaskPriority.overdueChazara ||
            t.priority == DailyTaskPriority.scheduledChazara,
      )
      .toList();

  // ── Step 3: completion filter + priority sort, exactly as the provider.
  // No sentinel rows exist in the fixture, so the provider's sentinel
  // exemption never applies; skipped / previously-skipped sets are empty.
  final completions = await completionRepo.getCompletions(_kCurriculum);
  bool isTaskCompleted(DailyTask task) => completions.any(
    (c) =>
        c.sefariaRef == task.contentItemSefariaRef &&
        c.stageOrder == task.stageOrder,
  );
  final daily = [
    ...projection,
    ...chazara,
  ].where((t) => !isTaskCompleted(t)).toList();
  daily.sort((a, b) => a.priority.index.compareTo(b.priority.index));

  return (projection: projection, chazara: chazara, daily: daily);
}

// ─── Serialization ──────────────────────────────────────────────────────────

/// Explicit field map for [DailyTask] (freezed, no `toJson`). Every field
/// of the model is listed so a parity comparison is total.
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

Map<String, Object?> _headerJson() => {
  'fixture_version': _kFixtureVersion,
  'story': 'DNI-522 (G0) — freeze legacy planner golden-parity fixture',
  'consumer': 'DNI-477 (1.15 Planner onto LearnerState) AC-2 golden parity',
  'captured_at_sha': _kCaptureSha,
  'regenerate':
      'cd learning_tracker && UPDATE_GOLDENS=1 flutter test '
      'test/features/scheduler/domain/services/'
      'legacy_planner_golden_parity_test.dart',
  'regenerate_after_cutover':
      'legacy golden is captured at SHA $_kCaptureSha or earlier; if the '
      'fixture is missing, regenerate from that SHA (git worktree add '
      '../lt-golden ${_kCaptureSha.substring(0, 9)}, copy this test in, run '
      'with UPDATE_GOLDENS=1), never from post-cutover code.',
  'entry_points': {
    'projection_tasks':
        'buildProjectionTasks (daily_task_projection_service.dart)',
    'chazara_tasks':
        'buildFreshPlan, overdueChazara/scheduledChazara priorities only',
    'daily_tasks':
        'allDailyTasksProvider composition: projection + chazara, completion '
        'filter, priority sort; no skips, no snapshot cache',
  },
  'divergence_policy':
      'projection_tasks must match exactly in every scenario. chazara_tasks '
      'and daily_tasks must match exactly in every scenario except '
      'chazara_due, whose chazara_tasks (and hence daily_tasks) may be '
      'marked an intentional divergence only where reviewsDue(today) '
      'semantics differ; document it in DNI-477.',
  'conventions': {
    'dates':
        'Dates are civil YYYY-MM-DD. The legacy planner is fed each civil '
        'date as an instant at '
        '${_kInstantHourUtc.toString().padLeft(2, '0')}:00Z.',
    'learnt':
        'learnt rows are first-stage (learn, stage_order '
        '$_kLearnStageOrder) completions with a real learned_on date; no '
        'before_tracking / bulk-prior sentinel rows.',
    'track':
        'tracking_start_date is the track activatedAt; no reorder '
        '(lastReorderAt null), no custom learning order, no program '
        'enrollment, no sub-tracks.',
    'track_label':
        'track_label is the curriculum storage key (the test injects '
        'trackLabelFor = storageKey instead of the localized label).',
  },
};

Map<String, Object?> _sharedInputsJson(List<ContentItem> corpus) => {
  'curriculum': _kCurriculum.storageKey,
  'calendar_program': false,
  'scope_masechtos': _kScopedMasechtos,
  'corpus': [
    for (final c in corpus)
      {
        'ref': c.sefariaRef,
        'sort_order': c.sortOrder,
        'level1': c.level1,
        'level2': c.level2,
        'level3': c.level3,
        'level4': c.level4,
      },
  ],
  'stages': [
    for (final s in _kDefaultStages)
      {
        'stage_order': s.stageOrder,
        'stage_name': s.stageName,
        'schedule_type': 'delay',
        'delay_days': s.delayDays,
      },
  ],
  'study_weekdays': _kStudyWeekdays,
};

Map<String, Object?> _scenarioJson(
  _Scenario s,
  List<ContentItem> corpus,
  _LegacyPlan plan,
) => {
  'id': s.id,
  'description': s.description,
  'covers': s.covers,
  'today': s.today,
  'tracking_start_date': s.trackingStartDate,
  'goal': s.goal.toJson(),
  'learnt': [
    for (final (index, learnedOn) in s.learnt)
      {'ref': corpus[index].sefariaRef, 'learned_on': learnedOn},
  ],
  'expected': {
    'projection_tasks': plan.projection.map(_taskJson).toList(),
    'chazara_tasks': plan.chazara.map(_taskJson).toList(),
    'daily_tasks': plan.daily.map(_taskJson).toList(),
  },
};

/// Round-trip through JSON so in-memory values compare like decoded ones.
Object? _normalize(Object? value) => jsonDecode(jsonEncode(value));

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late List<ContentItem> corpus;
  late ProviderContainer container;
  late FirestoreStudyDayReaderAdapter studyDayReader;
  final plans = <String, _LegacyPlan>{};

  setUpAll(() async {
    corpus = await _loadScopedCorpus();
    container = ProviderContainer();
    studyDayReader = container.read(_studyDaysProvider);
    for (final scenario in _scenarios) {
      plans[scenario.id] = await _runLegacyPlanner(
        scenario,
        corpus,
        studyDayReader,
      );
    }
  });

  tearDownAll(() => container.dispose());

  String masechtaOf(String ref) =>
      corpus.firstWhere((c) => c.sefariaRef == ref).level2!;

  Map<String, Object?> buildDocument() => {
    '_header': _headerJson(),
    'shared_inputs': _sharedInputsJson(corpus),
    'scenarios': [
      for (final s in _scenarios) _scenarioJson(s, corpus, plans[s.id]!),
    ],
  };

  if (Platform.environment['UPDATE_GOLDENS'] == '1') {
    test('regenerates the legacy planner golden fixture', () async {
      final file = File(_kFixturePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(buildDocument())}\n',
      );
    });
    return;
  }

  group('legacy planner golden fixture', () {
    late Map<String, dynamic> fixture;

    setUpAll(() async {
      final file = File(_kFixturePath);
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '$_kFixturePath is missing — regenerate it from SHA '
            '$_kCaptureSha (see this file\'s library doc), never from '
            'post-cutover code.',
      );
      fixture = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    });

    test('header records the capture SHA and regeneration path', () {
      expect(fixture['_header'], _normalize(_headerJson()));
    });

    test('shared inputs (scoped corpus, default stages, study days) '
        'are unchanged', () {
      expect(fixture['shared_inputs'], _normalize(_sharedInputsJson(corpus)));
    });

    test('covers every scenario kind the story requires', () {
      final covered = {for (final s in _scenarios) ...s.covers};
      expect(
        covered,
        containsAll(<String>[
          'mid_masechta',
          'masechta_finish_next_begins',
          'deadline_goal',
          'pace_goal',
          'chazara_due',
        ]),
      );
      expect(
        (fixture['scenarios'] as List).map((s) => (s as Map)['id']),
        _scenarios.map((s) => s.id),
      );
    });

    for (final scenario in _scenarios) {
      group(scenario.id, () {
        test('current planner output equals the frozen fixture', () {
          final frozen = (fixture['scenarios'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((s) => s['id'] == scenario.id);
          expect(
            frozen,
            _normalize(_scenarioJson(scenario, corpus, plans[scenario.id]!)),
          );
        });

        test('exercises what its id claims', () {
          final plan = plans[scenario.id]!;
          final newLearning = plan.projection;
          expect(newLearning, isNotEmpty);
          expect(
            newLearning.map((t) => masechtaOf(t.contentItemSefariaRef)).toSet(),
            scenario.expectedMasechtos.toSet(),
          );
          expect(plan.chazara.isNotEmpty, scenario.expectChazara);
          if (!scenario.expectChazara) {
            // No review due: the composed list is the projection, sorted.
            expect(
              plan.daily.map(_taskJson).toList(),
              plan.projection.map(_taskJson).toList(),
            );
          }
        });
      });
    }

    test('chazara_due has both overdue and due-today chazara', () {
      final chazara = plans['chazara_due']!.chazara;
      expect(chazara.map((t) => t.priority).toSet(), {
        DailyTaskPriority.overdueChazara,
        DailyTaskPriority.scheduledChazara,
      });
    });

    test('the boundary day finishes Orlah and begins Bikkurim', () {
      final today = plans['masechta_boundary_pace']!.projection
          .where((t) => !t.isOverdue)
          .map((t) => t.contentItemSefariaRef)
          .toList();
      expect(today, [
        'Mishnah Orlah 3:8',
        'Mishnah Orlah 3:9',
        'Mishnah Bikkurim 1:1',
      ]);
    });
  });
}
