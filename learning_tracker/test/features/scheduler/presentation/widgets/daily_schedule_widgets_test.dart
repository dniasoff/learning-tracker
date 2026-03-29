import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/services/daily_schedule_composer.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_schedule_header.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/grouped_daily_view.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/unified_daily_view.dart';

DailyTask _task(
  CurriculumId curriculum, {
  String ref = 'ref',
  int stageOrder = 1,
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  bool isOverdue = false,
}) {
  return DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: ref,
    stageOrder: stageOrder,
    stageDefinitionId: stageOrder,
    priority: priority,
    isOverdue: isOverdue,
    reason: 'test',
    stageName: stageOrder == 1 ? 'Learn' : 'Chazara $stageOrder',
  );
}

ComposedDailySchedule _schedule(List<DailyTask> tasks, String summary) {
  return ComposedDailySchedule(tasks: tasks, summary: summary);
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('UnifiedDailyView', () {
    testWidgets('renders single prioritized list with curriculum badge', (
      tester,
    ) async {
      final schedule = _schedule([
        _task(CurriculumId.mishnayos, ref: 'Mishnah_Berakhot_1.0'),
        _task(CurriculumId.bavli, ref: 'Bavli_Berakhot_2a'),
      ], '2 tasks across 2 curricula today');

      await tester.pumpWidget(
        _wrap(
          UnifiedDailyView(
            schedule: schedule,
            onTaskDismissed: (_) {},
            onTaskCompleted: (_) {},
          ),
        ),
      );

      // Both tasks should be visible
      expect(find.text('Mishnah Berakhot 1.0'), findsOneWidget);
      expect(find.text('Bavli Berakhot 2a'), findsOneWidget);
      // Curriculum badges
      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('תלמוד בבלי'), findsOneWidget);
    });

    testWidgets('shows empty message for no tasks', (tester) async {
      final schedule = _schedule([], '0 tasks across 0 curricula today');

      await tester.pumpWidget(
        _wrap(
          UnifiedDailyView(
            schedule: schedule,
            onTaskDismissed: (_) {},
            onTaskCompleted: (_) {},
          ),
        ),
      );

      expect(find.text('No tasks for today'), findsOneWidget);
    });
  });

  group('GroupedDailyView', () {
    testWidgets(
      'renders tasks organized by curriculum with collapsible sections',
      (tester) async {
        final schedule = _schedule([
          _task(CurriculumId.mishnayos, ref: 'Mishnah_1'),
          _task(CurriculumId.bavli, ref: 'Bavli_1'),
          _task(CurriculumId.bavli, ref: 'Bavli_2'),
        ], '3 tasks across 2 curricula today');

        await tester.pumpWidget(
          _wrap(
            GroupedDailyView(
              schedule: schedule,
              onTaskDismissed: (_, __) {},
              onTaskCompleted: (_, __) {},
            ),
          ),
        );

        // Curriculum group headers with counts
        expect(find.text('תלמוד בבלי (2)'), findsOneWidget);
        expect(find.text('משניות (1)'), findsOneWidget);
      },
    );
  });

  group('DailyScheduleHeader', () {
    testWidgets('displays summary text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DailyScheduleHeader(
            summary: '15 tasks across 3 curricula today',
            isGroupedView: false,
            onToggleView: () {},
          ),
        ),
      );

      expect(find.text('15 tasks across 3 curricula today'), findsOneWidget);
    });

    testWidgets('toggle switches between views', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        _wrap(
          DailyScheduleHeader(
            summary: 'test',
            isGroupedView: false,
            onToggleView: () => toggled = true,
          ),
        ),
      );

      // Find the toggle button and tap it
      await tester.tap(find.byType(IconButton));
      expect(toggled, isTrue);
    });

    testWidgets('summary updates reactively', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DailyScheduleHeader(
            summary: '10 tasks across 2 curricula today',
            isGroupedView: false,
            onToggleView: () {},
          ),
        ),
      );

      expect(find.text('10 tasks across 2 curricula today'), findsOneWidget);

      // Rebuild with updated summary
      await tester.pumpWidget(
        _wrap(
          DailyScheduleHeader(
            summary: '9 tasks across 2 curricula today',
            isGroupedView: false,
            onToggleView: () {},
          ),
        ),
      );

      expect(find.text('9 tasks across 2 curricula today'), findsOneWidget);
      expect(find.text('10 tasks across 2 curricula today'), findsNothing);
    });
  });
}
