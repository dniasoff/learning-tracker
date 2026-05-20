/// Widget tests for the Dashboard refinement (Task #14 / Phase D):
///
///   - The shared [ProgressTierCounterRow] is mounted on the Dashboard body.
///   - Adult mode renders 3 counters (no points).
///   - Child mode renders 4 counters (includes points).
///   - Active-track rows show dual "Track progress" / "Lifetime" labels
///     wired to [trackDualProgressMetricsProvider].
///   - The legacy "ACTIVE TRACKS" stat card no longer appears.
@Tags(['dashboard', 'tier_counter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _profileId = 0;

// ── Overrides ──────────────────────────────────────────────────────────────

class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

/// Pin the Hebrew Terms toggle off so assertions can target English copy
/// deterministically — the toggle default depends on environment.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

// ── Fixture helpers ────────────────────────────────────────────────────────

JourneyViewModel _journey({
  int unit = 0,
  int aggregate = 0,
  int curriculum = 0,
}) => JourneyViewModel(
  curricula: const [],
  totalCompletions: 0,
  totalUniqueUnits: 0,
  unitLevelSiyumimCount: unit,
  aggregateLevelSiyumimCount: aggregate,
  curriculumLevelSiyumimCount: curriculum,
);

LifetimeTotals _lifetimeTotals({int learned = 0, int total = 0}) =>
    LifetimeTotals(
      learnedSections: learned,
      totalSections: total,
      totalCurricula: CurriculumId.values.length,
    );

CurriculumTrack _track({
  int id = 1,
  CurriculumId curriculum = CurriculumId.mishnayos,
}) => CurriculumTrack(
  id: id,
  profileId: _profileId,
  curriculumId: curriculum.storageKey,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

TrackDualProgressMetric _dualMetric({
  required int trackId,
  required CurriculumId curriculum,
  double currentCycle = 0.0,
  double lifetime = 0.0,
}) => TrackDualProgressMetric(
  trackId: trackId,
  trackLabel: curriculum.storageKey,
  curriculumId: curriculum,
  currentCyclePercentage: currentCycle,
  lifetimePercentage: lifetime,
  isProgramTrack: false,
);

/// Build the full set of overrides needed to render [DashboardScreen] with
/// at least one active track (so the body — and therefore the counter row —
/// renders instead of the empty-state placeholder).
List<Override> _overridesFor({
  required UserMode userMode,
  required int currentStreak,
  required JourneyViewModel journey,
  required LifetimeTotals lifetime,
  required List<CurriculumTrack> tracks,
  required List<TrackDualProgressMetric> dualMetrics,
  int points = 0,
}) {
  return [
    activeProfileIdProvider.overrideWith(
      () => _ProfileIdOverride(_profileId),
    ),
    useHebrewTermsProvider.overrideWith(
      () => _UseHebrewTermsOverride(useHebrew: false),
    ),
    dashboardActiveCurriculaProvider.overrideWith(
      (ref) => Future.value(
        tracks
            .map(
              (t) => CurriculumId.values.firstWhere(
                (c) => c.storageKey == t.curriculumId,
                orElse: () => CurriculumId.mishnayos,
              ),
            )
            .toList(),
      ),
    ),
    dashboardActiveCurriculaStreamProvider.overrideWith(
      (ref) => Stream.value(
        tracks
            .map(
              (t) => CurriculumId.values.firstWhere(
                (c) => c.storageKey == t.curriculumId,
                orElse: () => CurriculumId.mishnayos,
              ),
            )
            .toList(),
      ),
    ),
    dashboardActiveTracksStreamProvider.overrideWith(
      (ref) => Stream.value(tracks),
    ),
    dashboardUserModeProvider.overrideWith((ref) => Future.value(userMode)),
    dashboardStreakProvider.overrideWith(
      (ref) => Stream.value(
        (currentStreak: currentStreak, maxStreak: currentStreak),
      ),
    ),
    dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(points)),
    dashboardStreakRecoveryProvider.overrideWith(
      (ref) => Future.value(
        StreakRecoveryInfo(wasRecovered: false, currentStreak: currentStreak),
      ),
    ),
    allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
    initialSyncCompleteProvider.overrideWith((ref) => Future.value(true)),
    journeyViewModelProvider(_profileId).overrideWith(
      (ref) => Future.value(journey),
    ),
    lifetimeTotalsAcrossAllCurriculaProvider(_profileId).overrideWith(
      (ref) => Future.value(lifetime),
    ),
    trackDualProgressMetricsProvider(_profileId).overrideWith(
      (ref) => Future.value(dualMetrics),
    ),
    // Mark every curriculum as non-program-enrolled so the active-track card
    // takes the self-paced branch (avoids the program-calendar provider tree).
    for (final c in CurriculumId.values)
      dashboardHasProgramEnrollmentProvider(c).overrideWith(
        (ref) => Future.value(false),
      ),
  ];
}

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DashboardScreen(),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('Dashboard — ProgressTierCounterRow integration', () {
    testWidgets(
      'adult mode renders 3 counters (streak / siyumim / lifetime), no points',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            overrides: _overridesFor(
              userMode: UserMode.adult,
              currentStreak: 7,
              // 3 unit + 1 aggregate + 0 curriculum = 4 siyumim total
              journey: _journey(unit: 3, aggregate: 1),
              lifetime: _lifetimeTotals(learned: 42, total: 100),
              points: 250, // adult mode must NOT render this
              tracks: [track],
              dualMetrics: [
                _dualMetric(
                  trackId: track.id,
                  curriculum: CurriculumId.mishnayos,
                  currentCycle: 0.5,
                  lifetime: 0.42,
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The three engagement / achievement / lifetime counter labels.
        expect(find.text('7-day streak'), findsOneWidget);
        expect(find.text('4 siyumim earned'), findsOneWidget);
        expect(find.text('42 items in lifetime'), findsOneWidget);
        // Adult mode must NOT render the ⭐ points counter even when the
        // dashboardGlobalPointsProvider has a non-zero value.
        expect(find.text('250 pts'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'child mode renders 4 counters (adds ⭐ points)',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            overrides: _overridesFor(
              userMode: UserMode.child,
              currentStreak: 3,
              journey: _journey(unit: 2),
              lifetime: _lifetimeTotals(learned: 15, total: 100),
              points: 1200,
              tracks: [track],
              dualMetrics: [
                _dualMetric(
                  trackId: track.id,
                  curriculum: CurriculumId.mishnayos,
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('3-day streak'), findsOneWidget);
        expect(find.text('2 siyumim earned'), findsOneWidget);
        expect(find.text('15 items in lifetime'), findsOneWidget);
        // ⭐ points counter must appear in child mode.
        expect(find.text('1200 pts'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('Dashboard — dual per-track labels', () {
    testWidgets(
      'active-track card shows both "Track progress: X%" and "Lifetime: Y%"',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            overrides: _overridesFor(
              userMode: UserMode.adult,
              currentStreak: 0,
              journey: _journey(),
              lifetime: _lifetimeTotals(),
              tracks: [track],
              dualMetrics: [
                _dualMetric(
                  trackId: track.id,
                  curriculum: CurriculumId.mishnayos,
                  // 0.35 → 35%, 0.74 → 74% (rounded via formatFractionAsPercent)
                  currentCycle: 0.35,
                  lifetime: 0.74,
                ),
              ],
            ),
          ),
        );
        // Two pumps to allow the futures + stream to settle without using
        // pumpAndSettle (which would spin forever on auto-refreshing streams).
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The active-tracks carousel lives near the bottom of the dashboard
        // ListView and is outside the default test viewport (800×600).
        // Scroll it into view so the per-track card renders.
        await tester.scrollUntilVisible(
          find.byType(PageView),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Both labels are rendered side-by-side in the card footer.
        // `formatFractionAsPercent` formats with 2 decimal places by default
        // (e.g. 0.35 → "35.00%"). Tests assert the exact rendered string so
        // any formatter tweak surfaces as a deliberate failure.
        expect(find.text('Track progress: 35.00%'), findsOneWidget);
        expect(find.text('Lifetime: 74.00%'), findsOneWidget);
        // Legacy single-label format must be gone.
        expect(find.textContaining('Since reactivation'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('Dashboard — legacy "ACTIVE TRACKS" stat card removed', () {
    testWidgets(
      'no widget displays the legacy "ACTIVE TRACKS" stat tile',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            overrides: _overridesFor(
              userMode: UserMode.adult,
              currentStreak: 0,
              journey: _journey(),
              lifetime: _lifetimeTotals(),
              tracks: [track],
              dualMetrics: [
                _dualMetric(
                  trackId: track.id,
                  curriculum: CurriculumId.mishnayos,
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Neither casing should appear — the redundant counter card is gone.
        expect(find.text('ACTIVE TRACKS'), findsNothing);
        expect(find.text('Active Tracks'.toUpperCase()), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
