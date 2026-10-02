// DNI-474 AC-3: the progress, lifetime and Browse surfaces show the
// engine's distinct learnt count (FR-14) and every corpus node's
// empty / partial / complete state (FR-15) through a tristate checkbox, a
// count, a semantics label and a 12% tint — repeats never inflate them,
// learning from any source updates them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/curriculum_progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/curriculum_breakdown_list.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/learnt_tri_state.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _NoStages extends Fake implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(CurriculumId c) async =>
      const [];
}

class _English extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// One learnt mishna of Berakhot, learnt three times (live, repeat and a
/// sub-track chazara), and Peah complete by a before-tracking mark.
final _base = <LearningEvent>[
  progressLearn(1, 'Mishnah Berakhot 1:1'),
  progressLearn(2, 'Mishnah Berakhot 1:1', minutes: 1),
  engineLearn(3, 'Mishnah Berakhot 1:1', minutes: 2, source: engineUlid(90)),
  progressGround(4, 'Mishnah Peah', 'masechta', minutes: 3),
];

Widget _app(LearnerState state, Widget child) => pumpApp(
  overrides: [
    ...progressOverrides(state),
    useHebrewTermsProvider.overrideWith(_English.new),
    stageDefinitionRepositoryProvider.overrideWith((ref, c) => _NoStages()),
    activeTracksProvider.overrideWith((ref) => Stream.value(const [])),
    profileProgramsByProfileProvider.overrideWith((ref) async => const {}),
  ],
  child: child,
);

Finder _semantics(Pattern pattern) => find.bySemanticsLabel(pattern);

void main() {
  group('curriculum progress screen', () {
    testWidgets('repeats leave the distinct count unchanged; nodes carry '
        'state, count and semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          progressState(_base),
          const CurriculumProgressScreen(curriculumId: 'mishnayos'),
        ),
      );
      await tester.pumpAndSettle();

      expect(_semantics(RegExp('partial, 3 of 7 learnt')), findsWidgets);
      expect(find.byType(LearntTriStateBox), findsWidgets);
      expect(find.byIcon(Icons.indeterminate_check_box_rounded), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Moed'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_semantics(RegExp('not learnt, 0 of 2 learnt')), findsWidgets);
      handle.dispose();
    });

    testWidgets('learning from another source updates the count', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          progressState([
            ..._base,
            engineLearn(
              5,
              'Mishnah Shabbat 1:1',
              minutes: 4,
              dateState: DateState.catchUp,
            ),
          ]),
          const CurriculumProgressScreen(curriculumId: 'mishnayos'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_semantics(RegExp('partial, 3 of 7 learnt')), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Moed'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_semantics(RegExp('partial, 1 of 2 learnt')), findsWidgets);
      handle.dispose();
    });
  });

  testWidgets('lifetime tree: tristate, 12% tint, count and semantics per '
      'node', (tester) async {
    final handle = tester.ensureSemantics();
    final state = progressState(_base);
    final summary = (await computeLifetimeViewSummary(
      state: state,
      corpus: progressCorpus(),
      repo: FixtureContentRepository(),
      curriculum: CurriculumId.mishnayos,
    ))!;
    await tester.pumpWidget(
      _app(
        state,
        Scaffold(body: CurriculumBreakdownList(summaries: [summary])),
      ),
    );
    await tester.pumpAndSettle();
    // Expand the curriculum card to show its top-level nodes.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(_semantics(RegExp('partial, 3 of 7 learnt')), findsOneWidget);
    expect(_semantics(RegExp('not learnt, 0 of 2 learnt')), findsOneWidget);
    final tints = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(CurriculumBreakdownTreeNode),
            matching: find.byType(Material),
          ),
        )
        .map((m) => m.color?.a)
        .whereType<double>();
    expect(tints, everyElement(closeTo(learntTriStateTintAlpha, 0.01)));
    expect(find.text('3/7'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Browse tree: a container and a leaf render their engine '
      'state', (tester) async {
    final handle = tester.ensureSemantics();
    final content = progressContent();
    final peah = content.firstWhere((i) => i.sefariaRef == 'Mishnah Peah');
    final berakhot = content.firstWhere(
      (i) => i.sefariaRef == 'Mishnah Berakhot',
    );
    final leaf = content.firstWhere(
      (i) => i.sefariaRef == 'Mishnah Berakhot 1:1',
    );
    await tester.pumpWidget(
      _app(
        progressState(_base),
        Scaffold(
          body: Column(
            children: [
              for (final item in [peah, berakhot, leaf])
                ContentItemTile(
                  item: item,
                  curriculum: CurriculumId.mishnayos,
                  onTap: () {},
                  showReviewBadge: false,
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_semantics(RegExp('complete, 2 of 2 learnt')), findsOneWidget);
    expect(_semantics(RegExp('partial, 1 of 5 learnt')), findsOneWidget);
    expect(_semantics(RegExp('complete, 1 of 1 learnt')), findsOneWidget);
    expect(find.text('1 of 5 learnt'), findsOneWidget);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    expect(
      tiles.map((t) => t.tileColor!.a),
      everyElement(closeTo(learntTriStateTintAlpha, 0.01)),
    );
    handle.dispose();
  });
}
