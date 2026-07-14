/// Logic tests — scheduler_providers.dart branches NOT covered by
/// scheduler_all_daily_tasks_test.dart.
///
/// Verifier-flagged branches covered here:
///
///   RA1. REORDER-AMNESTY: lastReorderAt set to TODAY → overdue items from
///        yesterday are amnestied (dropped from the result) because their
///        scheduledDate is strictly before the day-level amnesty cutoff.
///
///   RA2. REORDER-AMNESTY mid-day: a lastReorderAt of 15:00 UTC yesterday
///        uses the day-level cutoff (yesterday midnight), so same-local-day
///        items are NOT amnestied even when the raw instant is "after" them.
///        (regression guard for the mid-day activation bug).
///
///   RA3. REORDER-AMNESTY zero: null lastReorderAt (epoch 0) → NO items are
///        amnestied; all overdue items remain in the result.
///
///   DL1. DEADLINE goal — paceValue==null + goalType=='deadline' + targetDate
///        set → derivePaceFromDeadline is called and tasks are generated.
///
///   DL2. DEADLINE goal — studyDaysInWindow==0 early-exit: when every day
///        between today and the deadline is a rest day (all days configured
///        as 'rest'), studyDaysInWindow = 0, derivePaceFromDeadline returns the
///        fallback pace (1/week), and the track still generates tasks rather
///        than silently producing nothing.
///
/// Drives the REAL allDailyTasksProvider via ProviderContainer + in-memory DB.
/// Does NOT duplicate tests from scheduler_all_daily_tasks_test.dart.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake no-op calendar engine (calendar tests are not in scope here).
// ─────────────────────────────────────────────────────────────────────────────
class _NoopCalendarEngine implements LocalCalendarEngine {
  const _NoopCalendarEngine();

  @override
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async => null;

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
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

// ─────────────────────────────────────────────────────────────────────────────
// Profile notifier stub — always returns profileId = 1.
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileId1 extends ActiveProfileId {
  @override
  int build() => 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake content items.
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
// Container builder
// ─────────────────────────────────────────────────────────────────────────────
ProviderContainer _container(
  UserDatabase db, {
  required DateTime clock,
  CurriculumId curriculum = CurriculumId.mishnayos,
  int contentCount = 20,
  List<Override> extraOverrides = const [],
}) {
  final today =
      '${clock.year}-${clock.month.toString().padLeft(2, '0')}-${clock.day.toString().padLeft(2, '0')}';

  SharedPreferences.setMockInitialValues({
    'skipped_tasks_date': today,
    'skipped_tasks_refs': <String>[],
    'skipped_tasks_previous_refs': <String>[],
  });

  final fakeItems = _fakeItems(curriculum, contentCount);

  return ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWith(_ProfileId1.new),
      clockProvider.overrideWith((ref) => clock),
      calendarProgramServiceProvider.overrideWith(
        (ref) =>
            Future.value(CalendarProgramService(const _NoopCalendarEngine())),
      ),
      globalStageRepositoryProvider.overrideWith((ref) {
        return StageDefinitionRepositoryImpl(
          stageDao: db.stageDao,
          completionDao: db.completionDao,
          pushStageDefinitions: null,
        );
      }),
      scopedCurriculumContentProvider(
        curriculum,
      ).overrideWith((ref) => Future.value(fakeItems)),
      for (final c in CurriculumId.values)
        if (c != curriculum)
          scopedCurriculumContentProvider(
            c,
          ).overrideWith((ref) => Future.value(const <ContentItem>[])),
      ...extraOverrides,
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DB seeding helpers
// ─────────────────────────────────────────────────────────────────────────────
const _profileId = 1;

/// Inserts a self-paced track with an explicit pace goal.  Returns the
/// inserted track id.
///
/// [studyDaysType] controls the `dayType` written for all 7 day-of-week rows
/// ('study' by default; pass 'review' to exercise the all-review pattern).
Future<int> _seedPaceTrack(
  UserDatabase db, {
  required CurriculumId curriculum,
  required DateTime activatedAt,
  DateTime? lastReorderAt,
  int paceValue = 1,
  String pacePeriod = 'day',
  String studyDaysType = 'study',
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
          lastReorderAt: Value(lastReorderAt),
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
    description: 'Pace goal',
    targetPercent: 100.0,
    targetDate: null,
    goalType: 'pace',
    paceValue: paceValue,
    pacePeriod: pacePeriod,
    createdAt: now,
    updatedAt: now,
  );

  // All 7 days configured with [studyDaysType] ('study' by default).
  for (var d = 1; d <= 7; d++) {
    await db.studyDayConfigDao.upsertDayConfig(
      profileId: _profileId,
      curriculumId: curriculum.storageKey,
      trackId: trackId,
      dayOfWeek: d,
      dayType: studyDaysType,
    );
  }

  return trackId;
}

/// Inserts a self-paced track with a deadline goal (no paceValue / pacePeriod)
/// so the provider must derive the pace from the deadline.
///
/// [studyDaysType] — 'study' (default, all 7 days) or 'rest' (all days rest).
Future<int> _seedDeadlineTrack(
  UserDatabase db, {
  required CurriculumId curriculum,
  required DateTime activatedAt,
  required DateTime targetDate,
  String studyDaysType = 'study',
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
  // Deliberately leave paceValue and pacePeriod null to exercise the
  // derivePaceFromDeadline fallback path in the provider.
  await db.goalDao.upsertGoalByTrack(
    profileId: _profileId,
    trackId: trackId,
    curriculumId: curriculum.storageKey,
    description: 'Deadline goal',
    targetPercent: 100.0,
    targetDate: targetDate,
    goalType: 'deadline',
    paceValue: null,
    pacePeriod: null,
    createdAt: now,
    updatedAt: now,
  );

  for (var d = 1; d <= 7; d++) {
    await db.studyDayConfigDao.upsertDayConfig(
      profileId: _profileId,
      curriculumId: curriculum.storageKey,
      trackId: trackId,
      dayOfWeek: d,
      dayType: studyDaysType,
    );
  }

  return trackId;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
    // Belt-and-braces: any test that installs a fake LocalDayClock must
    // reset it itself, but reset again here so a forgotten reset can never
    // leak a fake wall-clock into a later, unrelated test file.
    resetLocalDayClock();
  });

  // ── RA1: REORDER-AMNESTY — lastReorderAt == today wipes pre-today overdue ──
  //
  // Scenario: track anchored 3 days ago (pace=1/day, all study days), with
  // lastReorderAt == today (UTC midnight). The 3 items scheduled on anchor,
  // anchor+1, anchor+2 are all strictly before today's UTC midnight, so all 3
  // are amnestied. Only today's task survives.
  test(
    'RA1: lastReorderAt=today (UTC midnight) amnesty drops all pre-today overdue',
    () async {
      final today = DateTime.utc(2026, 6, 4); // Wednesday
      final anchor = today.subtract(const Duration(days: 3));

      await _seedPaceTrack(
        db,
        curriculum: CurriculumId.mishnayos,
        activatedAt: anchor,
        lastReorderAt: today, // today's UTC midnight = day-level cutoff = today
        paceValue: 1,
        pacePeriod: 'day',
      );

      final c = _container(db, clock: today);
      addTearDown(c.dispose);

      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      final tasks = await c.read(allDailyTasksProvider.future);
      final overdue = tasks.where((t) => t.isOverdue).toList();
      final dueToday = tasks.where((t) => !t.isOverdue).toList();

      // All 3 pre-today items were amnestied; only today's 1 item survives.
      expect(
        overdue,
        isEmpty,
        reason:
            'RA1: lastReorderAt==today means all overdue items (scheduled before '
            'today) are amnestied and must not appear',
      );
      expect(
        dueToday,
        hasLength(1),
        reason: "RA1: today's task must still appear after amnesty",
      );
      expect(
        dueToday.first.priority,
        DailyTaskPriority.newLearning,
        reason: "RA1: today's task is newLearning (not overdue)",
      );
    },
  );

  // ── RA2: REORDER-AMNESTY mid-day — day-level cutoff normalisation ──────────
  //
  // Scenario: track anchored 2 days ago, lastReorderAt = yesterday at 15:00 UTC.
  // Raw lastReorderAt > yesterday midnight (00:00 UTC), BUT the day-level cutoff
  // normalises to yesterday midnight. So the item scheduled on anchor day
  // (2 days ago) IS strictly before yesterday midnight → amnestied.
  // The item scheduled on yesterday is NOT before yesterday midnight → survives.
  test('RA2: mid-day lastReorderAt (yesterday 15:00 UTC) only amnesty items '
      'strictly before yesterday midnight, not items on the same local day', () async {
    final today = DateTime.utc(2026, 6, 4);
    final yesterday = today.subtract(const Duration(days: 1));
    final anchor = today.subtract(const Duration(days: 2));

    // lastReorderAt = yesterday at 15:00 UTC (mid-day).
    final midDayYesterday = DateTime.utc(2026, 6, 3, 15, 0, 0);

    await _seedPaceTrack(
      db,
      curriculum: CurriculumId.mishnayos,
      activatedAt: anchor,
      lastReorderAt: midDayYesterday,
      paceValue: 1,
      pacePeriod: 'day',
    );

    final c = _container(db, clock: today);
    addTearDown(c.dispose);

    c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
    await c.read(skippedTasksProvider.notifier).debugReadyForTest;

    final tasks = await c.read(allDailyTasksProvider.future);
    final overdue = tasks.where((t) => t.isOverdue).toList();
    final dueToday = tasks.where((t) => !t.isOverdue).toList();

    // Day-level cutoff = yesterday 00:00 UTC.
    // anchor (2 days ago, 00:00 UTC) is BEFORE yesterday midnight → amnestied.
    // yesterday (00:00 UTC) is NOT before yesterday midnight (equal, not before)
    // → survives as overdue (missed yesterday).
    expect(
      overdue,
      hasLength(1),
      reason:
          "RA2: yesterday's item (same local day as mid-day lastReorderAt) must NOT "
          'be amnestied — it survives as an overdue task',
    );
    expect(
      dueToday,
      hasLength(1),
      reason: "RA2: today's item must appear as newLearning",
    );

    // The surviving overdue must be the yesterday ref (not the anchor ref).
    final overdueRef = overdue.first.contentItemSefariaRef;
    // ref_1 corresponds to day 2 (yesterday in a pace=1 track anchored 2 days ago).
    expect(
      overdueRef,
      equals('mishnayos_ref_1'),
      reason:
          "RA2: only yesterday's ref_1 survives; anchor's ref_0 was amnestied",
    );
    expect(
      yesterday,
      isNotNull,
      reason: 'RA2: confirm yesterday variable was set correctly',
    );
  });

  // ── RA3: null lastReorderAt (epoch 0) — no amnesty ───────────────────────
  //
  // When lastReorderAt is null (track created before the column existed),
  // the provider treats it as epoch 0. Nothing is scheduled before epoch 0,
  // so no overdue items are dropped.
  test(
    'RA3: null lastReorderAt (epoch 0 fallback) → no amnesty; all overdue survive',
    () async {
      final today = DateTime.utc(2026, 6, 4);
      final anchor = today.subtract(const Duration(days: 3));

      await _seedPaceTrack(
        db,
        curriculum: CurriculumId.mishnayos,
        activatedAt: anchor,
        lastReorderAt: null, // null → epoch 0 → no amnesty
        paceValue: 1,
        pacePeriod: 'day',
      );

      final c = _container(db, clock: today);
      addTearDown(c.dispose);

      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      final tasks = await c.read(allDailyTasksProvider.future);
      final overdue = tasks.where((t) => t.isOverdue).toList();
      final dueToday = tasks.where((t) => !t.isOverdue).toList();

      // 3 days ago, 2 days ago, 1 day ago = 3 overdue; + 1 today.
      expect(
        overdue,
        hasLength(3),
        reason:
            'RA3: null lastReorderAt → no amnesty; all 3 pre-today items must '
            'appear as overdue',
      );
      expect(dueToday, hasLength(1), reason: "RA3: today's task still present");
    },
  );

  // ── DL1: DEADLINE goal with null pace → derivePaceFromDeadline used ───────
  //
  // The provider must call derivePaceFromDeadline when:
  //   • goal.paceValue == null
  //   • goal.pacePeriod == null
  //   • goal.goalType == 'deadline'
  //   • goal.targetDate != null
  //   • studyDaysInWindow > 0
  //
  // Expected outcome: tasks ARE generated (non-empty result). The derived pace
  // is >= 1/week → ceil(paceToDaily(derived)) >= 1 → at least 1 task for today.
  test('DL1: deadline goal (paceValue=null, pacePeriod=null) derives pace from '
      'deadline and produces tasks for today', () async {
    final today = DateTime.utc(2026, 6, 4);
    // Deadline is 30 days from today; plenty of study days in window.
    final deadline = today.add(const Duration(days: 30));

    await _seedDeadlineTrack(
      db,
      curriculum: CurriculumId.mishnayos,
      activatedAt: today,
      targetDate: deadline,
      studyDaysType: 'study', // all 7 days = study → studyDaysInWindow > 0
    );

    final c = _container(db, clock: today, contentCount: 30);
    addTearDown(c.dispose);

    c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
    await c.read(skippedTasksProvider.notifier).debugReadyForTest;

    final tasks = await c.read(allDailyTasksProvider.future);

    expect(
      tasks,
      isNotEmpty,
      reason:
          'DL1: a deadline goal with null pace must invoke derivePaceFromDeadline '
          'and produce at least one task — the track must not be silently skipped',
    );
    // All tasks should be newLearning (track anchored today, no prior overdue).
    expect(
      tasks.every((t) => t.priority == DailyTaskPriority.newLearning),
      isTrue,
      reason:
          'DL1: tasks from a today-anchored track must be newLearning, not overdue',
    );
  });

  // ── DL1b (regression, TQ-6 hermeticity): deadline derivation must use the
  //     injected clock, never the real wall clock ───────────────────────────
  //
  // Bug: the deadline-fallback branch computed "today" via
  // DateTimeFactory.nowLocal() (the real wall clock) instead of the
  // provider's own `now`/`todayDate` (sourced from clockProvider, which this
  // test suite overrides to a fixed date). That made DL1 pass or fail purely
  // as a function of when the suite happened to be *run* — it silently broke
  // once real wall-clock time advanced past a test's hardcoded deadline,
  // with no code change required to flip it red. Reproduce that class of bug
  // deterministically (independent of whatever day this suite actually runs
  // on) by installing a fake LocalDayClock far away from BOTH the real date
  // and this test's clockProvider-overridden date: if the deadline-fallback
  // path ever again reads the wall clock instead of `now`, the derived
  // "today" would land in the far future relative to the 30-day-out
  // deadline, `endLocal.isBefore(startLocal)` would trip, pace derivation
  // would be skipped, and this test would go red exactly like DL1 did.
  test(
    'DL1b: deadline-pace derivation is immune to the real wall clock '
    '(TQ-6 — must use the injected clockProvider, not DateTimeFactory)',
    () async {
      final today = DateTime.utc(2026, 6, 4);
      final deadline = today.add(const Duration(days: 30));

      await _seedDeadlineTrack(
        db,
        curriculum: CurriculumId.mishnayos,
        activatedAt: today,
        targetDate: deadline,
        studyDaysType: 'study',
      );

      // Install a fake wall clock decades away from both the real date and
      // `today` above. A correct implementation never consults this — it is
      // wired only through the overridden clockProvider (below).
      useLocalDayClock(FakeLocalDayClock(DateTime.utc(2099, 1, 1)));
      addTearDown(resetLocalDayClock);

      final c = _container(db, clock: today, contentCount: 30);
      addTearDown(c.dispose);

      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      final tasks = await c.read(allDailyTasksProvider.future);

      expect(
        tasks,
        isNotEmpty,
        reason:
            'DL1b: deadline-pace derivation must key off the injected '
            'clockProvider date, not the real (or fake-global) wall clock — '
            'a wall-clock read here silently ghosts the track once real '
            'time drifts past the test-fixed deadline',
      );
    },
  );

  // ── DL2: studyDaysInWindow==0 early-exit + fallback pace ─────────────────
  //
  // When every day in [today, deadline] is configured as a non-study day,
  // countStudyDaysInInclusiveDateRangeForTrack returns 0. The provider still
  // calls derivePaceFromDeadline(studyDaysInWindow=0, ...) which returns the
  // fallback (1, 'per_week'), so a valid pace is always derivable.
  //
  // BUT a config that exists with ZERO study days is a genuine
  // zero-study-day pattern: the user explicitly marked every day as not-study.
  // The projection must NOT collapse an empty study-weekday set to
  // "study every day" (the bug fixed in scheduler_providers.dart) — so no
  // new-learning tasks are scheduled, matching isStudyDayForTrack (which
  // returns false for every day). The track is suppressed, not ghosted-by-
  // accident: it correctly has no due-today/overdue work because the user
  // configured no study days.
  test('DL2: deadline goal with all-non-study-day config → pace is still '
      'derivable (1/week fallback) but the zero-study-day pattern schedules '
      'no new-learning tasks', () async {
    final today = DateTime.utc(2026, 6, 4);
    final deadline = today.add(const Duration(days: 30));

    await _seedDeadlineTrack(
      db,
      curriculum: CurriculumId.mishnayos,
      activatedAt: today,
      targetDate: deadline,
      studyDaysType: 'review', // ALL days non-study → studyDaysInWindow == 0
    );

    final c = _container(db, clock: today, contentCount: 30);
    addTearDown(c.dispose);

    c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
    await c.read(skippedTasksProvider.notifier).debugReadyForTest;

    final tasks = await c.read(allDailyTasksProvider.future);
    final newLearning = tasks
        .where(
          (t) =>
              t.priority == DailyTaskPriority.newLearning ||
              t.priority == DailyTaskPriority.overdueProgram ||
              t.priority == DailyTaskPriority.todayProgram,
        )
        .toList();

    // The derived fallback pace is valid, but with zero study days the
    // projection schedules nothing — it does NOT treat an empty study-weekday
    // set as "study every day".
    expect(
      newLearning,
      isEmpty,
      reason:
          'DL2: a config that exists with zero study days is a genuine '
          'zero-study-day pattern; new learning must NOT be scheduled '
          '(must match isStudyDayForTrack, not collapse to study-every-day)',
    );
  });

  // ── ZS1 (regression): all-review config must NOT collapse to study-every-day
  //
  // Bug-hunt round-2 (goals-scheduler): on a self-paced track where every day
  // is toggled to review-only (dayType=='review' for all 7 days), the
  // projection built studyWeekdays={} from the rows whose dayType=='study'.
  // The projection's StudyDayPattern interprets an EMPTY weekday set as
  // "study every day", so all-review collapsed to all-study and scheduled
  // brand-new learning on days the user explicitly marked review-only —
  // disagreeing with isStudyDayForTrack (which correctly reports those days
  // are NOT study days).
  //
  // After the fix: when study_day_config rows EXIST but none is 'study',
  // the self-paced path skips new-learning scheduling entirely for the track.
  test('ZS1: all-review study-day config (explicit pace) schedules NO new '
      'learning — does not collapse to study-every-day', () async {
    final today = DateTime.utc(2026, 6, 4); // Wednesday
    final anchor = today.subtract(const Duration(days: 3));

    await _seedPaceTrack(
      db,
      curriculum: CurriculumId.mishnayos,
      activatedAt: anchor,
      paceValue: 1,
      pacePeriod: 'day',
      studyDaysType: 'review', // every day toggled to review-only
    );

    final c = _container(db, clock: today);
    addTearDown(c.dispose);

    c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
    await c.read(skippedTasksProvider.notifier).debugReadyForTest;

    final tasks = await c.read(allDailyTasksProvider.future);
    final newLearning = tasks
        .where(
          (t) =>
              t.priority == DailyTaskPriority.newLearning ||
              t.priority == DailyTaskPriority.overdueProgram ||
              t.priority == DailyTaskPriority.todayProgram,
        )
        .toList();

    expect(
      newLearning,
      isEmpty,
      reason:
          'ZS1: with every day marked review-only there are zero study days; '
          'the projection must schedule no new learning (would FAIL before '
          'the fix — empty study-weekday set collapsed to study-every-day).',
    );
  });

  // ── ZS2 (control): a track with at least one study day still schedules new
  //     learning — confirms the fix does not over-suppress mixed configs.
  test(
    'ZS2 control: one study day + six review days still schedules new learning',
    () async {
      final today = DateTime.utc(2026, 6, 4); // Wednesday = ISO weekday 3
      final anchor = today; // anchored today → today's unit due

      // Seed an all-review track, then flip today's weekday to study.
      final trackId = await _seedPaceTrack(
        db,
        curriculum: CurriculumId.mishnayos,
        activatedAt: anchor,
        paceValue: 1,
        pacePeriod: 'day',
        studyDaysType: 'review',
      );
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: _profileId,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: trackId,
        dayOfWeek: today.weekday, // Wednesday → study
        dayType: 'study',
      );

      final c = _container(db, clock: today);
      addTearDown(c.dispose);

      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      final tasks = await c.read(allDailyTasksProvider.future);
      final newLearning = tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();

      expect(
        newLearning,
        isNotEmpty,
        reason:
            'ZS2: at least one study day → the track is NOT suppressed; '
            "today's new-learning task must appear.",
      );
    },
  );
}
