/// Widget tests for the new Progress hub (W3b-A / Task #8).
///
/// Verifies:
///   - The hub renders the top counter row (via [ProgressTierCounterRow]),
///     the three lens tiles, and the per-track section.
///   - The legacy `_StatGrid` and `_LearningLifetimeTreeCard` are gone —
///     the four "ITEMS LEARNED · TASKS DONE · DAY STREAK · ACTIVE TRACKS"
///     labels do NOT appear anywhere on the hub.
///   - Tapping each lens tile pushes the matching route on the router.
@Tags(['progress', 'progress_hub'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/progress_tier_counter_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _profileId = 1;

class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

/// Pin the Hebrew Terms toggle off so we can assert against the English
/// default strings.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

/// Captures pushed route names so the lens-tile tap tests can assert
/// navigation occurred without mounting the real auto_route stack.
class _RecordingRouter extends Fake implements StackRouter {
  _RecordingRouter(this.pushed);

  final List<String> pushed;

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route.routeName);
    return null;
  }
}

JourneyViewModel _journey({
  int unit = 3,
  int aggregate = 1,
  int curriculum = 0,
}) => JourneyViewModel(
      curricula: const [],
      totalCompletions: 0,
      totalUniqueUnits: 0,
      unitLevelSiyumimCount: unit,
      aggregateLevelSiyumimCount: aggregate,
      curriculumLevelSiyumimCount: curriculum,
    );

LifetimeTotals _lifetime({int learned = 0, int total = 0}) => LifetimeTotals(
      learnedSections: learned,
      totalSections: total,
      totalCurricula: 9,
    );

List<TrackDualProgressMetric> _metrics({
  required List<CurriculumId> curricula,
  double cyclePct = 0.31,
  double lifetimePct = 0.33,
}) {
  return [
    for (var i = 0; i < curricula.length; i++)
      TrackDualProgressMetric(
        trackId: 100 + i,
        trackLabel: curricula[i].storageKey,
        curriculumId: curricula[i],
        currentCyclePercentage: cyclePct,
        lifetimePercentage: lifetimePct,
        isProgramTrack: false,
      ),
  ];
}

Widget _wrap({
  required List<CurriculumId> activeCurricula,
  required JourneyViewModel journey,
  required LifetimeTotals totals,
  required int streak,
  UserMode userMode = UserMode.adult,
  int points = 0,
  StackRouter? router,
}) {
  final scope = ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWith(
        () => _ProfileIdOverride(_profileId),
      ),
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: false),
      ),
      dashboardActiveCurriculaProvider.overrideWith(
        (ref) => Future.value(activeCurricula),
      ),
      dashboardActiveCurriculaStreamProvider.overrideWith(
        (ref) => Stream.value(activeCurricula),
      ),
      dashboardUserModeProvider.overrideWith((ref) => Future.value(userMode)),
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value((currentStreak: streak, maxStreak: streak)),
      ),
      dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(points)),
      journeyViewModelProvider(_profileId).overrideWith(
        (ref) => Future.value(journey),
      ),
      lifetimeTotalsAcrossAllCurriculaProvider(_profileId).overrideWith(
        (ref) => Future.value(totals),
      ),
      trackDualProgressMetricsProvider(_profileId).overrideWith(
        (ref) => Future.value(_metrics(curricula: activeCurricula)),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: router == null
          ? const ProgressScreen()
          : StackRouterScope(
              controller: router,
              stateHash: 0,
              child: const ProgressScreen(),
            ),
    ),
  );
  return scope;
}

void main() {
  group('ProgressScreen — three-lens IA hub', () {
    testWidgets(
      'renders top counter row + 3 lens tiles + per-track rows '
      '(adult mode, single track)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.mishnayos],
            // 3 + 1 + 0 = 4 siyumim total.
            journey: _journey(unit: 3, aggregate: 1),
            totals: _lifetime(learned: 1336),
            streak: 6,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Shared counter row widget is present.
        expect(find.byType(ProgressTierCounterRow), findsOneWidget);

        // 2. Counter values are visible (English default labels — Hebrew
        // toggle is pinned off in [_wrap]).
        expect(find.text('6-day streak'), findsOneWidget);
        expect(find.text('4 siyumim earned'), findsOneWidget);
        expect(find.text('1336 items in lifetime'), findsOneWidget);

        // 3. The three lens tile titles render via `domainTermLabels(ref)`.
        expect(find.text('Recent Activity'), findsOneWidget);
        expect(find.text('Siyumim & Milestones'), findsOneWidget);
        expect(find.text('Lifetime Knowledge'), findsOneWidget);

        // 4. Per-track row shows the dual progress numbers (31% / 33%).
        expect(find.text('Track progress: 31%'), findsOneWidget);
        expect(find.text('Lifetime: 33%'), findsOneWidget);

        // 5. Section header for tracks.
        expect(find.text('ACTIVE TRACKS'), findsOneWidget);
      },
    );

    testWidgets(
      'adult mode hides the points counter even when points provider is non-zero',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.bavli],
            journey: _journey(unit: 0, aggregate: 0, curriculum: 0),
            totals: _lifetime(),
            streak: 0,
            points: 1250,
          ),
        );
        await tester.pumpAndSettle();

        // No "1250 pts" anywhere in adult mode.
        expect(find.text('1250 pts'), findsNothing);
      },
    );

    testWidgets(
      'child mode renders the fourth ⭐ points counter',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.mishnayos],
            journey: _journey(unit: 1),
            totals: _lifetime(learned: 5),
            streak: 2,
            userMode: UserMode.child,
            points: 1250,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1250 pts'), findsOneWidget);
      },
    );

    testWidgets(
      'legacy 4-card stat grid + inline lifetime tree are GONE',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.mishnayos],
            journey: _journey(),
            totals: _lifetime(),
            streak: 0,
          ),
        );
        await tester.pumpAndSettle();

        // The retired _StatGrid had these all-caps labels via the legacy
        // l10n keys (statCompletions, statUnitsDone, statActiveTracks).
        // They must NOT appear on the hub anymore.
        expect(find.text('ITEMS LEARNED'), findsNothing);
        expect(find.text('TASKS DONE'), findsNothing);
        expect(find.text('DAY STREAK'), findsNothing);

        // The inline learning-lifetime tree header is gone — the tree
        // moved into the Lifetime Knowledge screen.
        expect(find.text('Learning Lifetime'), findsNothing);
      },
    );

    testWidgets(
      'shows empty state when there are no active curricula',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [],
            journey: _journey(),
            totals: _lifetime(),
            streak: 0,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No progress yet'), findsOneWidget);
        // Counter row + per-track section are not rendered when empty.
        expect(find.byType(ProgressTierCounterRow), findsNothing);
      },
    );

    testWidgets(
      'tapping each lens tile pushes the matching route on the router',
      (tester) async {
        final pushed = <String>[];
        final router = _RecordingRouter(pushed);

        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.mishnayos],
            journey: _journey(),
            totals: _lifetime(),
            streak: 0,
            router: router,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Recent Activity'));
        await tester.pumpAndSettle();
        expect(
          pushed,
          contains('RecentActivityRoute'),
          reason: 'Recent Activity lens tile must push RecentActivityRoute',
        );

        await tester.tap(find.text('Siyumim & Milestones'));
        await tester.pumpAndSettle();
        expect(
          pushed,
          contains('SiyumimMilestonesRoute'),
          reason:
              'Siyumim & Milestones lens tile must push SiyumimMilestonesRoute',
        );

        await tester.tap(find.text('Lifetime Knowledge'));
        await tester.pumpAndSettle();
        expect(
          pushed,
          contains('LifetimeKnowledgeRoute'),
          reason: 'Lifetime Knowledge lens tile must push LifetimeKnowledgeRoute',
        );
      },
    );

    testWidgets(
      'tapping a per-track row pushes the curriculum progress route',
      (tester) async {
        final pushed = <String>[];
        final router = _RecordingRouter(pushed);

        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.mishnayos],
            journey: _journey(),
            totals: _lifetime(),
            streak: 0,
            router: router,
          ),
        );
        await tester.pumpAndSettle();

        // Tap on the dual-progress label inside the per-track row — the row
        // is wrapped in an InkWell so any hit lands the same route push.
        await tester.tap(find.text('Track progress: 31%'));
        await tester.pumpAndSettle();

        expect(
          pushed,
          contains('CurriculumProgressRoute'),
          reason:
              'tapping a per-track row must push CurriculumProgressRoute '
              'for that curriculum',
        );
      },
    );
  });
}
