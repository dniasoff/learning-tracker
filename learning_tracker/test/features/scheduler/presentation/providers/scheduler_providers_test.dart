/// Unit tests for scheduler_providers.dart
///
/// Covers:
///   • [SchedulerTaskSectionNotifier] — state transitions + reset
///   • [SchedulerGroupedView]         — toggle logic
///   • [clockProvider]                — override-controlled time
///   • [skippedTasksProvider]         — skip / undoSkip / date-rollover
///   • [paceStatusProvider]           — deadline path + pace path (via DB)
///   • [overdueCountForCurriculumProvider] — filters from allDailyTasks
///   • [firstTaskInTrackForCategoryProvider] — bucket selection logic
///   • [TrackTaskCategory]            — enum completeness
///   • [SchedulerTaskSection]         — enum completeness
///   • allDailyTasksProvider          — override + error path
///   • previouslySkippedRefsProvider  — prefs round-trip
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../../../helpers/drift_memory.dart' as db_helper;

// ---------------------------------------------------------------------------
// Profile override helper (ActiveProfileId is a Notifier — needs a class)
// ---------------------------------------------------------------------------

class _ProfileId1 extends ActiveProfileId {
  @override
  int build() => 1;
}

// ---------------------------------------------------------------------------
// AUD-t-scheduler-03 (AC2): a SharedPreferencesStorePlatform whose getAll()
// resolves only after an artificial delay — proves debugReadyForTest
// synchronizes on the real async prefs load, not a race against a guessed
// sleep duration.
// ---------------------------------------------------------------------------

class _SlowSharedPreferencesStore extends InMemorySharedPreferencesStore {
  _SlowSharedPreferencesStore(super.data) : super.withData();

  @override
  Future<Map<String, Object>> getAll() async {
    // Deliberately longer than every fixed delay this finding replaced
    // (100-200ms) — if synchronization were still time-based instead of
    // awaiting the real load future, the assertion below would observe the
    // stale initial `{}` state.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return super.getAll();
  }
}

// ---------------------------------------------------------------------------
// AUD-scheduler-10 (SM-4): a SharedPreferencesStorePlatform whose getAll()
// suspends on an externally-held Completer until the test opens the gate.
// Lets the test dispose the ProviderContainer while _loadFromPrefs's
// `await SharedPreferences.getInstance()` is still in flight — deterministic
// (no timing race), mirroring the established pattern in
// skipped_onboarding_cta_banner_dismiss_mounted_test.dart (AUD-dashboard-02).
// ---------------------------------------------------------------------------

class _GatedSkippedTasksStore extends InMemorySharedPreferencesStore {
  _GatedSkippedTasksStore(super.data) : super.withData();

  final Completer<void> _gate = Completer<void>();

  void openGate() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<Map<String, Object>> getAll() async {
    await _gate.future;
    return super.getAll();
  }
}

// ---------------------------------------------------------------------------
// Task factory
// ---------------------------------------------------------------------------

DailyTask _task({
  CurriculumId curriculum = CurriculumId.mishnayos,
  String ref = 'Mishnah_Berakhot_1.1',
  int trackId = 1,
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  bool isOverdue = false,
}) {
  return DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: ref,
    stageOrder: 1,
    stageDefinitionId: 1,
    priority: priority,
    isOverdue: isOverdue,
    reason: 'test reason',
    stageName: 'Learn',
    trackId: trackId,
    trackLabel: 'personal',
    estimatedEffortMinutes: 5,
  );
}

// ---------------------------------------------------------------------------
// Container factories — each typed so the overrides list is inferred correctly
// ---------------------------------------------------------------------------

/// Minimal container: in-memory DB + profile=1 + clean prefs.
ProviderContainer _bare() {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db_helper.inMemoryDb()),
      activeProfileIdProvider.overrideWith(_ProfileId1.new),
    ],
  );
}

/// Container with a fixed clock override.
/// IMPORTANT: Caller must set SharedPreferences.setMockInitialValues before
/// calling this function if non-empty prefs are needed.
ProviderContainer _withClock(DateTime clock, {UserDatabase? db}) {
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db ?? db_helper.inMemoryDb()),
      activeProfileIdProvider.overrideWith(_ProfileId1.new),
      clockProvider.overrideWith((ref) => clock),
    ],
  );
}

/// Container with a fixed clock + custom SharedPreferences seed.
ProviderContainer _withClockAndPrefs(
  DateTime clock,
  Map<String, Object> prefs,
) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db_helper.inMemoryDb()),
      activeProfileIdProvider.overrideWith(_ProfileId1.new),
      clockProvider.overrideWith((ref) => clock),
    ],
  );
}

/// Container with [allDailyTasksProvider] overridden to [tasks].
ProviderContainer _withTasks(List<DailyTask> tasks) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db_helper.inMemoryDb()),
      activeProfileIdProvider.overrideWith(_ProfileId1.new),
      allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
    ],
  );
}

/// Container that injects [db] + profile=1 (for paceStatus tests).
ProviderContainer _withDb(UserDatabase db) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWith(_ProfileId1.new),
    ],
  );
}

/// Container with [db] + fixed clock (for paceStatus tests).
ProviderContainer _withDbAndClock(UserDatabase db, DateTime clock) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWith(_ProfileId1.new),
      clockProvider.overrideWith((ref) => clock),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // SharedPreferences mock requires the Flutter test binding to be initialized
  // so platform channel calls are routed to the fake implementation.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── SchedulerTaskSectionNotifier ──────────────────────────────────────────
  group('SchedulerTaskSectionNotifier', () {
    test('initial state is all', () {
      final c = _bare();
      addTearDown(c.dispose);
      expect(c.read(schedulerTaskSectionProvider), SchedulerTaskSection.all);
    });

    test('setSection changes state', () {
      final c = _bare();
      addTearDown(c.dispose);

      c
          .read(schedulerTaskSectionProvider.notifier)
          .setSection(SchedulerTaskSection.overdue);
      expect(
        c.read(schedulerTaskSectionProvider),
        SchedulerTaskSection.overdue,
      );

      c
          .read(schedulerTaskSectionProvider.notifier)
          .setSection(SchedulerTaskSection.review);
      expect(c.read(schedulerTaskSectionProvider), SchedulerTaskSection.review);
    });

    test('reset returns to all after setting a non-default section', () {
      final c = _bare();
      addTearDown(c.dispose);

      c
          .read(schedulerTaskSectionProvider.notifier)
          .setSection(SchedulerTaskSection.today);
      c.read(schedulerTaskSectionProvider.notifier).reset();

      expect(c.read(schedulerTaskSectionProvider), SchedulerTaskSection.all);
    });

    test('all four enum values can be set without error', () {
      final c = _bare();
      addTearDown(c.dispose);

      for (final section in SchedulerTaskSection.values) {
        c.read(schedulerTaskSectionProvider.notifier).setSection(section);
        expect(c.read(schedulerTaskSectionProvider), section);
      }
    });

    test('container.listen receives each state change in order', () {
      final c = _bare();
      addTearDown(c.dispose);

      final emissions = <SchedulerTaskSection>[];
      c.listen<SchedulerTaskSection>(
        schedulerTaskSectionProvider,
        (_, next) => emissions.add(next),
        fireImmediately: false,
      );

      c
          .read(schedulerTaskSectionProvider.notifier)
          .setSection(SchedulerTaskSection.overdue);
      c
          .read(schedulerTaskSectionProvider.notifier)
          .setSection(SchedulerTaskSection.review);
      c.read(schedulerTaskSectionProvider.notifier).reset();

      expect(emissions, [
        SchedulerTaskSection.overdue,
        SchedulerTaskSection.review,
        SchedulerTaskSection.all,
      ]);
    });
  });

  // ── SchedulerGroupedView ──────────────────────────────────────────────────
  group('SchedulerGroupedView', () {
    test('initial state is false (not grouped)', () {
      final c = _bare();
      addTearDown(c.dispose);
      expect(c.read(schedulerGroupedViewProvider), isFalse);
    });

    test('toggle flips to true then back to false', () {
      final c = _bare();
      addTearDown(c.dispose);

      c.read(schedulerGroupedViewProvider.notifier).toggle();
      expect(c.read(schedulerGroupedViewProvider), isTrue);

      c.read(schedulerGroupedViewProvider.notifier).toggle();
      expect(c.read(schedulerGroupedViewProvider), isFalse);
    });

    test('five toggles from false end up true (odd cycle)', () {
      final c = _bare();
      addTearDown(c.dispose);

      for (var i = 0; i < 5; i++) {
        c.read(schedulerGroupedViewProvider.notifier).toggle();
      }
      expect(c.read(schedulerGroupedViewProvider), isTrue);
    });
  });

  // ── clockProvider ─────────────────────────────────────────────────────────
  group('clockProvider', () {
    test('override returns the exact fixed instant', () {
      final fixedNow = DateTime.utc(2026, 5, 29, 12, 0, 0);
      final c = _withClock(fixedNow);
      addTearDown(c.dispose);
      expect(c.read(clockProvider), equals(fixedNow));
    });

    test('two containers with different clock overrides are independent', () {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 12, 31);
      final c1 = _withClock(t1);
      final c2 = _withClock(t2);
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      expect(c1.read(clockProvider), equals(t1));
      expect(c2.read(clockProvider), equals(t2));
      expect(c1.read(clockProvider), isNot(equals(c2.read(clockProvider))));
    });
  });

  // ── SkippedTasks ──────────────────────────────────────────────────────────
  group('SkippedTasks', () {
    test('initial state is an empty set', () {
      SharedPreferences.setMockInitialValues({});
      final c = _bare();
      addTearDown(c.dispose);
      expect(c.read(skippedTasksProvider), isEmpty);
    });

    test('skip adds a ref', () async {
      SharedPreferences.setMockInitialValues({
        'skipped_tasks_date': '2026-05-29',
        'skipped_tasks_refs': <String>[],
      });
      final c = _withClock(DateTime.utc(2026, 5, 29));
      addTearDown(c.dispose);

      // Keep provider alive with a listener (prevents auto-dispose between ops)
      // and wait for _loadFromPrefs to settle.
      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      await c.read(skippedTasksProvider.notifier).skip('ref_A');

      expect(c.read(skippedTasksProvider), contains('ref_A'));
    });

    test('skip multiple refs accumulates them all', () async {
      SharedPreferences.setMockInitialValues({
        'skipped_tasks_date': '2026-05-29',
        'skipped_tasks_refs': <String>[],
      });
      final c = _withClock(DateTime.utc(2026, 5, 29));
      addTearDown(c.dispose);

      // Keep provider alive + await prefs load
      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      await c.read(skippedTasksProvider.notifier).skip('ref_A');
      await c.read(skippedTasksProvider.notifier).skip('ref_B');

      final state = c.read(skippedTasksProvider);
      expect(state, containsAll(['ref_A', 'ref_B']));
      expect(state, hasLength(2));
    });

    test('undoSkip removes the specific ref', () async {
      SharedPreferences.setMockInitialValues({
        'skipped_tasks_date': '2026-05-29',
        'skipped_tasks_refs': <String>[],
      });
      final c = _withClock(DateTime.utc(2026, 5, 29));
      addTearDown(c.dispose);

      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      await c.read(skippedTasksProvider.notifier).skip('ref_A');
      await c.read(skippedTasksProvider.notifier).skip('ref_B');
      await c.read(skippedTasksProvider.notifier).undoSkip('ref_A');

      final state = c.read(skippedTasksProvider);
      expect(state, isNot(contains('ref_A')));
      expect(state, contains('ref_B'));
    });

    test('undoSkip on a ref that was never skipped is a no-op', () async {
      SharedPreferences.setMockInitialValues({
        'skipped_tasks_date': '2026-05-29',
        'skipped_tasks_refs': <String>[],
      });
      final c = _withClock(DateTime.utc(2026, 5, 29));
      addTearDown(c.dispose);

      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      await c.read(skippedTasksProvider.notifier).skip('ref_A');
      await c.read(skippedTasksProvider.notifier).undoSkip('ref_Z');

      expect(c.read(skippedTasksProvider), equals({'ref_A'}));
    });

    test('date rollover: stale prefs are cleared and archived', () async {
      // Prefs written for yesterday
      final c = _withClockAndPrefs(DateTime.utc(2026, 5, 29), {
        'skipped_tasks_date': '2026-05-28',
        'skipped_tasks_refs': ['old_A', 'old_B'],
      });
      addTearDown(c.dispose);

      // Keep provider alive + trigger build (kicks off _loadFromPrefs async call)
      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      // Allow the async prefs read+write to complete
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      // Stale skips are cleared
      expect(c.read(skippedTasksProvider), isEmpty);

      // Yesterday's refs were archived into previouslySkipped
      final prefs = await SharedPreferences.getInstance();
      final prevRefs = prefs.getStringList('skipped_tasks_previous_refs');
      expect(prevRefs, containsAll(['old_A', 'old_B']));
    });

    test('same-date prefs restore the skipped set on load', () async {
      final c = _withClockAndPrefs(DateTime.utc(2026, 5, 29), {
        'skipped_tasks_date': '2026-05-29',
        'skipped_tasks_refs': ['ref_X', 'ref_Y'],
      });
      addTearDown(c.dispose);

      // Keep provider alive + trigger build, await prefs load
      c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
      await c.read(skippedTasksProvider.notifier).debugReadyForTest;

      final state = c.read(skippedTasksProvider);
      expect(state, containsAll(['ref_X', 'ref_Y']));
    });

    test(
      'debugReadyForTest waits for a slow prefs resolution deterministically '
      '(AUD-t-scheduler-03 AC2: no fixed-delay race)',
      () async {
        // Reset the SharedPreferences singleton/completer (the only public
        // way to do so is setMockInitialValues) before installing the
        // deliberately slow store below — otherwise a prior test's cached
        // instance would short-circuit getInstance() and never touch it.
        SharedPreferences.setMockInitialValues({});
        SharedPreferencesStorePlatform.instance = _SlowSharedPreferencesStore({
          'flutter.skipped_tasks_date': '2026-05-29',
          'flutter.skipped_tasks_refs': ['ref_X', 'ref_Y'],
        });
        addTearDown(() => SharedPreferences.setMockInitialValues({}));

        final c = _withClock(DateTime.utc(2026, 5, 29));
        addTearDown(c.dispose);

        c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
        await c.read(skippedTasksProvider.notifier).debugReadyForTest;

        expect(
          c.read(skippedTasksProvider),
          containsAll(['ref_X', 'ref_Y']),
          reason:
              'debugReadyForTest must await the real _loadFromPrefs future, '
              'not a fixed timer — the store above deliberately resolves '
              'getAll() after 400ms, longer than any of the old guessed '
              'delays (100-200ms) this finding replaced.',
        );
      },
    );

    test('container disposed mid-_loadFromPrefs await does not log an '
        'AppLogger error (AUD-scheduler-10, SM-4 regression)', () async {
      // Reset the SharedPreferences singleton/completer before installing
      // the gated store below (same rationale as the debugReadyForTest
      // slow-store test above).
      SharedPreferences.setMockInitialValues({});
      final store = _GatedSkippedTasksStore({
        'flutter.skipped_tasks_date': '2026-05-29',
        'flutter.skipped_tasks_refs': ['ref_X'],
      });
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferences.setMockInitialValues({}));

      final c = _withClock(DateTime.utc(2026, 5, 29));

      // Kick off build() -> _loadFromPrefs(), which suspends on the gated
      // getAll() call inside `await SharedPreferences.getInstance()`.
      c.listen<Set<String>>(skippedTasksProvider, (_, _) {});

      final historyBefore = AppLogger.instance.talker.history.length;

      // Dispose the container while the prefs load is still in flight —
      // the exact SM-4 race this finding guards against.
      c.dispose();

      // Resolve the gated getAll() now that the container is gone.
      store.openGate();

      // Let the resumed continuation run to completion.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final newEntries = AppLogger.instance.talker.history
          .skip(historyBefore)
          .map((e) => e.generateTextMessage())
          .toList();

      expect(
        newEntries.any((m) => m.contains('Failed to load skipped tasks')),
        isFalse,
        reason:
            'a disposed-mid-load ref must return early via the '
            'ref.mounted guard, not fall through to the catch block and '
            'misreport a routine dispose race as "Failed to load skipped '
            'tasks". New log entries: $newEntries',
      );
    });
  });

  // ── previouslySkippedRefsProvider ─────────────────────────────────────────
  group('previouslySkippedRefsProvider', () {
    test('returns empty set when no previous refs in prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _bare();
      addTearDown(c.dispose);

      final result = await c.read(previouslySkippedRefsProvider.future);
      expect(result, isEmpty);
    });

    test('returns stored previous refs from SharedPreferences', () async {
      // Set prefs BEFORE building the container so the FutureProvider reads
      // the correct initial values. _bare() would reset prefs, so use a
      // dedicated setup that doesn't clobber the prefs we need.
      SharedPreferences.setMockInitialValues({
        'skipped_tasks_previous_refs': ['prev_A', 'prev_B'],
      });
      final c = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db_helper.inMemoryDb()),
          activeProfileIdProvider.overrideWith(_ProfileId1.new),
        ],
      );
      addTearDown(c.dispose);

      final result = await c.read(previouslySkippedRefsProvider.future);
      expect(result, containsAll(['prev_A', 'prev_B']));
    });
  });

  // ── paceStatusProvider ────────────────────────────────────────────────────
  group('paceStatusProvider', () {
    late UserDatabase db;

    setUp(() async {
      db = db_helper.inMemoryDb();
      await db_helper.seedProfile(db); // inserts profileId = 1
    });

    tearDown(() => db.close());

    test(
      'returns null when no goalDeadline is provided for a deadline goal',
      () async {
        final c = _withDb(db);
        addTearDown(c.dispose);

        final result = await c.read(
          paceStatusProvider(
            curriculumId: CurriculumId.mishnayos,
            goalStartDate: DateTime.utc(2026, 1, 1),
            totalItems: 100,
            // goalDeadline intentionally omitted → null
          ).future,
        );

        expect(result, isNull);
      },
    );

    test(
      'returns a PaceStatus for a deadline goal even with no completions',
      () async {
        final c = _withDbAndClock(db, DateTime.utc(2026, 5, 29));
        addTearDown(c.dispose);

        final result = await c.read(
          paceStatusProvider(
            curriculumId: CurriculumId.mishnayos,
            goalStartDate: DateTime.utc(2026, 1, 1),
            goalDeadline: DateTime.utc(2026, 12, 31),
            totalItems: 365,
          ).future,
        );

        expect(result, isNotNull);
        expect(result!.rollingAverage, 0.0);
        expect(
          result.projectedCompletionDate,
          isNull,
          reason: 'No study history → cannot project',
        );
      },
    );

    test('pace goal: behind when rolling average is zero', () async {
      final c = _withDbAndClock(db, DateTime.utc(2026, 5, 29));
      addTearDown(c.dispose);

      final result = await c.read(
        paceStatusProvider(
          curriculumId: CurriculumId.mishnayos,
          goalStartDate: DateTime.utc(2026, 1, 1),
          totalItems: 200,
          goalType: 'pace',
          pacePerDay: 1.0,
        ).future,
      );

      expect(result, isNotNull);
      expect(
        result!.status,
        PaceStatusType.behind,
        reason: 'Rolling average 0 < target 1 → behind',
      );
    });

    test('pace goal: ahead when rolling average exceeds target pace', () async {
      // 7 completions on each of the last 7 days → rolling avg = 1.0
      for (var i = 1; i <= 7; i++) {
        final ts = DateTime.utc(2026, 5, 29 - i, 10);
        await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Berakhot_$i',
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: ts,
          ),
        );
      }

      final c = _withDbAndClock(db, DateTime.utc(2026, 5, 29));
      addTearDown(c.dispose);

      final result = await c.read(
        paceStatusProvider(
          curriculumId: CurriculumId.mishnayos,
          goalStartDate: DateTime.utc(2026, 1, 1),
          totalItems: 200,
          goalType: 'pace',
          pacePerDay: 0.5, // rolling avg 1.0 > 0.5
        ).future,
      );

      expect(result, isNotNull);
      expect(result!.status, PaceStatusType.ahead);
      expect(result.rollingAverage, closeTo(1.0, 0.01));
    });

    test(
      'deadline goal: rolling average reflects yesterday completions',
      () async {
        // 3 completions yesterday
        for (var i = 0; i < 3; i++) {
          await db.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: 'Ref_$i',
              stageId: 1,
              trackType: 'personal',
              eventTimestamp: DateTime.utc(2026, 5, 28, 10),
            ),
          );
        }

        final c = _withDbAndClock(db, DateTime.utc(2026, 5, 29));
        addTearDown(c.dispose);

        final result = await c.read(
          paceStatusProvider(
            curriculumId: CurriculumId.mishnayos,
            goalStartDate: DateTime.utc(2026, 1, 1),
            goalDeadline: DateTime.utc(2026, 12, 31),
            totalItems: 365,
          ).future,
        );

        expect(result, isNotNull);
        // Rolling 7-day avg: 3 completions in the last 7 days / 7 = 3/7
        expect(result!.rollingAverage, closeTo(3.0 / 7.0, 0.01));
      },
    );

    test(
      'deadline goal: completions in other curricula do not bleed in',
      () async {
        // Insert 5 bavli completions — must NOT inflate mishnayos rolling avg
        for (var i = 0; i < 5; i++) {
          await db.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.bavli.storageKey,
              sefariaRef: 'Bavli_$i',
              stageId: 1,
              trackType: 'personal',
              eventTimestamp: DateTime.utc(2026, 5, 28, 10),
            ),
          );
        }

        final c = _withDbAndClock(db, DateTime.utc(2026, 5, 29));
        addTearDown(c.dispose);

        final result = await c.read(
          paceStatusProvider(
            curriculumId: CurriculumId.mishnayos,
            goalStartDate: DateTime.utc(2026, 1, 1),
            goalDeadline: DateTime.utc(2026, 12, 31),
            totalItems: 365,
          ).future,
        );

        expect(result, isNotNull);
        expect(
          result!.rollingAverage,
          0.0,
          reason: 'Bavli completions must not inflate mishnayos rolling avg',
        );
      },
    );
  });

  // ── paceStatusProvider error path ─────────────────────────────────────────
  group('paceStatusProvider — error path', () {
    test('error from the provider propagates to the future', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          userDatabaseProvider.overrideWithValue(db_helper.inMemoryDb()),
          activeProfileIdProvider.overrideWith(_ProfileId1.new),
          paceStatusProvider(
            curriculumId: CurriculumId.mishnayos,
            goalStartDate: DateTime.utc(2026, 1, 1),
            goalDeadline: DateTime.utc(2026, 12, 31),
            totalItems: 100,
          ).overrideWith(
            (ref) => Future<PaceStatus?>.error(Exception('db gone')),
          ),
        ],
      );
      addTearDown(c.dispose);

      await expectLater(
        c.read(
          paceStatusProvider(
            curriculumId: CurriculumId.mishnayos,
            goalStartDate: DateTime.utc(2026, 1, 1),
            goalDeadline: DateTime.utc(2026, 12, 31),
            totalItems: 100,
          ).future,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── overdueCountForCurriculumProvider ─────────────────────────────────────
  group('overdueCountForCurriculumProvider', () {
    test('returns 0 when allDailyTasks is empty', () async {
      final c = _withTasks([]);
      addTearDown(c.dispose);

      final count = await c.read(
        overdueCountForCurriculumProvider(CurriculumId.mishnayos).future,
      );
      expect(count, 0);
    });

    test('counts only overdue tasks for the requested curriculum', () async {
      final tasks = [
        _task(
          curriculum: CurriculumId.mishnayos,
          ref: 'mish_overdue_1',
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
        ),
        _task(
          curriculum: CurriculumId.mishnayos,
          ref: 'mish_overdue_2',
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
        ),
        _task(
          curriculum: CurriculumId.mishnayos,
          ref: 'mish_today',
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
        ),
        _task(
          curriculum: CurriculumId.bavli,
          ref: 'bavli_overdue',
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
        ),
      ];

      final c = _withTasks(tasks);
      addTearDown(c.dispose);

      expect(
        await c.read(
          overdueCountForCurriculumProvider(CurriculumId.mishnayos).future,
        ),
        2,
        reason: 'Only mishnayos overdue tasks',
      );
      expect(
        await c.read(
          overdueCountForCurriculumProvider(CurriculumId.bavli).future,
        ),
        1,
        reason: 'Only bavli overdue tasks',
      );
      expect(
        await c.read(
          overdueCountForCurriculumProvider(CurriculumId.chumash).future,
        ),
        0,
        reason: 'No chumash tasks at all',
      );
    });

    test('non-overdue tasks are never counted even if present', () async {
      final tasks = [
        _task(
          curriculum: CurriculumId.mishnayos,
          ref: 'today_ref',
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
        ),
        _task(
          curriculum: CurriculumId.mishnayos,
          ref: 'new_ref',
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
        ),
      ];

      final c = _withTasks(tasks);
      addTearDown(c.dispose);

      final count = await c.read(
        overdueCountForCurriculumProvider(CurriculumId.mishnayos).future,
      );
      expect(count, 0);
    });

    test(
      'all overdue priority types are counted (program + chazara + new-learning)',
      () async {
        final tasks = [
          _task(
            curriculum: CurriculumId.bavli,
            ref: 'r1',
            priority: DailyTaskPriority.overdueProgram,
            isOverdue: true,
          ),
          _task(
            curriculum: CurriculumId.bavli,
            ref: 'r2',
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
          ),
          _task(
            curriculum: CurriculumId.bavli,
            ref: 'r3',
            priority: DailyTaskPriority.overdueNewLearning,
            isOverdue: true,
          ),
        ];

        final c = _withTasks(tasks);
        addTearDown(c.dispose);

        final count = await c.read(
          overdueCountForCurriculumProvider(CurriculumId.bavli).future,
        );
        expect(count, 3);
      },
    );
  });

  // ── allDailyTasksProvider override ───────────────────────────────────────
  group('allDailyTasksProvider — override', () {
    test('override with task list returns those tasks', () async {
      final tasks = [_task(ref: 'ref_A'), _task(ref: 'ref_B')];
      final c = _withTasks(tasks);
      addTearDown(c.dispose);

      final result = await c.read(allDailyTasksProvider.future);
      expect(result, hasLength(2));
      expect(
        result.map((t) => t.contentItemSefariaRef).toList(),
        containsAll(['ref_A', 'ref_B']),
      );
    });

    test('override with empty list returns empty', () async {
      final c = _withTasks([]);
      addTearDown(c.dispose);

      final result = await c.read(allDailyTasksProvider.future);
      expect(result, isEmpty);
    });

    test('error path (retry=null): future throws', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          userDatabaseProvider.overrideWithValue(db_helper.inMemoryDb()),
          activeProfileIdProvider.overrideWith(_ProfileId1.new),
          allDailyTasksProvider.overrideWith(
            (ref) => Future<List<DailyTask>>.error(Exception('scheduler gone')),
          ),
        ],
      );
      addTearDown(c.dispose);

      await expectLater(
        c.read(allDailyTasksProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── firstTaskInTrackForCategoryProvider ───────────────────────────────────
  group('firstTaskInTrackForCategoryProvider', () {
    test('returns null when allDailyTasks is empty', () async {
      final c = _withTasks([]);
      addTearDown(c.dispose);

      final task = await c.read(
        firstTaskInTrackForCategoryProvider(
          trackId: 1,
          category: TrackTaskCategory.dueToday,
        ).future,
      );
      expect(task, isNull);
    });

    test('returns null when no tasks match the requested trackId', () async {
      final c = _withTasks([
        _task(trackId: 99, priority: DailyTaskPriority.newLearning),
      ]);
      addTearDown(c.dispose);

      final task = await c.read(
        firstTaskInTrackForCategoryProvider(
          trackId: 1,
          category: TrackTaskCategory.dueToday,
        ).future,
      );
      expect(task, isNull);
    });

    test(
      'dueToday bucket: first non-overdue non-review task for the track',
      () async {
        final tasks = [
          _task(
            ref: 'overdue_task',
            trackId: 1,
            priority: DailyTaskPriority.overdueProgram,
            isOverdue: true,
          ),
          _task(
            ref: 'today_first',
            trackId: 1,
            priority: DailyTaskPriority.todayProgram,
            isOverdue: false,
          ),
          _task(
            ref: 'today_second',
            trackId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
          ),
        ];

        final c = _withTasks(tasks);
        addTearDown(c.dispose);

        final task = await c.read(
          firstTaskInTrackForCategoryProvider(
            trackId: 1,
            category: TrackTaskCategory.dueToday,
          ).future,
        );
        expect(task, isNotNull);
        expect(task!.contentItemSefariaRef, 'today_first');
      },
    );

    test(
      'overdue bucket: first overdue non-chazara task for the track',
      () async {
        final tasks = [
          _task(
            ref: 'overdue_prog_1',
            trackId: 1,
            priority: DailyTaskPriority.overdueProgram,
            isOverdue: true,
          ),
          _task(
            ref: 'overdue_prog_2',
            trackId: 1,
            priority: DailyTaskPriority.overdueNewLearning,
            isOverdue: true,
          ),
          _task(
            ref: 'today_task',
            trackId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
          ),
        ];

        final c = _withTasks(tasks);
        addTearDown(c.dispose);

        final task = await c.read(
          firstTaskInTrackForCategoryProvider(
            trackId: 1,
            category: TrackTaskCategory.overdue,
          ).future,
        );
        expect(task, isNotNull);
        expect(task!.contentItemSefariaRef, 'overdue_prog_1');
      },
    );

    test(
      'review bucket: first overdueChazara or scheduledChazara task',
      () async {
        final tasks = [
          _task(
            ref: 'new_task',
            trackId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
          ),
          _task(
            ref: 'chazara_overdue',
            trackId: 1,
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
          ),
          _task(
            ref: 'chazara_scheduled',
            trackId: 1,
            priority: DailyTaskPriority.scheduledChazara,
            isOverdue: false,
          ),
        ];

        final c = _withTasks(tasks);
        addTearDown(c.dispose);

        final task = await c.read(
          firstTaskInTrackForCategoryProvider(
            trackId: 1,
            category: TrackTaskCategory.review,
          ).future,
        );
        expect(task, isNotNull);
        expect(task!.contentItemSefariaRef, 'chazara_overdue');
      },
    );

    test(
      'scheduledChazara with isOverdue=false is still returned by review bucket',
      () async {
        final tasks = [
          _task(
            ref: 'scheduled_review',
            trackId: 5,
            priority: DailyTaskPriority.scheduledChazara,
            isOverdue: false,
          ),
        ];

        final c = _withTasks(tasks);
        addTearDown(c.dispose);

        final task = await c.read(
          firstTaskInTrackForCategoryProvider(
            trackId: 5,
            category: TrackTaskCategory.review,
          ).future,
        );
        expect(task, isNotNull);
        expect(task!.priority, DailyTaskPriority.scheduledChazara);
      },
    );

    test(
      'dueToday bucket excludes overdueChazara (it is review, not today)',
      () async {
        final tasks = [
          _task(
            ref: 'chazara_overdue',
            trackId: 1,
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
          ),
        ];

        final c = _withTasks(tasks);
        addTearDown(c.dispose);

        final task = await c.read(
          firstTaskInTrackForCategoryProvider(
            trackId: 1,
            category: TrackTaskCategory.dueToday,
          ).future,
        );
        expect(
          task,
          isNull,
          reason: 'overdueChazara belongs in review, not dueToday',
        );
      },
    );

    test(
      'all three categories return null when tasks are for a different track',
      () async {
        final tasks = [
          _task(
            ref: 'other_overdue',
            trackId: 99,
            priority: DailyTaskPriority.overdueProgram,
            isOverdue: true,
          ),
          _task(
            ref: 'other_chazara',
            trackId: 99,
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
          ),
          _task(
            ref: 'other_today',
            trackId: 99,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
          ),
        ];

        final c = _withTasks(tasks);
        addTearDown(c.dispose);

        for (final category in TrackTaskCategory.values) {
          final task = await c.read(
            firstTaskInTrackForCategoryProvider(
              trackId: 1,
              category: category,
            ).future,
          );
          expect(
            task,
            isNull,
            reason: 'Track 1 has no tasks; checked category $category',
          );
        }
      },
    );
  });

  // ── TrackTaskCategory enum ─────────────────────────────────────────────────
  group('TrackTaskCategory enum', () {
    test('has exactly 3 values: review, dueToday, overdue', () {
      expect(TrackTaskCategory.values, hasLength(3));
      expect(TrackTaskCategory.values, contains(TrackTaskCategory.review));
      expect(TrackTaskCategory.values, contains(TrackTaskCategory.dueToday));
      expect(TrackTaskCategory.values, contains(TrackTaskCategory.overdue));
    });
  });

  // ── SchedulerTaskSection enum ─────────────────────────────────────────────
  group('SchedulerTaskSection enum', () {
    test('has exactly 4 values: all, today, overdue, review', () {
      expect(SchedulerTaskSection.values, hasLength(4));
      expect(SchedulerTaskSection.values, contains(SchedulerTaskSection.all));
      expect(SchedulerTaskSection.values, contains(SchedulerTaskSection.today));
      expect(
        SchedulerTaskSection.values,
        contains(SchedulerTaskSection.overdue),
      );
      expect(
        SchedulerTaskSection.values,
        contains(SchedulerTaskSection.review),
      );
    });
  });
}
