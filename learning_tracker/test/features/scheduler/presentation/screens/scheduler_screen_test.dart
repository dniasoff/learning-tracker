// ignore_for_file: deprecated_member_use
// Test-only: TestWidgetsFlutterBinding.instance.window.*TestValue is the
// only binding-level viewport-sizing API available in setUp (no tester there).

/// L1 widget-behaviour tests for [SchedulerScreen].
///
/// This is the sole test file exercising [SchedulerScreen] top-to-bottom
/// (AUD-t-scheduler-05): a prior, near-fully-duplicate `scheduler_screen_test
/// .dart` was deleted and this file — formerly `scheduler_screen_l1_test
/// .dart` — was renamed to the AG-5-mirrored path (`test/.../
/// scheduler_screen_test.dart` mirrors `lib/.../scheduler_screen.dart`) so
/// the file that survives keeps satisfying the test-mirroring ratchet.
///
/// Covers:
///   1.  Empty state (no tasks at all) — celebration icon + copy present.
///   2.  Loading state — CircularProgressIndicator shown.
///   3.  Error state — error text + Retry button shown; tapping Retry
///       re-triggers the provider (invalidates).
///   4.  Data state: task count in "TODAY'S GOAL" card matches task list.
///   5.  "Daily Tasks" header present when tasks exist.
///   6.  Section filter — SchedulerTaskSection.today hides overdue tasks.
///   7.  Section filter — SchedulerTaskSection.overdue hides non-overdue tasks.
///   8.  Section filter — SchedulerTaskSection.review hides non-chazara tasks.
///   9.  Section filter — all filtered out → empty-state shown.
///  10.  View toggle button present; tapping it switches to GroupedDailyView.
///  11.  Flat task list renders DailyTaskCard widgets, including the correct
///       per-curriculum ref label for each task (e.g. Mishnah vs. Bavli).
///  12.  Skip (swipe-dismiss) shows snackbar with Undo action.
///  13.  No track-type labels ("Personal"/"Standard"/"Custom"/"אישי") shown.
///  14.  Hebrew (RTL) smoke — screen pumps without error under `he` locale.
///  15.  AUD-scheduler-01 (PF-2): grouped view lazily windows a large
///       (~200-task) backlog instead of realizing every DailyTaskCard.
@Tags(['scheduler', 'l1'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/scheduler_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/grouped_daily_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

/// Creates a minimal [DailyTask] for testing.
DailyTask _task({
  CurriculumId curriculum = CurriculumId.mishnayos,
  String ref = 'Mishnah_Berakhot_1.1',
  int stageOrder = 1,
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  bool isOverdue = false,
  String? stageName,
}) {
  return DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: ref,
    stageOrder: stageOrder,
    priority: priority,
    isOverdue: isOverdue,
    reason: 'test',
    stageName: stageName ?? (stageOrder == 1 ? 'Learn' : 'Chazara'),
    trackLabel: 'Test Track',
    estimatedEffortMinutes: 5,
  );
}

/// Builds [SchedulerScreen] under a minimal test harness.
///
/// [tasks]          — resolves from [allDailyTasksProvider]; defaults to empty.
/// [tasksFactory]   — factory called by the provider override; for
///                    never-completing or error futures.  Overrides [tasks].
/// [section]        — initial [SchedulerTaskSection]; defaults to .all.
/// [locale]         — language locale; defaults to English.
Widget _buildScreen({
  List<DailyTask> tasks = const [],
  Future<List<DailyTask>> Function()? tasksFactory,
  SchedulerTaskSection section = SchedulerTaskSection.all,
  Locale locale = const Locale('en'),
}) {
  final overrides = <Override>[
    useHebrewTermsProvider.overrideWith(
      locale.languageCode == 'he' ? _HebrewTermsOn.new : _HebrewTermsOff.new,
    ),
    allDailyTasksProvider.overrideWith(
      (ref) async {
        final skipped = ref.watch(skippedTasksProvider);
        final resolved = tasksFactory != null ? await tasksFactory() : tasks;
        return resolved
            .where((task) => !skipped.contains(task.contentItemSefariaRef))
            .toList();
      },
    ),
    schedulerTaskSectionProvider.overrideWith(() {
      final n = SchedulerTaskSectionNotifier();
      // post-init hook — set section after build() returns default
      Future.microtask(() => n.setSection(section));
      return n;
    }),
  ];

  return ProviderScope(
    retry: (_, __) => null,
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SchedulerScreen(),
    ),
  );
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.instance.window.physicalSizeTestValue =
        const Size(1080, 2340);
    TestWidgetsFlutterBinding.instance.window.devicePixelRatioTestValue = 3.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.window.clearPhysicalSizeTestValue();
    TestWidgetsFlutterBinding.instance.window.clearDevicePixelRatioTestValue();
  });

  // ── 1. Empty state ─────────────────────────────────────────────────────────

  group('SchedulerScreen — empty state', () {
    testWidgets('shows celebration icon and all-caught-up copy', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(tasks: const []));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.celebration_outlined), findsOneWidget);
      expect(find.text('All caught up! Great work!'), findsOneWidget);
      expect(
        find.text('You have no tasks remaining for today.'),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets('empty state has no task cards', (tester) async {
      await tester.pumpWidget(_buildScreen(tasks: const []));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DailyTaskCard), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── 2. Loading state ────────────────────────────────────────────────────────

  group('SchedulerScreen — loading state', () {
    testWidgets('shows CircularProgressIndicator before data arrives', (
      tester,
    ) async {
      final controller = Completer<List<DailyTask>>();

      await tester.pumpWidget(
        _buildScreen(tasksFactory: () => controller.future),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DailyTaskCard), findsNothing);

      controller.complete(const []);
      await _tearDown(tester);
    });
  });

  // ── 3. Error state ──────────────────────────────────────────────────────────

  group('SchedulerScreen — error state', () {
    testWidgets('shows error text and Retry button on provider failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          tasksFactory: () =>
              Future.error(Exception('db exploded'), StackTrace.empty),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Error loading tasks'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await _tearDown(tester);
    });

    // R6-6 regression: raw exception must NOT leak to the user-facing text.
    testWidgets(
      'R6-6: error state does not expose raw exception string to user',
      (tester) async {
        await tester.pumpWidget(
          _buildScreen(
            tasksFactory: () =>
                Future.error(Exception('SECRET_DB_DETAIL'), StackTrace.empty),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.textContaining('SECRET_DB_DETAIL'),
          findsNothing,
          reason:
              'Raw exception message must not be visible to the user '
              '(R6-6 regression guard)',
        );

        await _tearDown(tester);
      },
    );

    testWidgets('no task cards shown in error state', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          tasksFactory: () => Future.error(Exception('fail'), StackTrace.empty),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DailyTaskCard), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('tapping Retry triggers provider rebuild', (tester) async {
      // Call count tracks how many times the provider was invoked.
      var callCount = 0;
      final overrides = <Override>[
        useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
        allDailyTasksProvider.overrideWith((ref) {
          callCount++;
          return Future<List<DailyTask>>.error(
            Exception('fail'),
            StackTrace.empty,
          );
        }),
      ];

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: SchedulerScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final beforeTap = callCount;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Provider was rebuilt at least once more after Retry.
      expect(callCount, greaterThan(beforeTap));

      await _tearDown(tester);
    });
  });

  // ── 4. Data state: task count ───────────────────────────────────────────────

  group('SchedulerScreen — data state', () {
    testWidgets('TODAY\'S GOAL card shows correct task count', (tester) async {
      final tasks = [
        _task(ref: 'Ref_1'),
        _task(ref: 'Ref_2'),
        _task(ref: 'Ref_3'),
      ];

      await tester.pumpWidget(_buildScreen(tasks: tasks));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // _GoalCard renders the localized schedulerGoalTaskCount (en plural).
      expect(find.text('3 tasks today'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('single task shows singular count', (tester) async {
      await tester.pumpWidget(_buildScreen(tasks: [_task()]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // SCHED-GOAL-PLURAL-15: count==1 must say "task" not "tasks"
      // (localized via schedulerGoalTaskCount ICU plural).
      expect(find.text('1 task today'), findsOneWidget);

      await _tearDown(tester);
    });

    // ── 5. Header ──────────────────────────────────────────────────────────────

    testWidgets('"Daily Tasks" header present when tasks exist', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(tasks: [_task()]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Daily Tasks'), findsOneWidget);

      await _tearDown(tester);
    });

    // ── 11. Flat task list ─────────────────────────────────────────────────────

    testWidgets('flat list renders one DailyTaskCard per task', (tester) async {
      final tasks = [_task(ref: 'Ref_1'), _task(ref: 'Ref_2')];

      await tester.pumpWidget(_buildScreen(tasks: tasks));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DailyTaskCard), findsNWidgets(2));

      await _tearDown(tester);
    });

    // AUD-t-scheduler-05: folded from the deleted scheduler_screen_test.dart
    // ("renders task cards when tasks exist") — the per-curriculum ref-label
    // rendering it checked was not a strict duplicate: daily_task_card_test
    // covers a Mishnayos ref in isolation, but nothing else exercises a
    // Bavli ref, nor mixed curricula, at the SchedulerScreen level.
    testWidgets(
      'flat list renders the correct per-curriculum ref label for each task',
      (tester) async {
        final tasks = [
          _task(ref: 'Mishnah_Berakhot_1.1'),
          _task(curriculum: CurriculumId.bavli, ref: 'Bavli_Berakhot_2a'),
        ];

        await tester.pumpWidget(_buildScreen(tasks: tasks));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(DailyTaskCard), findsNWidgets(2));
        expect(find.text('Mishnah Berakhot 1.1'), findsOneWidget);
        expect(find.text('Bavli Berakhot 2a'), findsOneWidget);

        await _tearDown(tester);
      },
    );
  });

  // ── 6–9. Section filter ─────────────────────────────────────────────────────

  group('SchedulerScreen — section filter: today', () {
    testWidgets('today section hides overdue tasks, shows non-overdue', (
      tester,
    ) async {
      final tasks = [
        _task(
          ref: 'Due_Today',
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
        ),
        _task(
          ref: 'Overdue_1',
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(tasks: tasks, section: SchedulerTaskSection.today),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // One non-overdue non-chazara task should be shown.
      expect(find.byType(DailyTaskCard), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('today section hides chazara tasks', (tester) async {
      final tasks = [
        _task(
          ref: 'Chazara_Today',
          priority: DailyTaskPriority.scheduledChazara,
          isOverdue: false,
          stageOrder: 2,
        ),
        _task(
          ref: 'Learn_Today',
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(tasks: tasks, section: SchedulerTaskSection.today),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Only the newLearning task should pass the today filter.
      expect(find.byType(DailyTaskCard), findsOneWidget);

      await _tearDown(tester);
    });
  });

  group('SchedulerScreen — section filter: overdue', () {
    testWidgets('overdue section shows only overdue tasks', (tester) async {
      final tasks = [
        _task(
          ref: 'Due_Today',
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
        ),
        _task(
          ref: 'Overdue_1',
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
        ),
        _task(
          ref: 'Overdue_2',
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(tasks: tasks, section: SchedulerTaskSection.overdue),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Only the 2 overdue tasks should be visible.
      expect(find.byType(DailyTaskCard), findsNWidgets(2));

      await _tearDown(tester);
    });
  });

  group('SchedulerScreen — section filter: review (chazara)', () {
    testWidgets('review section shows only chazara tasks', (tester) async {
      final tasks = [
        _task(
          ref: 'Learn_1',
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
        ),
        _task(
          ref: 'Chazara_Overdue',
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: false,
          stageOrder: 2,
        ),
        _task(
          ref: 'Chazara_Today',
          priority: DailyTaskPriority.scheduledChazara,
          isOverdue: false,
          stageOrder: 2,
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(tasks: tasks, section: SchedulerTaskSection.review),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Only the 2 chazara tasks should be visible.
      expect(find.byType(DailyTaskCard), findsNWidgets(2));

      await _tearDown(tester);
    });
  });

  group('SchedulerScreen — section filter: all filtered → empty state', () {
    testWidgets(
      'when section filter excludes all tasks, empty state is shown',
      (tester) async {
        // All tasks are newLearning (not overdue).
        final tasks = [
          _task(ref: 'Due_1', priority: DailyTaskPriority.newLearning),
          _task(ref: 'Due_2', priority: DailyTaskPriority.newLearning),
        ];

        // Overdue section: both tasks are not overdue → filtered to empty.
        await tester.pumpWidget(
          _buildScreen(tasks: tasks, section: SchedulerTaskSection.overdue),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.celebration_outlined), findsOneWidget);
        expect(find.byType(DailyTaskCard), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── 10. View toggle ─────────────────────────────────────────────────────────

  group('SchedulerScreen — view toggle', () {
    testWidgets('view toggle button present with tasks', (tester) async {
      await tester.pumpWidget(_buildScreen(tasks: [_task()]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The _GoalCard contains an InkWell for the toggle.
      // The icon is grid_view_rounded when in flat mode.
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('tapping toggle switches from flat list to GroupedDailyView', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(tasks: [_task()]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Flat view: no GroupedDailyView
      expect(find.byType(GroupedDailyView), findsNothing);

      // Tap the toggle (InkWell inside _GoalCard wrapping the icon).
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Grouped view now rendered.
      expect(find.byType(GroupedDailyView), findsOneWidget);
      // Icon flips to list view icon.
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('tapping toggle twice returns to flat list', (tester) async {
      await tester.pumpWidget(_buildScreen(tasks: [_task()]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // First tap: switch to grouped.
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GroupedDailyView), findsOneWidget);

      // Second tap: back to flat.
      await tester.tap(find.byIcon(Icons.view_list_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GroupedDailyView), findsNothing);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── 12. Skip snackbar ───────────────────────────────────────────────────────

  group('SchedulerScreen — skip (swipe dismiss)', () {
    testWidgets('swiping a task card shows skip snackbar with Undo', (
      tester,
    ) async {
      final tasks = [_task(ref: 'Mishnah_Test_1')];

      await tester.pumpWidget(_buildScreen(tasks: tasks));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Dismissible wraps each card — drag end-to-start.
      await tester.drag(find.byType(Dismissible).first, const Offset(-600, 0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Task skipped until tomorrow'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── 13. No track-type labels ────────────────────────────────────────────────

  group('SchedulerScreen — no track-type labels', () {
    testWidgets('no "Personal"/"Standard"/"Custom"/"אישי" label shown', (
      tester,
    ) async {
      final tasks = [_task(ref: 'Ref_1'), _task(ref: 'Ref_2')];

      await tester.pumpWidget(_buildScreen(tasks: tasks));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.textContaining('אישי'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('no track-type label in empty state', (tester) async {
      await tester.pumpWidget(_buildScreen(tasks: const []));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── 14. Hebrew RTL smoke ────────────────────────────────────────────────────

  group('SchedulerScreen — Hebrew RTL smoke', () {
    testWidgets('screen pumps without error under he locale (tasks)', (
      tester,
    ) async {
      final tasks = [_task(ref: 'Ref_1'), _task(ref: 'Ref_2')];

      await tester.pumpWidget(
        _buildScreen(tasks: tasks, locale: const Locale('he')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('screen pumps without error under he locale (empty)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(tasks: const [], locale: const Locale('he')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── 15. AUD-scheduler-01: lazy-build the grouped view (PF-2) ───────────────
  //
  // GroupedDailyView previously built every DailyTaskCard up front via
  // `List.generate(tasks.length, ...)` fed into a non-lazy `ExpansionTile`
  // inside a plain `ListView(children: ...)`. A lapsed user (the app's own
  // core scenario) can accumulate a large, unbounded overdue backlog across
  // curricula — this regression guards that only the on-screen cards are
  // realized, matching the already-lazy flat (_TaskList / ListView.builder)
  // path, never every card up front.

  group('SchedulerScreen — AUD-scheduler-01: grouped view windowing', () {
    testWidgets('grouped view realizes only the initial viewport worth of '
        'DailyTaskCards for a ~205-task backlog across 3 curricula, matching '
        'the already-lazy flat list path — never all ~205', (tester) async {
      final tasks = [
        for (var i = 0; i < 70; i++)
          _task(
            curriculum: CurriculumId.mishnayos,
            ref: 'Mishnah_Berakhot_$i',
            isOverdue: true,
            priority: DailyTaskPriority.overdueProgram,
          ),
        for (var i = 0; i < 70; i++)
          _task(
            curriculum: CurriculumId.bavli,
            ref: 'Bavli_Berakhot_$i',
            isOverdue: true,
            priority: DailyTaskPriority.overdueProgram,
          ),
        for (var i = 0; i < 65; i++)
          _task(
            curriculum: CurriculumId.chumash,
            ref: 'Chumash_Bereshit_$i',
            isOverdue: true,
            priority: DailyTaskPriority.overdueProgram,
          ),
      ];
      expect(tasks.length, 205);

      // Baseline: the already-compliant flat (_TaskList / ListView.builder)
      // path never realizes all ~205 cards for the same backlog/viewport.
      await tester.pumpWidget(_buildScreen(tasks: tasks));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final flatRealized = tester.widgetList(find.byType(DailyTaskCard)).length;
      expect(
        flatRealized,
        lessThan(tasks.length),
        reason:
            'sanity check: the compliant flat _TaskList path must not '
            'realize every card either — if this fails the fixture/'
            'harness itself is wrong, not GroupedDailyView',
      );

      // Switch to grouped view — the view under test.
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GroupedDailyView), findsOneWidget);

      final groupedRealized = tester
          .widgetList(find.byType(DailyTaskCard))
          .length;

      // The whole point of AUD-scheduler-01: grouped view must not
      // realize every DailyTaskCard up front for an unbounded backlog.
      expect(
        groupedRealized,
        lessThan(tasks.length),
        reason:
            'GroupedDailyView must lazily build only the on-screen '
            'DailyTaskCards for an unbounded (~205-task) backlog spread '
            'across curricula, not all of them up front (PF-2 / '
            'AUD-scheduler-01)',
      );
      // Windowed to roughly the same viewport as the flat list — not just
      // "less than 205" (a very loose bound would tolerate a partial fix
      // that still over-realizes, e.g. capping to 100 instead of a real
      // viewport window).
      expect(
        groupedRealized,
        lessThanOrEqualTo(flatRealized + 10),
        reason:
            'grouped view should realize a comparable number of cards to '
            'the already-lazy flat list for the same viewport — a much '
            'larger count would indicate it is still over-building '
            '(e.g. one full curriculum section eagerly expanded)',
      );

      await _tearDown(tester);
    });
  });
}
