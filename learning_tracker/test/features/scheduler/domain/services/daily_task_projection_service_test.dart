/// Domain-layer unit tests for `daily_task_projection_service.dart`
/// (AUD-scheduler-12).
///
/// Drives [buildProjectionTasks] DIRECTLY against an in-memory `UserDatabase`
/// and plain constructor-injected collaborators — no `ProviderContainer`, no
/// Riverpod at all. The one Riverpod dependency the provider-layer version
/// used to carry (`curriculumLabelTextFromRef`) is a plain
/// `String Function(CurriculumId) trackLabelFor` closure here, proving the
/// function no longer needs a `Ref`.
///
/// Branches covered:
///   PT1. Amnesty-cutoff (self-paced path): a reorder stamped mid-day on
///        day D amnesties overdue items scheduled strictly before D's
///        device-local midnight; items scheduled on/after D survive.
///   PT2. Program-vs-self-paced branching: ONE `buildProjectionTasks` call
///        across two active curricula — one enrolled in a calendar program
///        (program path: `todayProgram`/`overdueProgram` priorities, "Program
///        …" reasons) and one with no enrollment (self-paced path:
///        `newLearning` priority, "Due today" reason) — asserts both
///        branches fire from the same call.
///   PT3. Amnesty-cutoff (program path, back-date clamp): a freshly-enrolled
///        program track's `lastReorderAt` (stamped "today", at enrollment
///        time) must NOT amnesty the intentional back-dated anchor window —
///        overdue on/after `trackingStartDate` survives (the F-M-back-date
///        fix documented inline in `buildProjectionTasks`).
@Tags(['scheduler'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

import '../../../../helpers/drift_memory.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake LocalCalendarEngine — deterministic, no separators in the generated
// ref so resolvedOrFallbackProgramRefs' underscore→space fallback transform
// never fires and assertions can compare refs verbatim.
// ─────────────────────────────────────────────────────────────────────────────
class _FakeCalendarEngine implements LocalCalendarEngine {
  _FakeCalendarEngine(this._programId);

  final String _programId;

  String _refForDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'progday$y$m$d';
  }

  @override
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async {
    if (programId != _programId) return null;
    final local = DateTime(date.year, date.month, date.day);
    return CalendarProgramEntry(
      programId: programId,
      displayNameEn: '',
      displayNameHe: '',
      todayRef: _refForDate(date),
      apiSource: 'fake',
      date: local,
    );
  }

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (programId != _programId) return const [];
    final result = <CalendarProgramEntry>[];
    var cursor = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    while (!cursor.isAfter(end)) {
      final local = DateTime(cursor.year, cursor.month, cursor.day);
      result.add(
        CalendarProgramEntry(
          programId: programId,
          displayNameEn: '',
          displayNameHe: '',
          todayRef: _refForDate(cursor),
          apiSource: 'fake',
          date: local,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  @override
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async =>
      const [];

  @override
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) => getEntry(programKey, date);
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake content items — deterministic leaf refs for the self-paced curriculum.
// ─────────────────────────────────────────────────────────────────────────────
List<ContentItem> _fakeItems(CurriculumId curriculum, int count) =>
    List.generate(
      count,
      (i) => ContentItem(
        curriculumId: curriculum.storageKey,
        level1: 'Seder',
        level2: 'Masechta',
        level3: 'Perek',
        level4: '${i + 1}',
        displayNameHe: 'פרק ${i + 1}',
        displayNameEn: 'Chapter ${i + 1}',
        sefariaRef: '${curriculum.storageKey}_ref_$i',
        sortOrder: i,
        isLeaf: true,
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// DB seeding helpers
// ─────────────────────────────────────────────────────────────────────────────
const _profileId = 1;

/// Seeds an active self-paced curriculum track: track row + first stage +
/// a pace goal + all-7-days study-day config. Returns the track id.
Future<int> _seedSelfPacedTrack(
  UserDatabase db, {
  required CurriculumId curriculum,
  required DateTime activatedAt,
  int paceValue = 1,
  String pacePeriod = 'day',
}) async {
  final trackId = await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: _profileId,
          curriculumId: curriculum.storageKey,
          state: const Value('active'),
          stateChangedAt: activatedAt,
          activatedAt: activatedAt,
        ),
      );

  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: _profileId,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
        ),
      );

  final now = DateTimeFactory.nowUtc();
  await db.goalDao.upsertGoalByTrack(
    profileId: _profileId,
    trackId: trackId,
    curriculumId: curriculum.storageKey,
    description: 'Test goal',
    targetPercent: 100.0,
    targetDate: null,
    goalType: 'pace',
    paceValue: paceValue,
    pacePeriod: pacePeriod,
    createdAt: now,
    updatedAt: now,
  );

  for (var d = 1; d <= 7; d++) {
    await db.studyDayConfigDao.upsertDayConfig(
      profileId: _profileId,
      curriculumId: curriculum.storageKey,
      trackId: trackId,
      dayOfWeek: d,
      dayType: 'study',
    );
  }

  return trackId;
}

/// Seeds an active program-enrolled track: track row + first stage +
/// a `profile_programs` enrollment pointing at [programId]. Returns the
/// track id.
Future<int> _seedProgramTrack(
  UserDatabase db, {
  required CurriculumId curriculum,
  required DateTime activatedAt,
  required int programId,
  required DateTime trackingStartDate,
}) async {
  final trackId = await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: _profileId,
          curriculumId: curriculum.storageKey,
          state: const Value('active'),
          stateChangedAt: activatedAt,
          activatedAt: activatedAt,
        ),
      );

  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: _profileId,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
        ),
      );

  await db.profileProgramDao.setProfileProgram(
    profileId: _profileId,
    curriculumType: curriculum.storageKey,
    programId: programId,
    trackingStartDate: trackingStartDate,
  );

  return trackId;
}

// Curriculum whose seed program (`daf_yomi`) is a calendar program.
final _dafYomiProgram = LearningProgramRepository.instance
    .getAllPrograms()
    .firstWhere((p) => p.apiProgramKey == 'daf_yomi');
final _programCurriculum = CurriculumId.values.firstWhere(
  (c) => c.storageKey == _dafYomiProgram.curriculumType,
);

Future<List<ContentItem>> _getScopedContent(CurriculumId curriculumId) async {
  // The self-paced curriculum needs real leaf items so selfPacedSchedule has
  // refs to walk; the program curriculum intentionally gets none —
  // resolvedOrFallbackProgramRefs then falls back to the raw calendar ref,
  // which is exactly what the fake calendar engine's refs are shaped for.
  if (curriculumId == CurriculumId.mishnayos) {
    return _fakeItems(curriculumId, 20);
  }
  return const [];
}

/// Builds a [SchedulerEngine] + [StageDefinitionRepositoryImpl] wired to
/// [db], and the shared [LearningProgramRepository] — the plain,
/// constructor-injected collaborators [buildProjectionTasks] needs. No
/// Riverpod, no `ProviderContainer`.
({
  StageDefinitionRepositoryImpl stageRepository,
  SchedulerEngine engine,
  LearningProgramRepository programRepository,
})
_buildDeps(UserDatabase db) {
  final stageRepository = StageDefinitionRepositoryImpl(
    stageDao: db.stageDao,
    completionDao: db.completionDao,
    pushStageDefinitions: null,
  );
  final engine = SchedulerEngine(
    contentRepository: SchedulerContentRepositoryImpl(
      getContent: _getScopedContent,
    ),
    completionRepository: SchedulerCompletionRepositoryImpl(
      completionDao: db.completionDao,
      stageDao: db.stageDao,
      profileId: _profileId,
    ),
    stageRepository: SchedulerStageRepositoryImpl(stageDao: db.stageDao),
    learningOrderRepository: SchedulerLearningOrderRepositoryImpl(
      learningOrderDao: db.learningOrderDao,
      profileId: _profileId,
    ),
  );
  return (
    stageRepository: stageRepository,
    engine: engine,
    programRepository: LearningProgramRepository.instance,
  );
}

void main() {
  // ── PT1: amnesty-cutoff (self-paced path) ─────────────────────────────────
  test('PT1: reorder stamped mid-day amnesties overdue scheduled strictly '
      'before that device-local day; same-day and later survive', () async {
    final db = inMemoryDb();
    addTearDown(db.close);
    await seedProfile(db);
    final deps = _buildDeps(db);

    final today = DateTime.utc(2026, 5, 27);
    // pace=1/day, anchored 5 days ago → scheduled days: today-5 .. today
    // (5 overdue + 1 dueToday before any amnesty).
    final anchor = today.subtract(const Duration(days: 5));
    final trackId = await _seedSelfPacedTrack(
      db,
      curriculum: CurriculumId.mishnayos,
      activatedAt: anchor,
      paceValue: 1,
      pacePeriod: 'day',
    );

    // Reorder happens mid-day (15:00 UTC) on today-2. The amnesty cutoff
    // must normalize to midnight of today-2's device-local date — NOT the
    // raw instant — so today-2's own scheduled item is NOT amnestied.
    final reorderAt = today
        .subtract(const Duration(days: 2))
        .add(const Duration(hours: 15));
    await db.trackDao.stampReorderAt(trackId, at: reorderAt);

    final calendarService = CalendarProgramService(
      _FakeCalendarEngine('unused'),
    );

    final tasks = await buildProjectionTasks(
      trackLabelFor: (c) => c.storageKey,
      db: db,
      stageRepository: deps.stageRepository,
      engine: deps.engine,
      profileId: _profileId,
      now: today,
      calendarService: calendarService,
      getScopedContent: _getScopedContent,
      programRepository: deps.programRepository,
    );

    final overdue = tasks.where((t) => t.isOverdue).toList();
    final dueToday = tasks.where((t) => !t.isOverdue).toList();

    expect(
      dueToday,
      hasLength(1),
      reason: 'pace=1 → exactly 1 due-today task regardless of amnesty',
    );
    expect(
      overdue,
      hasLength(2),
      reason:
          'amnesty keeps only today-2 and today-1 (scheduled on/after the '
          'reorder-day cutoff); today-5..today-3 (3 days, strictly before '
          'the cutoff) are amnestied',
    );
    expect(
      overdue.every((t) => t.reason == 'Behind pace'),
      isTrue,
      reason: 'surviving overdue tasks are still self-paced (not program)',
    );
  });

  // ── PT2: program-vs-self-paced branching ──────────────────────────────────
  test('PT2: one buildProjectionTasks call routes an enrolled curriculum '
      'through the program path and an unenrolled curriculum through the '
      'self-paced path', () async {
    final db = inMemoryDb();
    addTearDown(db.close);
    await seedProfile(db);
    final deps = _buildDeps(db);

    final today = DateTime.utc(2026, 5, 27);

    // Self-paced curriculum: activated today, pace=1/day → 1 dueToday, 0
    // overdue.
    await _seedSelfPacedTrack(
      db,
      curriculum: CurriculumId.mishnayos,
      activatedAt: today,
      paceValue: 1,
      pacePeriod: 'day',
    );

    // Program curriculum: enrolled in daf_yomi, anchored 2 days ago → the
    // fake calendar engine yields 3 entries: today-2, today-1 (overdue),
    // today (dueToday).
    final programAnchor = today.subtract(const Duration(days: 2));
    await _seedProgramTrack(
      db,
      curriculum: _programCurriculum,
      activatedAt: programAnchor,
      programId: _dafYomiProgram.id,
      trackingStartDate: programAnchor,
    );

    final calendarService = CalendarProgramService(
      _FakeCalendarEngine(_dafYomiProgram.apiProgramKey!),
    );
    // Sanity: the registry must resolve daf_yomi's own apiProgramKey back
    // to itself, or this test would silently exercise no program path.
    expect(
      CalendarProgramRegistry.byId(_dafYomiProgram.apiProgramKey!)?.id,
      _dafYomiProgram.apiProgramKey,
    );

    final tasks = await buildProjectionTasks(
      trackLabelFor: (c) => c.storageKey,
      db: db,
      stageRepository: deps.stageRepository,
      engine: deps.engine,
      profileId: _profileId,
      now: today,
      calendarService: calendarService,
      getScopedContent: _getScopedContent,
      programRepository: deps.programRepository,
    );

    final selfPacedTasks = tasks
        .where((t) => t.curriculumId == CurriculumId.mishnayos)
        .toList();
    final programTasks = tasks
        .where((t) => t.curriculumId == _programCurriculum)
        .toList();

    // Self-paced branch markers.
    expect(
      selfPacedTasks,
      hasLength(1),
      reason: 'self-paced curriculum: pace=1, activated today → 1 task',
    );
    expect(selfPacedTasks.single.priority, DailyTaskPriority.newLearning);
    expect(selfPacedTasks.single.reason, 'Due today');

    // Program branch markers — distinct priorities/reasons from the
    // self-paced branch, produced by the SAME buildProjectionTasks call.
    expect(
      programTasks,
      hasLength(3),
      reason: 'program anchored 2 days ago → 2 overdue + 1 dueToday',
    );
    final programOverdue = programTasks.where((t) => t.isOverdue).toList();
    final programDueToday = programTasks.where((t) => !t.isOverdue).toList();
    expect(programOverdue, hasLength(2));
    expect(programDueToday, hasLength(1));
    expect(
      programOverdue.every(
        (t) =>
            t.priority == DailyTaskPriority.overdueProgram &&
            t.reason == 'Program day pending from previous days',
      ),
      isTrue,
    );
    expect(
      programDueToday.every(
        (t) =>
            t.priority == DailyTaskPriority.todayProgram &&
            t.reason == 'Program assignment for today',
      ),
      isTrue,
    );
  });

  // ── PT3: amnesty-cutoff (program path, back-date clamp) ────────────────────
  test('PT3: a freshly-enrolled program track — lastReorderAt == enrollment '
      'day, anchor several days back-dated — is not amnestied down to zero '
      'overdue (the anchor clamp)', () async {
    final db = inMemoryDb();
    addTearDown(db.close);
    await seedProfile(db);
    final deps = _buildDeps(db);

    final today = DateTime.utc(2026, 5, 27);
    // Back-dated 4 days: enrolling "as if" the user started the program 4
    // days ago. lastReorderAt (stamped at enrollment, i.e. "today") is
    // AFTER every one of those back-dated scheduled days — a naive cutoff
    // would amnesty the whole intended back-date window.
    final programAnchor = today.subtract(const Duration(days: 4));
    final trackId = await _seedProgramTrack(
      db,
      curriculum: _programCurriculum,
      activatedAt: today,
      programId: _dafYomiProgram.id,
      trackingStartDate: programAnchor,
    );
    await db.trackDao.stampReorderAt(trackId, at: today);

    final calendarService = CalendarProgramService(
      _FakeCalendarEngine(_dafYomiProgram.apiProgramKey!),
    );

    final tasks = await buildProjectionTasks(
      trackLabelFor: (c) => c.storageKey,
      db: db,
      stageRepository: deps.stageRepository,
      engine: deps.engine,
      profileId: _profileId,
      now: today,
      calendarService: calendarService,
      getScopedContent: _getScopedContent,
      programRepository: deps.programRepository,
    );

    final overdue = tasks.where((t) => t.isOverdue).toList();
    final dueToday = tasks.where((t) => !t.isOverdue).toList();

    expect(
      overdue,
      hasLength(4),
      reason:
          'the back-date clamp keeps overdue on/after trackingStartDate '
          'even though lastReorderAt is later (today) — a naive cutoff '
          'would wrongly amnesty all 4',
    );
    expect(dueToday, hasLength(1));
  });
}
