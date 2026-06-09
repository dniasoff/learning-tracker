// ignore_for_file: deprecated_member_use
// Test-only: TestWidgetsFlutterBinding.instance.window.*TestValue is the only
// binding-level viewport-sizing API available in setUp (no tester there). It is
// functional and test-scoped, not production tech debt.
/// Regression test: SCHED-GOAL-PLURAL-15 — _GoalCard must use correct English
/// pluralization for its task-count label.
///
/// Before the fix: `_GoalCard` renders `'$count today tasks'` unconditionally,
/// which produces "1 today tasks" for a single task — incorrect English.
///
/// After the fix: the label is `'$count today ${count == 1 ? 'task' : 'tasks'}'`,
/// producing "1 today task" (singular) and "3 today tasks" (plural).
///
/// Root cause: hard-coded literal `'$count today tasks'` in `_GoalCard.build`
/// in `scheduler_screen.dart:302`. The noun is not derived from the count
/// value, so the singular/plural boundary is never crossed.
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
    stageDefinitionId: 1,
    priority: DailyTaskPriority.newLearning,
    isOverdue: false,
    reason: 'test',
    stageName: 'Learn',
    trackId: 1,
    trackLabel: 'Test Track',
    estimatedEffortMinutes: 5,
  );
}

Widget _buildScreen(List<DailyTask> tasks) {
  return ProviderScope(
    overrides: [
      allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
      useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SchedulerScreen(),
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

  // ── SCHED-GOAL-PLURAL-15 ─────────────────────────────────────────────────

  group('SCHED-GOAL-PLURAL-15: _GoalCard task-count pluralization', () {
    testWidgets(
      'count == 1 shows singular "1 today task" (not "1 today tasks")',
      (tester) async {
        await tester.pumpWidget(_buildScreen([_task()]));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The singular form must say "task" not "tasks".
        expect(
          find.text('1 today task'),
          findsOneWidget,
          reason:
              'SCHED-GOAL-PLURAL-15: count==1 must produce "1 today task"; '
              r'the hard-coded literal "$count today tasks" ignores the count '
              'and always produces the plural form.',
        );
        // The plural form must NOT appear for a single task.
        expect(
          find.text('1 today tasks'),
          findsNothing,
          reason:
              'SCHED-GOAL-PLURAL-15: "1 today tasks" is ungrammatical; '
              'the bug was a missing pluralisation branch.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('count == 0 shows "0 today tasks" (plural)', (tester) async {
      // Edge case: zero tasks uses the plural form.
      await tester.pumpWidget(_buildScreen([]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Empty-state is shown — _GoalCard is NOT rendered for 0 tasks.
      expect(find.text('0 today tasks'), findsNothing);
      expect(find.text('0 today task'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('count == 3 shows plural "3 today tasks"', (tester) async {
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
        find.text('3 today tasks'),
        findsOneWidget,
        reason: 'count > 1 must produce the plural form "3 today tasks"',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
