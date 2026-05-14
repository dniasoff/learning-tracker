import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  // DNI-328 flipped the Hebrew-terms default to false. These tests assert on
  // Hebrew labels, so seed the preference to true for the default profile.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hebrew_terms_script_p0': true,
    });
  });

  group('DailyTaskCard', () {
    testWidgets('renders task content and curriculum badge', (tester) async {
      final task = _task();

      await tester.pumpWidget(
        _wrap(
          DailyTaskCard(task: task, onDismissed: () {}, onCompleted: () {}),
        ),
      );
      // Allow the core/preferences Hebrew-terms async load to propagate.
      await tester.pumpAndSettle();

      // Content ref displayed (underscores replaced with spaces)
      expect(find.text('Mishnah Berakhot 1.1'), findsOneWidget);
      // Curriculum badge
      expect(find.text('משניות'), findsOneWidget);
      // Stage label: stageOrder 1 shows 'Learn'
      expect(find.text('Learn'), findsOneWidget);
    });

    testWidgets('displays XP for effort', (tester) async {
      // DNI-376 removed the +XP badge from DailyTaskCard.
      // This test verifies the card still renders without the badge.
      final task = _task(estimatedEffortMinutes: 5);

      await tester.pumpWidget(
        _wrap(
          DailyTaskCard(task: task, onDismissed: () {}, onCompleted: () {}),
        ),
      );

      // Card renders without XP badge (badge was removed in DNI-376).
      expect(find.byType(DailyTaskCard), findsOneWidget);
      expect(find.text('+15 XP'), findsNothing);
    });

    testWidgets('shows overdue badge when task is overdue', (tester) async {
      final task = _task(
        isOverdue: true,
        priority: DailyTaskPriority.overdueChazara,
        stageOrder: 2,
      );

      await tester.pumpWidget(
        _wrap(
          DailyTaskCard(task: task, onDismissed: () {}, onCompleted: () {}),
        ),
      );

      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('does not show overdue badge for non-overdue task', (
      tester,
    ) async {
      final task = _task(isOverdue: false);

      await tester.pumpWidget(
        _wrap(
          DailyTaskCard(task: task, onDismissed: () {}, onCompleted: () {}),
        ),
      );

      expect(find.text('Overdue'), findsNothing);
    });

    testWidgets('has swipe-to-skip interaction', (tester) async {
      final task = _task();

      await tester.pumpWidget(
        _wrap(
          DailyTaskCard(task: task, onDismissed: () {}, onCompleted: () {}),
        ),
      );

      // Dismissible wraps the card for swipe-to-skip
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('swipe dismiss calls onDismissed', (tester) async {
      var dismissed = false;
      final task = _task();

      await tester.pumpWidget(
        _wrap(
          DailyTaskCard(
            task: task,
            onDismissed: () => dismissed = true,
            onCompleted: () {},
          ),
        ),
      );

      // Swipe end to start (right to left)
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('shows chazara stage name for non-first stage', (tester) async {
      final task = _task(stageOrder: 3, estimatedEffortMinutes: 3);

      await tester.pumpWidget(
        _wrap(
          DailyTaskCard(task: task, onDismissed: () {}, onCompleted: () {}),
        ),
      );

      expect(find.text('Chazara 3'), findsOneWidget);
      // DNI-376: XP badge removed from DailyTaskCard.
      expect(find.text('+9 XP'), findsNothing);
    });
  });
}
