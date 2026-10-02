// Story 2.11 (DNI-502) T3: today against the engine's daily target, with
// warm encouragement and the curriculum streak (UX-DR-67), and the bonus
// copy for a zero target (UX-DR-96).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/learner_today_card.dart';

import '../../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  LearnerState? state,
  bool parent = false,
}) async {
  // A fresh ProviderScope per pump, so a second pump in one test reads its
  // own overrides.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    pumpApp(
      theme: AppTheme.lightTheme(),
      overrides: forecastOverrides(parent: parent, state: state),
      child: const Scaffold(
        body: SingleChildScrollView(child: LearnerTodaySection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LearnerState _today({
  required int done,
  int? target,
  int streak = 0,
  ProjectionStatus status = ProjectionStatus.behindPace,
}) => forecastState([
  forecastCurriculumState(
    projection: Projection(
      status: status,
      deadline: '2029-09-10',
      newlyLearntToday: done,
    ),
    dailyTarget: target,
    streak: CurriculumStreak(current: streak, best: streak),
  ),
]);

void main() {
  testWidgets('partway: "Today 3 of 4 done" and a forward-looking line', (
    tester,
  ) async {
    await _pump(tester, state: _today(done: 3, target: 4, streak: 6));
    expect(find.text('Today 3 of 4 done'), findsOneWidget);
    expect(
      find.text("Great pace! Only one left to finish today's goal."),
      findsOneWidget,
    );
    expect(find.text('6-day streak'), findsOneWidget);
  });

  testWidgets('several left', (tester) async {
    await _pump(tester, state: _today(done: 1, target: 4));
    expect(
      find.text("Great pace! Only 3 left to finish today's goal."),
      findsOneWidget,
    );
    // No streak yet: no streak line.
    expect(find.byKey(const Key('learnerTodayStreak')), findsNothing);
  });

  testWidgets('nothing yet and goal done', (tester) async {
    await _pump(tester, state: _today(done: 0, target: 4));
    expect(find.text('Today 0 of 4 done'), findsOneWidget);
    expect(find.text("Every step counts — let's begin!"), findsOneWidget);
    await _pump(tester, state: _today(done: 5, target: 4));
    expect(find.text('Today 5 of 4 done'), findsOneWidget);
    expect(find.text("Today's goal is done — wonderful!"), findsOneWidget);
  });

  testWidgets('a zero target is the bonus copy, not an error (AC-4)', (
    tester,
  ) async {
    await _pump(tester, state: _today(done: 0, target: 0));
    expect(
      find.text('All covered — any extra learning is a bonus.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('learnerTodayEncouragement')), findsNothing);
    expect(find.byType(InlineAsyncError), findsNothing);
  });

  testWidgets('no target: today\'s count only', (tester) async {
    await _pump(tester, state: _today(done: 2));
    expect(find.text('2 learnt today'), findsOneWidget);
  });

  testWidgets('never shows a status, even when the engine is behind pace', (
    tester,
  ) async {
    await _pump(tester, state: _today(done: 1, target: 4));
    expect(find.textContaining('Behind'), findsNothing);
    expect(find.textContaining('Projected'), findsNothing);
  });

  testWidgets('a load error is an inline retry', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        theme: AppTheme.lightTheme(),
        // No learner-state override: the C0 stub fails the read.
        overrides: forecastOverrides(),
        child: const Scaffold(body: LearnerTodaySection()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InlineAsyncError), findsOneWidget);
  });
}
