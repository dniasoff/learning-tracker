import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart'
    show goalRepositoryProvider;
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/goal_setup_launcher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _Goals extends Mock implements GoalRepository {}

GoalEntity _goal(DateTime createdAt, String description) => GoalEntity(
  curriculumId: CurriculumId.mishnayos,
  targetPercent: 100,
  goalType: 'pace',
  paceValue: 1,
  pacePeriod: 'per_week',
  description: description,
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  setUpAll(() => registerFallbackValue(CurriculumId.mishnayos));

  testWidgets('the latest goal is the most recently created one', (
    tester,
  ) async {
    final goals = _Goals();
    when(() => goals.getGoals(CurriculumId.mishnayos)).thenAnswer(
      (_) async => [
        _goal(DateTime.utc(2026), 'old'),
        _goal(DateTime.utc(2026, 5), 'new'),
      ],
    );
    GoalEntity? latest;
    await tester.pumpWidget(
      pumpApp(
        overrides: [goalRepositoryProvider.overrideWithValue(goals)],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => latest = await latestCurriculumGoal(
              ref,
              CurriculumId.mishnayos,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(latest?.description, 'new');
  });

  testWidgets('opens the existing goal setup for the same curriculum', (
    tester,
  ) async {
    final goals = _Goals();
    when(() => goals.getGoals(any())).thenAnswer((_) async => []);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          goalRepositoryProvider.overrideWithValue(goals),
          scopedItemCountProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => 120),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                openCurriculumGoalSetup(context, ref, CurriculumId.mishnayos),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump();
    final screen = tester.widget<GoalSetupScreen>(
      find.byType(GoalSetupScreen, skipOffstage: false),
    );
    expect(screen.curriculumId, CurriculumId.mishnayos);
    expect(screen.existingGoal, isNull);
    expect(screen.totalItems, 120);
  });
}
