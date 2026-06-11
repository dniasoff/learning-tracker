import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/scheduler_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

DailyTask _task({
  CurriculumId curriculum = CurriculumId.mishnayos,
  String ref = 'Mishnah_Berakhot_1.1',
  int stageOrder = 1,
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  bool isOverdue = false,
  int estimatedEffortMinutes = 5,
}) {
  return DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: ref,
    stageOrder: stageOrder,
    stageDefinitionId: stageOrder,
    priority: priority,
    isOverdue: isOverdue,
    reason: 'test reason',
    stageName: stageOrder == 1 ? 'Learn' : 'Chazara $stageOrder',
    trackId: 1,
    trackLabel: 'Test Track',
    estimatedEffortMinutes: estimatedEffortMinutes,
  );
}

/// Wraps SchedulerScreen with overridden providers for isolated testing.
Widget _buildScreen({required List<DailyTask> tasks}) {
  return ProviderScope(
    overrides: [
      allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme(),
      home: const SchedulerScreen(),
    ),
  );
}

void main() {
  group('SchedulerScreen', () {
    testWidgets('shows empty state when no tasks', (tester) async {
      await tester.pumpWidget(_buildScreen(tasks: []));
      await tester.pumpAndSettle();

      expect(find.text('All caught up! Great work!'), findsOneWidget);
      expect(
        find.text('You have no tasks remaining for today.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.celebration_outlined), findsOneWidget);
    });

    testWidgets('renders task cards when tasks exist', (tester) async {
      final tasks = [
        _task(ref: 'Mishnah_Berakhot_1.1'),
        _task(curriculum: CurriculumId.bavli, ref: 'Bavli_Berakhot_2a'),
      ];

      await tester.pumpWidget(_buildScreen(tasks: tasks));
      await tester.pumpAndSettle();

      expect(find.byType(DailyTaskCard), findsNWidgets(2));
      expect(find.text('Mishnah Berakhot 1.1'), findsOneWidget);
      expect(find.text('Bavli Berakhot 2a'), findsOneWidget);
    });

    testWidgets('shows summary header with task count', (tester) async {
      final tasks = [
        _task(ref: 'Ref_1'),
        _task(ref: 'Ref_2'),
        _task(ref: 'Ref_3'),
      ];

      await tester.pumpWidget(_buildScreen(tasks: tasks));
      await tester.pumpAndSettle();

      expect(find.text('3 tasks today'), findsOneWidget);
    });

    testWidgets('shows singular text for single task', (tester) async {
      await tester.pumpWidget(_buildScreen(tasks: [_task()]));
      await tester.pumpAndSettle();

      // SCHED-GOAL-PLURAL-15: count==1 must say "task" not "tasks"
      // (localized via schedulerGoalTaskCount ICU plural).
      expect(find.text('1 task today'), findsOneWidget);
    });

    testWidgets('has view toggle button', (tester) async {
      await tester.pumpWidget(_buildScreen(tasks: [_task()]));
      await tester.pumpAndSettle();

      // The _GoalCard has an InkWell for toggling grouped/unified views
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('shows loading indicator while loading', (tester) async {
      final completer = Completer<List<DailyTask>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allDailyTasksProvider.overrideWith((ref) => completer.future),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme(),
            home: const SchedulerScreen(),
          ),
        ),
      );

      // Should show loading before settling
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to avoid pending timer issues
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allDailyTasksProvider.overrideWith(
              (ref) => Future<List<DailyTask>>.error('Test error'),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme(),
            home: const SchedulerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Error loading tasks'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('swipe dismiss shows snackbar with undo', (tester) async {
      final tasks = [_task(ref: 'Mishnah_Test_1')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme(),
            home: const SchedulerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe the task card
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Task skipped until tomorrow'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });
  });
}
