import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
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
    priority: priority,
    isOverdue: isOverdue,
    reason: 'test reason',
    stageName: stageOrder == 1 ? 'Learn' : 'Chazara $stageOrder',
    trackLabel: 'Test Track',
    estimatedEffortMinutes: estimatedEffortMinutes,
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      // Force English mode so resolveStoredStageName returns English stage
      // names (e.g. "Learn", "Chazara 3") regardless of SharedPreferences.
      useHebrewTermsProvider.overrideWithValue(false),
      // No daf grouping in these card tests (and avoid the DB-backed lookup):
      // an empty set means the card never collapses the amud label to a daf.
      coarsePacedTrackIdsProvider.overrideWith(
        (ref) async => const <CurriculumId>{},
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  // useHebrewTermsProvider is overridden to false in _wrap(), so stage names
  // resolve to English. SharedPreferences mock is kept empty (default).
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DailyTaskCard', () {
    testWidgets('renders task content and curriculum badge', (tester) async {
      final task = _task();

      await tester.pumpWidget(
        _wrap(DailyTaskCard(task: task, onDismissed: () {})),
      );
      // Allow the core/preferences Hebrew-terms async load to propagate.
      await tester.pumpAndSettle();

      // Content ref displayed (underscores replaced with spaces)
      expect(find.text('Mishnah Berakhot 1.1'), findsOneWidget);
      // Curriculum badge — English mode (useHebrew=false) renders displayNameEn.
      expect(find.text('Mishnayos'), findsOneWidget);
      // Stage label: stageOrder 1 shows 'Limud'. IL-5 normalised the stage-0
      // display name from the legacy DB key "Learn" to the canonical
      // transliteration "Limud" (matching DomainTermLabels.limud) in English
      // mode; the DB-stored stageName ("Learn") is unchanged.
      expect(find.text('Limud'), findsOneWidget);
    });

    testWidgets('displays XP for effort', (tester) async {
      // DNI-376 removed the +XP badge from DailyTaskCard.
      // This test verifies the card still renders without the badge.
      final task = _task(estimatedEffortMinutes: 5);

      await tester.pumpWidget(
        _wrap(DailyTaskCard(task: task, onDismissed: () {})),
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
        _wrap(DailyTaskCard(task: task, onDismissed: () {})),
      );

      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('does not show overdue badge for non-overdue task', (
      tester,
    ) async {
      final task = _task(isOverdue: false);

      await tester.pumpWidget(
        _wrap(DailyTaskCard(task: task, onDismissed: () {})),
      );

      expect(find.text('Overdue'), findsNothing);
    });

    testWidgets('has swipe-to-skip interaction', (tester) async {
      final task = _task();

      await tester.pumpWidget(
        _wrap(DailyTaskCard(task: task, onDismissed: () {})),
      );

      // Dismissible wraps the card for swipe-to-skip
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('swipe dismiss calls onDismissed', (tester) async {
      var dismissed = false;
      final task = _task();

      await tester.pumpWidget(
        _wrap(DailyTaskCard(task: task, onDismissed: () => dismissed = true)),
      );

      // Swipe end to start (right to left)
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('shows chazara stage name for non-first stage', (tester) async {
      final task = _task(stageOrder: 3, estimatedEffortMinutes: 3);

      await tester.pumpWidget(
        _wrap(DailyTaskCard(task: task, onDismissed: () {})),
      );

      expect(find.text('Chazara 3'), findsOneWidget);
      // DNI-376: XP badge removed from DailyTaskCard.
      expect(find.text('+9 XP'), findsNothing);
    });
  });
}
