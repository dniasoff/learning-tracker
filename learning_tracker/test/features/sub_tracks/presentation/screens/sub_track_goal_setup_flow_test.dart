/// Story 2.4 (DNI-495) AC-6: the no-deadline link opens the existing goal
/// setup for the same curriculum and saves through the governed
/// `LearningCommands.applyGovernedChange` (C0), never the legacy goal
/// repository; a refused or impossible save is reported as failed.
@Tags(['sub_tracks'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/governed_goal_change.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_goal_setup_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_harness.dart';

void main() {
  late SubTrackHarness h;
  SubTrackGoalSetupOutcome? outcome;

  setUp(() {
    outcome = null;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async => h.dispose());

  Future<void> pumpFlow(
    WidgetTester tester, {
    bool withCommands = true,
    bool sessionLive = true,
  }) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          ...h.overrides(commands: withCommands, parentSession: null),
          switchableParentSessionOverride(),
          if (!withCommands)
            learningCommandsProvider.overrideWith((ref) async => null),
          scopedItemCountProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => 120),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => outcome = await openSubTrackGoalSetup(
              context,
              ref,
              CurriculumId.mishnayos,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    if (!sessionLive) setParentSession(tester, find.text('go'), live: false);
    await tester.tap(find.text('go'));
    // The in-memory intent store answers in the root zone.
    await settleCommands(tester);
    await tester.pumpAndSettle();
  }

  GoalSetupScreen screen(WidgetTester tester) => tester.widget<GoalSetupScreen>(
    find.byType(GoalSetupScreen, skipOffstage: false),
  );

  Future<void> complete(WidgetTester tester, GoalEntity? result) async {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pop<GoalEntity>(result);
    await settleCommands(tester);
    await tester.pumpAndSettle();
  }

  GoalEntity deadline(DateTime date) => GoalEntity(
    curriculumId: CurriculumId.mishnayos,
    targetDate: date,
    createdAt: DateTime.utc(2026, 10, 2),
  );

  testWidgets('opens the existing goal setup for the same curriculum', (
    tester,
  ) async {
    h = SubTrackHarness();
    await pumpFlow(tester);
    expect(screen(tester).curriculumId, CurriculumId.mishnayos);
    expect(screen(tester).existingGoal, isNull);
    expect(screen(tester).totalItems, 120);
    await complete(tester, null);
    expect(outcome, SubTrackGoalSetupOutcome.cancelled);
    expect(h.commands.governed, isEmpty);
  });

  testWidgets('a chosen deadline goes through applyGovernedChange', (
    tester,
  ) async {
    h = SubTrackHarness();
    await pumpFlow(tester);
    await complete(tester, deadline(DateTime(2028, 6, 1)));
    expect(outcome, SubTrackGoalSetupOutcome.saved);
    expect(h.commands.governed, [
      GovernedAction([
        const GovernedEntityChange(
          entity: GovernedEntity.goal,
          entityId: 'mishnayos_deadline',
          docs: [
            GovernedDocPatch(
              collection: 'goals',
              docId: 'mishnayos_deadline',
              fields: {
                'goal_type': 'deadline',
                'curriculum_id': 'mishnayos',
                'target_date': '2028-06-01',
              },
            ),
          ],
        ),
      ]),
    ]);
  });

  testWidgets(
    'a pace goal on a curriculum without a unit picker saves with the leaf '
    'granularity',
    (tester) async {
      h = SubTrackHarness();
      await pumpFlow(tester);
      // Drive the real goal screen: Mishnayos has no granularity picker.
      await tester.tap(find.text('Pace'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await settleCommands(tester);
      await tester.pumpAndSettle();
      expect(outcome, SubTrackGoalSetupOutcome.saved);
      expect(h.commands.governed, hasLength(1));
      final fields =
          h.commands.governed.single.changes.single.docs.single.fields;
      expect(fields['goal_type'], 'pace');
      expect(fields['pace_unit'], 'per_day');
      expect(fields['pace_value'], isA<num>());
      expect(fields['pace_granularity'], kLeafPaceGranularity);
    },
  );

  testWidgets('a refused governed save is reported as failed', (tester) async {
    h = SubTrackHarness();
    h.commands.nextGovernedResult = const CaptureResult.onlineRequired();
    await pumpFlow(tester);
    await complete(tester, deadline(DateTime(2028, 6, 1)));
    expect(outcome, SubTrackGoalSetupOutcome.failed);
    expect(h.commands.governed, hasLength(1));
  });

  testWidgets('without commands the goal screen never opens', (tester) async {
    h = SubTrackHarness();
    await pumpFlow(tester, withCommands: false);
    await tester.pumpAndSettle();
    expect(find.byType(GoalSetupScreen, skipOffstage: false), findsNothing);
    expect(outcome, SubTrackGoalSetupOutcome.failed);
  });

  group('AC-3: a governed goal write needs a live parent session', () {
    testWidgets('without a parent session the goal screen never opens', (
      tester,
    ) async {
      h = SubTrackHarness();
      await pumpFlow(tester, sessionLive: false);
      expect(find.byType(GoalSetupScreen, skipOffstage: false), findsNothing);
      expect(outcome, SubTrackGoalSetupOutcome.failed);
      expect(h.commands.governed, isEmpty);
    });

    testWidgets('a session that expires between render and save refuses the '
        'save', (tester) async {
      h = SubTrackHarness();
      await pumpFlow(tester);
      expect(find.byType(GoalSetupScreen), findsOneWidget);
      // The PIN session locks while the goal screen is open; the save
      // arrives before the next frame.
      setParentSession(tester, find.byType(GoalSetupScreen), live: false);
      await complete(tester, deadline(DateTime(2028, 6, 1)));
      expect(outcome, SubTrackGoalSetupOutcome.failed);
      expect(h.commands.governed, isEmpty);
    });

    testWidgets('a locked session hides the goal screen and keeps its values', (
      tester,
    ) async {
      h = SubTrackHarness();
      await pumpFlow(tester);
      await tester.tap(find.text('Pace'));
      await tester.pumpAndSettle();
      final before = tester.element(find.byType(GoalSetupScreen));

      setParentSession(tester, find.byType(GoalSetupScreen), live: false);
      await tester.pumpAndSettle();
      // Not usable: nothing on it can be seen, tapped or submitted...
      expect(find.byType(GoalSetupScreen), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(
        find.byKey(const ValueKey('subTrackParentSessionLocked')),
        findsOneWidget,
      );
      // ...but it stays mounted with what the parent entered.
      expect(find.byType(GoalSetupScreen, skipOffstage: false), findsOneWidget);

      setParentSession(
        tester,
        find.byType(GoalSetupScreen, skipOffstage: false),
        live: true,
      );
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(GoalSetupScreen)), same(before));

      // A save while the session is live again goes through.
      await tester.tap(find.byType(FilledButton));
      await settleCommands(tester);
      await tester.pumpAndSettle();
      expect(outcome, SubTrackGoalSetupOutcome.saved);
      expect(h.commands.governed, hasLength(1));
      expect(
        h
            .commands
            .governed
            .single
            .changes
            .single
            .docs
            .single
            .fields['goal_type'],
        'pace',
      );
    });
  });

  test('a live pace goal prefills the goal screen', () {
    final entity = goalEntityOf(
      CurriculumId.mishnayos,
      const CurriculumGoals(
        pace: PaceGoal(
          curriculumId: 'mishnayos',
          paceValue: 2,
          paceUnit: 'per_week',
          paceGranularity: 'perek',
        ),
      ),
    )!;
    expect(entity.goalType, 'pace');
    expect(entity.paceValue, 2);
    expect(entity.pacePeriod, 'per_week');
    expect(entity.paceGranularityKey, 'perek');
  });

  group('a fractional stored pace (1.5)', () {
    const stored = PaceGoal(
      curriculumId: 'mishnayos',
      paceValue: 1.5,
      paceUnit: 'per_week',
      paceGranularity: kLeafPaceGranularity,
    );
    const goals = CurriculumGoals(pace: stored);

    GoalEntity paceResult(int value, {String unit = 'per_week'}) => GoalEntity(
      curriculumId: CurriculumId.mishnayos,
      goalType: 'pace',
      paceValue: value,
      pacePeriod: unit,
      createdAt: DateTime.utc(2026),
    );

    GovernedAction? save(GoalEntity result) => governedGoalAction(
      curriculumId: 'mishnayos',
      choice: goalChoiceOf(result, prefilledPace: prefilledPaceOf(goals))!,
      current: goals,
      nowUtc: DateTime.utc(2026, 10, 2),
    );

    test(
      'round-trips untouched: the stored value is kept, nothing written',
      () {
        final prefill = goalEntityOf(CurriculumId.mishnayos, goals)!;
        expect(prefill.paceValue, 2);
        expect(
          goalChoiceOf(paceResult(2), prefilledPace: prefilledPaceOf(goals)),
          isA<PaceGoalChoice>().having((c) => c.value, 'value', 1.5),
        );
        expect(save(paceResult(2)), isNull);
      },
    );

    test('a changed value is written as entered', () {
      final fields = save(paceResult(3))!.changes.single.docs.single.fields;
      expect(fields, {'pace_value': 3});
    });

    test('a changed unit writes the entered value, not the stored one', () {
      final fields = save(
        paceResult(2, unit: 'per_day'),
      )!.changes.single.docs.single.fields;
      expect(fields, {'pace_value': 2, 'pace_unit': 'per_day'});
    });

    test('a live deadline prefill never keeps the stored pace', () {
      const both = CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: 'mishnayos',
          targetDate: '2028-06-01',
        ),
        pace: stored,
      );
      expect(prefilledPaceOf(both), isNull);
    });
  });
  test('a goal-screen result maps to a governed choice', () {
    expect(
      goalChoiceOf(deadline(DateTime(2028, 6, 1))),
      isA<DeadlineGoalChoice>().having(
        (c) => c.targetDate,
        'targetDate',
        '2028-06-01',
      ),
    );
    expect(
      goalChoiceOf(
        GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          goalType: 'pace',
          paceValue: 3,
          pacePeriod: 'per_day',
          createdAt: DateTime.utc(2026),
        ),
      ),
      isA<PaceGoalChoice>()
          .having((c) => c.value, 'value', 3)
          .having((c) => c.unit, 'unit', 'per_day')
          .having((c) => c.granularity, 'granularity', kLeafPaceGranularity),
    );
    expect(
      goalChoiceOf(
        GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          goalType: 'none',
          createdAt: DateTime.utc(2026),
        ),
      ),
      isA<NoGoalChoice>(),
    );
    expect(
      goalChoiceOf(
        GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          createdAt: DateTime.utc(2026),
        ),
      ),
      isNull,
    );
  });
}
