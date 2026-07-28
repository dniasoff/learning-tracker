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
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/progress_tier_counter_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

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
  required double cyclePct,
  required double lifetimePct,
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
  ProfileMode userMode = ProfileMode.adult,
  int points = 0,
  StackRouter? router,
  bool useHebrew = false,
  double cyclePct = 0.31,
  double lifetimePct = 0.33,
  Locale locale = const Locale('en'),
  // P2 fix (deferred/track-rename-propagation): [db] + [metricsOverride] let
  // a test supply a seeded in-memory database + a metrics list whose
  // trackId matches a real seeded track/goal row, so `_PerTrackRow`'s
  // `trackCustomNameProvider(metric.trackId)` watch resolves against real
  // data instead of the default `_metrics()` synthetic trackIds (which have
  // no backing track/goal row). Both default to the pre-existing behaviour
  // when omitted, so every other test in this file is unaffected.
  UserDatabase? db,
  List<TrackDualProgressMetric>? metricsOverride,
}) {
  final scope = ProviderScope(
    overrides: [
      if (db != null) userDatabaseProvider.overrideWith((ref) => db),
      activeProfileIdProvider.overrideWith(
        () => _ProfileIdOverride(_profileId),
      ),
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: useHebrew),
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
      dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(points)),
      journeyViewModelProvider(
        _profileId,
      ).overrideWith((ref) => Future.value(journey)),
      lifetimeTotalsAcrossAllCurriculaProvider(
        _profileId,
      ).overrideWith((ref) => Future.value(totals)),
      trackDualProgressMetricsProvider(_profileId).overrideWith(
        (ref) => Future.value(
          metricsOverride ??
              _metrics(
                curricula: activeCurricula,
                cyclePct: cyclePct,
                lifetimePct: lifetimePct,
              ),
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
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
    testWidgets('renders top counter row + 3 lens tiles + per-track rows '
        '(adult mode, single track)', (tester) async {
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

      // 2. Counter values + short noun labels are visible (English default
      // — Hebrew toggle is pinned off in [_wrap]). Big value uses
      // locale-aware thousands separator so 1336 → "1,336".
      expect(find.text('6'), findsOneWidget); // streak value
      expect(find.text('4'), findsOneWidget); // siyumim value
      expect(find.text('1,336'), findsOneWidget); // lifetime value formatted
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Siyumim'), findsOneWidget);
      expect(find.text('Lifetime'), findsOneWidget);

      // 3. The three lens tile titles render via `domainTermLabels(ref)`.
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Siyumim & Milestones'), findsOneWidget);
      expect(find.text('Lifetime Knowledge'), findsOneWidget);

      // 4. Per-track row shows the dual progress numbers (31% / 33%).
      expect(find.text('Track progress: 31%'), findsOneWidget);
      expect(find.text('Lifetime: 33%'), findsOneWidget);

      // 5. Section header for tracks.
      expect(find.text('ACTIVE TRACKS'), findsOneWidget);
    });

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

        // No points tile (label or formatted value) in adult mode.
        expect(find.text('Points'), findsNothing);
        expect(find.text('1,250'), findsNothing);
      },
    );

    testWidgets('child mode renders the fourth ⭐ points counter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          activeCurricula: const [CurriculumId.mishnayos],
          journey: _journey(unit: 1),
          totals: _lifetime(learned: 5),
          streak: 2,
          userMode: ProfileMode.child,
          points: 1250,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1,250'), findsOneWidget); // points value formatted
      expect(find.text('Points'), findsOneWidget);
    });

    testWidgets('legacy 4-card stat grid + inline lifetime tree are GONE', (
      tester,
    ) async {
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
    });

    testWidgets('shows empty state when there are no active curricula', (
      tester,
    ) async {
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
    });

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
          reason:
              'Lifetime Knowledge lens tile must push LifetimeKnowledgeRoute',
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

  // ── Bug 1 (regression) — lens tiles follow device locale, not the
  //    Hebrew-Terms toggle ────────────────────────────────────────────────
  group('Bug 1 — lens tiles use locale-based l10n (not the Hebrew-Terms '
      'toggle)', () {
    testWidgets(
      'English locale + Hebrew-Terms toggle ON → lens tiles stay English',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.mishnayos],
            journey: _journey(),
            totals: _lifetime(learned: 5),
            streak: 1,
            // The toggle being ON used to flip the WHOLE tile (title +
            // subtitle) to Hebrew even though the device UI is English.
            useHebrew: true,
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        // Titles render in English (locale-based) regardless of the toggle.
        expect(find.text('Recent Activity'), findsOneWidget);
        expect(find.text('Siyumim & Milestones'), findsOneWidget);
        expect(find.text('Lifetime Knowledge'), findsOneWidget);

        // The generic English subtitle on the Recent Activity tile is present
        // (it used to render in Hebrew when the toggle was on).
        expect(find.text('Completions, trends, and more'), findsOneWidget);

        // No Hebrew tile strings leak onto the English hub.
        expect(find.text('פעילות אחרונה'), findsNothing);
        expect(find.text('השלמות, מגמות ועוד'), findsNothing);
      },
    );

    testWidgets('Hebrew locale → lens tiles render Hebrew (standard locale '
        'behaviour)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          activeCurricula: const [CurriculumId.mishnayos],
          journey: _journey(),
          totals: _lifetime(learned: 5),
          streak: 1,
          useHebrew: true,
          locale: const Locale('he'),
        ),
      );
      await tester.pumpAndSettle();

      // Hebrew device locale → Hebrew tile strings (normal locale resolution).
      expect(find.text('פעילות אחרונה'), findsOneWidget);
      expect(find.text('Recent Activity'), findsNothing);
    });
  });

  // ── Bug 3 — small non-zero fraction renders "0.1%" on the hub, not "0%" ──
  group('Bug 3 — per-track percentages use adaptive precision', () {
    testWidgets(
      'a tiny non-zero fraction (7/5846) renders "0.1%" instead of "0%"',
      (tester) async {
        const tiny = 7 / 5846; // ≈ 0.0011974 → 0.1%
        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.mishnayos],
            journey: _journey(),
            totals: _lifetime(),
            streak: 0,
            cyclePct: tiny,
            lifetimePct: tiny,
          ),
        );
        await tester.pumpAndSettle();

        // Previously `.round()` floored both to "0%"; the shared adaptive
        // formatter now matches the Lifetime Knowledge breakdown ("0.1%").
        expect(find.text('Track progress: 0.1%'), findsOneWidget);
        expect(find.text('Lifetime: 0.1%'), findsOneWidget);
        expect(find.text('Track progress: 0%'), findsNothing);
      },
    );

    testWidgets('a whole-number percentage still renders without a decimal', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          activeCurricula: const [CurriculumId.mishnayos],
          journey: _journey(),
          totals: _lifetime(),
          streak: 0,
          cyclePct: 0.5,
          lifetimePct: 0.5,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track progress: 50%'), findsOneWidget);
      expect(find.text('Lifetime: 50%'), findsOneWidget);
    });
  });

  // ── P2 fix (deferred/track-rename-propagation) ────────────────────────────
  // The Progress hub's per-track row is a specific track's own label (each
  // row = one track), so it must honour a custom track name the same way
  // Track Detail and the Learn track cards already do (B-EDIT-NAME,
  // commit 00048c68) instead of always showing the raw curriculum label.
  group('P2 — per-track row surfaces a custom track name', () {
    testWidgets(
      'a track renamed via Goal.description shows the custom name, not '
      'the curriculum label',
      (tester) async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);
        final trackId = await seedTrack(
          db,
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos.storageKey,
        );
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: _profileId,
                curriculumId: CurriculumId.mishnayos.storageKey,
                trackId: trackId,
                description: const Value('My Shas Journey'),
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );

        await tester.pumpWidget(
          _wrap(
            activeCurricula: const [CurriculumId.mishnayos],
            journey: _journey(),
            totals: _lifetime(),
            streak: 0,
            db: db,
            metricsOverride: [
              TrackDualProgressMetric(
                trackId: trackId,
                trackLabel: CurriculumId.mishnayos.storageKey,
                curriculumId: CurriculumId.mishnayos,
                currentCyclePercentage: 0.31,
                lifetimePercentage: 0.33,
                isProgramTrack: false,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Pre-fix the row always showed the curriculum label and ignored
        // the edited name. The custom name must now surface on the row.
        expect(find.text('My Shas Journey'), findsOneWidget);
        expect(find.text('Mishnayos'), findsNothing);
      },
    );

    testWidgets('no custom name (no goal seeded) falls back to the '
        'curriculum label', (tester) async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: CurriculumId.mishnayos.storageKey,
      );

      await tester.pumpWidget(
        _wrap(
          activeCurricula: const [CurriculumId.mishnayos],
          journey: _journey(),
          totals: _lifetime(),
          streak: 0,
          db: db,
          metricsOverride: [
            TrackDualProgressMetric(
              trackId: trackId,
              trackLabel: CurriculumId.mishnayos.storageKey,
              curriculumId: CurriculumId.mishnayos,
              currentCyclePercentage: 0.31,
              lifetimePercentage: 0.33,
              isProgramTrack: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mishnayos'), findsOneWidget);
    });
  });
}
