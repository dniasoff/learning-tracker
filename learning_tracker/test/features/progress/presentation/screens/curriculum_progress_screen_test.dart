/// Widget tests for the Curriculum Progress screen over the engine's
/// LearnerState (DNI-474).
///
/// Covers:
///   * `OverallStatsCard` headline rows: Track progress from the shared
///     dual-progress metric, Lifetime from the engine's learnt set;
///   * the pace badge renders the engine projection with the
///     "Pace tracks track learning only." caption;
///   * hierarchy rows show the distinct learnt count (repeats once) and the
///     "N chazaros" stage vocabulary;
///   * the settings gear tooltip and the AppBar track title;
///   * a learner-state failure renders the shared AppErrorView.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/curriculum_progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/learner_state/progress_fixtures.dart';

class _Stages extends Fake implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(CurriculumId c) async =>
      const [
        StageDefinition(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 1,
          stageName: 'Learned',
          delayDays: 0,
          isDefault: true,
        ),
        StageDefinition(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
          isDefault: true,
        ),
      ];
}

class _UseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _Router extends Fake implements StackRouter {}

const _metric = TrackDualProgressMetric(
  trackLabel: 'Mishnayos',
  curriculumId: CurriculumId.mishnayos,
  currentCyclePercentage: 0.25,
  lifetimePercentage: 0.9,
  isProgramTrack: false,
);

Widget _pump(
  List<LearningEvent> events, {
  List<TrackDualProgressMetric> metrics = const [_metric],
  String? customName,
  Projection? projection,
  Locale locale = const Locale('en'),
  Stream<LearnerState>? states,
}) => ProviderScope(
  overrides: [
    ...(states == null
        ? progressOverrides(progressState(events))
        : progressOverrides(null, states: states)),
    useHebrewTermsProvider.overrideWith(_UseHebrewTerms.new),
    stageDefinitionRepositoryProvider.overrideWith((ref, c) => _Stages()),
    trackDualProgressMetricsProvider.overrideWith((ref) async => metrics),
    trackCustomNameProvider.overrideWith((ref, c) async => customName),
    curriculumPaceStatusProvider.overrideWith((ref, c) async => projection),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: StackRouterScope(
      controller: _Router(),
      stateHash: 0,
      child: const CurriculumProgressScreen(curriculumId: 'mishnayos'),
    ),
  ),
);

void main() {
  final learning = [
    progressLearn(1, 'Mishnah Berakhot 1:1', stage: 1),
    progressLearn(2, 'Mishnah Berakhot 1:1', minutes: 1, stage: 2),
    progressGround(3, 'Mishnah Peah', 'masechta', minutes: 2),
  ];

  testWidgets('Track progress comes from the shared dual metric; Lifetime '
      'from the engine learnt set', (tester) async {
    await tester.pumpWidget(_pump(learning));
    await tester.pumpAndSettle();

    final card = find.byType(OverallStatsCard);
    expect(find.text('Track progress'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('25%')),
      findsOneWidget,
    );
    // 3 of 9 fixture leaves learnt (Berakhot 1:1 once, Peah by backfill).
    expect(find.text('Lifetime'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('33.3%')),
      findsOneWidget,
    );
    expect(find.text('Completed all stages'), findsOneWidget);
  });

  testWidgets('the pace badge renders the engine projection with the '
      'track-learning caption', (tester) async {
    await tester.pumpWidget(
      _pump(
        learning,
        projection: const Projection(status: ProjectionStatus.behindPace),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Behind pace'), findsOneWidget);
    expect(find.text('Pace tracks track learning only.'), findsOneWidget);
  });

  testWidgets('hierarchy rows count distinct learnt leaves and name the '
      'chazaros stage', (tester) async {
    await tester.pumpWidget(_pump(learning));
    await tester.pumpAndSettle();
    // Zeraim: Berakhot 1:1 (twice) + Peah 1:1, 1:2 → 3 of 7.
    expect(find.textContaining('3/7'), findsOneWidget);
    expect(find.textContaining('chazaros'), findsWidgets);
  });

  testWidgets('the settings gear tooltip comes from l10n', (tester) async {
    await tester.pumpWidget(_pump(learning, locale: const Locale('he')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('הגדרות קורס הלימוד'), findsOneWidget);
    expect(find.byTooltip('Curriculum settings'), findsNothing);
  });

  testWidgets('a custom track name titles the AppBar', (tester) async {
    await tester.pumpWidget(_pump(learning, customName: 'My Shas Journey'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('My Shas Journey'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a custom name the curriculum label titles the AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(learning, metrics: const []));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Mishnayos'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a learner-state failure renders the shared AppErrorView with '
      'retry', (tester) async {
    await tester.pumpWidget(
      _pump(learning, states: Stream.error(StateError('engine'))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
