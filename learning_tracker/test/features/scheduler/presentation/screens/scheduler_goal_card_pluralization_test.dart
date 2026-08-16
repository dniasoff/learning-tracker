// ignore_for_file: deprecated_member_use
// Test-only: TestWidgetsFlutterBinding.instance.window.*TestValue is the only
// binding-level viewport-sizing API available in setUp (no tester there). It is
// functional and test-scoped, not production tech debt.
/// Regression test: SCHED-GOAL-PLURAL-15 / SCHED-GOAL-I18N-R2 — the scheduler
/// goal banner (`_GoalCard`) must be fully localized and correctly pluralized.
///
/// Before the R2 fix: `_GoalCard` hard-coded the English eyebrow "TODAY'S GOAL"
/// and the count text `'$count today ${count == 1 ? 'task' : 'tasks'}'`. Under
/// the Hebrew (he) UI locale the banner leaked English chrome.
///
/// After the fix: both strings come from ARB keys (`schedulerTodaysGoal`,
/// `schedulerGoalTaskCount`). English plural: "1 task today" / "3 tasks today".
/// Hebrew uses the dual: "משימה אחת היום" / "שתי משימות היום" / "{n} משימות היום",
/// and the eyebrow reads "היעד של היום" — no English in the he locale.
@Tags(['scheduler', 'l1', 'sched_goal_plural_15'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/scheduler_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

DailyTask _task({String ref = 'Mishnah_Berakhot_1.1'}) {
  return DailyTask(
    curriculumId: CurriculumId.mishnayos,
    contentItemSefariaRef: ref,
    stageOrder: 1,
    priority: DailyTaskPriority.newLearning,
    isOverdue: false,
    reason: 'test',
    stageName: 'Learn',
    trackLabel: 'Test Track',
    estimatedEffortMinutes: 5,
  );
}

Widget _buildScreen(
  List<DailyTask> tasks, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
      useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
    ],
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

  // ── SCHED-GOAL-PLURAL-15 (English pluralization, localized) ───────────────

  group('SCHED-GOAL-PLURAL-15: _GoalCard task-count pluralization (en)', () {
    testWidgets(
      'count == 1 shows singular "1 task today" (not "1 tasks today")',
      (tester) async {
        await tester.pumpWidget(_buildScreen([_task()]));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The singular form must say "task" not "tasks".
        expect(
          find.text('1 task today'),
          findsOneWidget,
          reason:
              'SCHED-GOAL-PLURAL-15: count==1 must produce "1 task today" via '
              'the ICU plural ARB key schedulerGoalTaskCount.',
        );
        // The plural form must NOT appear for a single task.
        expect(
          find.text('1 tasks today'),
          findsNothing,
          reason:
              'SCHED-GOAL-PLURAL-15: "1 tasks today" is ungrammatical; the '
              'ICU =1 branch must be selected for a single task.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('count == 0 hides the goal card (empty state shown)', (
      tester,
    ) async {
      // Edge case: zero tasks shows the empty-state, not _GoalCard.
      await tester.pumpWidget(_buildScreen([]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('0 tasks today'), findsNothing);
      expect(find.text('0 task today'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('count == 3 shows plural "3 tasks today"', (tester) async {
      await tester.pumpWidget(
        _buildScreen([
          _task(ref: 'Ref_1'),
          _task(ref: 'Ref_2'),
          _task(ref: 'Ref_3'),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('3 tasks today'),
        findsOneWidget,
        reason: 'count > 1 must produce the plural form "3 tasks today"',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('eyebrow uses localized "TODAY\'S GOAL" (en)', (tester) async {
      await tester.pumpWidget(_buildScreen([_task()]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("TODAY'S GOAL"), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── SCHED-GOAL-I18N-R2 (Hebrew banner is fully Hebrew) ────────────────────

  group('SCHED-GOAL-I18N-R2: _GoalCard is fully Hebrew in the he locale', () {
    testWidgets('eyebrow + count are Hebrew; no English chrome leaks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen([_task()], locale: const Locale('he')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The English eyebrow must NOT appear under the Hebrew UI locale.
      expect(
        find.text("TODAY'S GOAL"),
        findsNothing,
        reason:
            'SCHED-GOAL-I18N-R2: the hard-coded English eyebrow leaked into '
            'the Hebrew banner before the fix.',
      );
      // The localized Hebrew eyebrow must be present.
      expect(find.text('היעד של היום'), findsOneWidget);

      // count == 1 → Hebrew singular dual form.
      expect(
        find.text('משימה אחת היום'),
        findsOneWidget,
        reason: 'SCHED-GOAL-I18N-R2: count==1 must render the Hebrew singular.',
      );
      // No English count text anywhere in the Hebrew banner.
      expect(find.text('1 task today'), findsNothing);
      expect(find.text('1 today task'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('count == 2 uses the Hebrew dual "שתי משימות היום"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen([
          _task(ref: 'Ref_1'),
          _task(ref: 'Ref_2'),
        ], locale: const Locale('he')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('שתי משימות היום'),
        findsOneWidget,
        reason:
            'SCHED-GOAL-I18N-R2: Hebrew has a dual — count==2 must use the '
            'two{...} ICU branch, not the plural "other" form.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
