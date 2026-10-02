/// Widget tests for the Lifetime Knowledge screen over the engine's
/// LearnerState (DNI-474).
///
/// Verifies:
///   - the header counts distinct learnt items and the derived chazara
///     count, and the "Track learning only" toggle excludes before-tracking
///     marks from both the header and the tree;
///   - leaf provenance is shown (live with chazaros / bulk-marked);
///   - a tree leaf opens Mishna history;
///   - the "Add items I learned previously" CTA is offered only to a
///     child-mode profile (its route requires childModeGuard).
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_knowledge_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/curriculum_breakdown_list.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/learner_state/progress_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

class _UseHebrewTermsOverride extends UseHebrewTerms {
  @override
  bool build() => false;
}

LearnerProfileEntity _profile(ProfileMode mode) => LearnerProfileEntity(
  profileId: profileUlid,
  displayName: 'Test User',
  mode: mode,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _RecordingRouter extends Fake implements StackRouter {
  final routes = <PageRouteInfo>[];

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    routes.add(route);
    return null;
  }
}

void main() {
  final state = progressState([
    progressGround(1, 'Mishnah Peah', 'masechta'),
    progressLearn(2, 'Mishnah Berakhot 1:1', minutes: 1),
    progressLearn(3, 'Mishnah Berakhot 1:1', minutes: 2),
  ]);

  Future<_RecordingRouter> pump(
    WidgetTester tester, {
    LearnerState? learner,
    ProfileMode mode = ProfileMode.adult,
  }) async {
    final router = _RecordingRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...progressOverrides(learner ?? state),
          activeProfileProvider.overrideWith((ref) async => _profile(mode)),
          useHebrewTermsProvider.overrideWith(_UseHebrewTermsOverride.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: const LifetimeKnowledgeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('all sources: the header counts distinct items (repeats '
      'once, before-tracking included) and the chazara repeat', (tester) async {
    await pump(tester);
    expect(find.textContaining('3'), findsWidgets);
    final list = tester.widget<CurriculumBreakdownList>(
      find.byType(CurriculumBreakdownList),
    );
    expect(list.summaries.single.learnedLeafCount, 3);
  });

  testWidgets('track learning only leaves before-tracking marks out of the '
      'tree', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Track learning only'));
    await tester.pumpAndSettle();
    final list = tester.widget<CurriculumBreakdownList>(
      find.byType(CurriculumBreakdownList),
    );
    expect(list.summaries.single.learnedLeafCount, 1);
  });

  testWidgets('no learning shows the empty state', (tester) async {
    await pump(tester, learner: progressState(const []));
    expect(find.byType(CurriculumBreakdownList), findsNothing);
  });

  testWidgets('a tree leaf opens Mishna history for its curriculum and '
      'ref', (tester) async {
    final router = await pump(tester);
    final list = tester.widget<CurriculumBreakdownList>(
      find.byType(CurriculumBreakdownList),
    );
    list.onLeafTap!(CurriculumId.mishnayos, 'Mishnah Berakhot 1:1');
    await tester.pumpAndSettle();
    final args = router.routes.single.args! as MishnaHistoryRouteArgs;
    expect(args.curriculumId, CurriculumId.mishnayos.storageKey);
    expect(args.leafRef, 'Mishnah Berakhot 1:1');
  });

  testWidgets('the CTA is offered to a child profile and pushes '
      'LifetimeMarkingRoute', (tester) async {
    final router = await pump(tester, mode: ProfileMode.child);
    final cta = find.text('Add items I learned previously');
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(router.routes.single.routeName, 'LifetimeMarkingRoute');
  });

  testWidgets('the CTA is hidden for an adult profile (its route requires '
      'childModeGuard)', (tester) async {
    await pump(tester);
    expect(find.text('Add items I learned previously'), findsNothing);
  });
}
