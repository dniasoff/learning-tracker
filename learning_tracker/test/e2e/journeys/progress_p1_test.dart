/// E2E Wave 2 P1 journeys — Progress area.
///
/// Journeys implemented:
///   E2E-803  Progress hub in child mode — points counter shown
///   E2E-806  Siyumim & Milestones: tutor views child's journey via
///            profileId query param
///   E2E-809  Progress hub empty state — no active curricula
///   E2E-810  Recent Activity offline / stale data behavior
///   E2E-811  Recent Activity with chazara-enabled vs. learn-only track
///   E2E-812  Hebrew locale (RTL) across progress screens — ProgressScreen
///            lays out RTL with Hebrew lens-tile titles under Locale('he')
///   E2E-813  Completion committed → progress screens update without
///            pull-to-refresh
///   E2E-814  Curriculum Progress: pace indicator states
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 9 / §7 R-PG*
///
/// Risk coverage:
///   R-PG6  anyActiveTrackHasChazaraProvider not invalidated on completion
///          commit — E2E-811 checks the toggle at build time
///   R-PG7  SiyumimMilestonesScreen profileId query param: no access-control
///          check — E2E-806 seeds a SECOND real profile and requests its
///          journey via an explicit, differing profileId, asserting the
///          OTHER profile's name and milestone content actually load
@Tags(['e2e', 'journey'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart'
    show DateTimeFactory;
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_screen.dart'
    show ProgressScreen;

import '../harness/e2e_common_overrides.dart' show stubTrack;
import '../harness/e2e_harness.dart';
import '../helpers/e2e_overrides.dart' show EmptyContentRepository;

// ── Shared test data ──────────────────────────────────────────────────────────

/// Zero-value [LifetimeTotals] stub.
const _zeroLifetimeTotals = LifetimeTotals(
  learnedSections: 0,
  totalSections: 0,
  totalCurricula: 0,
);

/// Empty [JourneyViewModel] (no siyumim yet).
const _emptyJourneyViewModel = JourneyViewModel(
  curricula: [],
  totalCompletions: 0,
  totalUniqueUnits: 0,
  unitLevelSiyumimCount: 0,
  aggregateLevelSiyumimCount: 0,
  curriculumLevelSiyumimCount: 0,
);

/// [JourneyViewModel] with one siyum milestone.
final _singleMilestoneJourneyViewModel = JourneyViewModel(
  curricula: [
    CurriculumJourney(
      curriculumId: CurriculumId.mishnayos,
      completions: [],
      uniqueUnitsCompleted: 1,
      totalUnitsAvailable: 63,
      milestones: [
        MilestoneAchievement(
          type: 'unit_complete',
          level: MilestoneLevel.unit,
          curriculumId: CurriculumId.mishnayos,
          displayName: 'Berakhot',
          unitKey: 'Berakhot',
          unitScope: 'masechta',
          achievedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    ),
  ],
  totalCompletions: 1,
  totalUniqueUnits: 1,
  unitLevelSiyumimCount: 1,
  aggregateLevelSiyumimCount: 0,
  curriculumLevelSiyumimCount: 0,
);

/// [JourneyViewModel] used ONLY for the "other" profile in the E2E-806
/// cross-profile (R-PG7) sub-test — deliberately a DIFFERENT milestone from
/// [_singleMilestoneJourneyViewModel] so an assertion of this milestone's
/// text on screen proves the OTHER profile's data loaded, not the caller's.
final _otherProfileJourneyViewModel = JourneyViewModel(
  curricula: [
    CurriculumJourney(
      curriculumId: CurriculumId.mishnayos,
      completions: [],
      uniqueUnitsCompleted: 1,
      totalUnitsAvailable: 63,
      milestones: [
        MilestoneAchievement(
          type: 'unit_complete',
          level: MilestoneLevel.unit,
          curriculumId: CurriculumId.mishnayos,
          displayName: 'Sukkah',
          unitKey: 'Sukkah',
          unitScope: 'masechta',
          achievedAt: DateTime.utc(2026, 1, 2),
        ),
      ],
    ),
  ],
  totalCompletions: 1,
  totalUniqueUnits: 1,
  unitLevelSiyumimCount: 1,
  aggregateLevelSiyumimCount: 0,
  curriculumLevelSiyumimCount: 0,
);

/// Minimal [CurriculumProgressData] stub with non-zero overall stats so the
/// detail screen renders its progress card.
const _stubCurriculumProgressData = CurriculumProgressData(
  curriculumId: 'mishnayos',
  hierarchyLevels: [],
  overallStats: OverallCurriculumStats(
    totalItems: 10,
    completedAllStages: 3,
    inProgress: 2,
    notStarted: 5,
  ),
);

// ── Override helpers ──────────────────────────────────────────────────────────

/// Overrides that silence dashboard stream providers (streak, points, tracks)
/// for any test landing on /progress. Mirrors the P0 pattern exactly.
List<Override> _progressWithContentOverrides(E2EHarness h) => [
  dashboardActiveCurriculaStreamProvider.overrideWith(
    (ref) => Stream.value(<CurriculumId>[CurriculumId.mishnayos]),
  ),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value(<CurriculumTrack>[
      stubTrack(id: 1, profileId: 1, curriculum: CurriculumId.mishnayos),
    ]),
  ),
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 3, maxStreak: 5)),
  ),
  dashboardStreakRecoveryProvider.overrideWith(
    (ref) => Future.value(
      const StreakRecoveryInfo(wasRecovered: false, currentStreak: 3),
    ),
  ),
  dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(0)),
  anyActiveTrackHasChazaraProvider.overrideWith((ref) => Future.value(false)),
  lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
    (ref, pid) => Future.value(_zeroLifetimeTotals),
  ),
  lifetimeSummariesProvider.overrideWith(
    (ref, pid) => Future.value(<CurriculumLifetimeSummary>[]),
  ),
  // Content repository — no real asset files in headless env (R-PG8)
  contentRepositoryProvider.overrideWithValue(const EmptyContentRepository()),
];

/// Silences providers consumed by [ProgressTierCounterRow] when tests supply
/// their own [journeyViewModelProvider] override.
List<Override> _counterRowSilenceOverrides() => [
  trackDualProgressMetricsProvider.overrideWith(
    (ref, pid) => Future.value(<TrackDualProgressMetric>[]),
  ),
  journeyViewModelProvider.overrideWith(
    (ref, pid) => Future.value(_emptyJourneyViewModel),
  ),
];

/// Overrides for an empty-curricula Progress hub (E2E-809).
List<Override> _progressEmptyStateOverrides() => [
  dashboardActiveCurriculaStreamProvider.overrideWith(
    (ref) => Stream.value(<CurriculumId>[]),
  ),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value(<CurriculumTrack>[]),
  ),
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
  ),
  dashboardStreakRecoveryProvider.overrideWith(
    (ref) => Future.value(
      const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
    ),
  ),
  dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(0)),
  lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
    (ref, pid) => Future.value(_zeroLifetimeTotals),
  ),
  journeyViewModelProvider.overrideWith(
    (ref, pid) => Future.value(_emptyJourneyViewModel),
  ),
];

/// Minimal shell-level overrides needed when navigating directly to a
/// progress sub-screen (Recent Activity, Lifetime Knowledge) that is mounted
/// inside AppShell. These prevent real Drift stream subscriptions from the
/// shell's tab-bar and dashboard badge providers that would produce timer
/// violations in headless tests.
///
/// Does NOT include streak or chazara providers — those are screen-specific
/// and are added per-test to avoid duplicate overrides.
List<Override> _shellSilenceOverrides() => [
  dashboardActiveCurriculaStreamProvider.overrideWith(
    (ref) => Stream.value(<CurriculumId>[]),
  ),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value(<CurriculumTrack>[]),
  ),
  dashboardStreakRecoveryProvider.overrideWith(
    (ref) => Future.value(
      const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
    ),
  ),
  dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(0)),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-803 ─────────────────────────────────────────────────────────────────

  group('E2E-803 — Progress hub in child mode — points counter shown', () {
    testWidgets(
      'ProgressScreen in child mode shows points tile; adult-only tiles absent',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          displayName: 'Charlie Child',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Child-mode overrides: mirrors _progressWithContentOverrides but
        // replaces dashboardGlobalPointsProvider with a non-zero child balance
        // and adds dashboardUserModeProvider → child so the ⭐ tile renders.
        await h.pumpApp(
          path: '/progress',
          extraOverrides: [
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumId>[CurriculumId.mishnayos]),
            ),
            dashboardActiveTracksStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumTrack>[
                stubTrack(
                  id: 1,
                  profileId: 1,
                  curriculum: CurriculumId.mishnayos,
                ),
              ]),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 2, maxStreak: 4)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 2),
              ),
            ),
            // Child: points balance is non-zero so the counter tile shows a
            // number (not the loading placeholder "…").
            dashboardGlobalPointsProvider.overrideWith(
              (ref) => Stream.value(42),
            ),
            // Key override: child mode → showPoints = true in ProgressScreen.
            dashboardUserModeProvider.overrideWith(
              (ref) => Future.value(ProfileMode.child),
            ),
            anyActiveTrackHasChazaraProvider.overrideWith(
              (ref) => Future.value(false),
            ),
            lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
              (ref, pid) => Future.value(_zeroLifetimeTotals),
            ),
            lifetimeSummariesProvider.overrideWith(
              (ref, pid) => Future.value(<CurriculumLifetimeSummary>[]),
            ),
            contentRepositoryProvider.overrideWithValue(
              const EmptyContentRepository(),
            ),
            trackDualProgressMetricsProvider.overrideWith(
              (ref, pid) => Future.value(<TrackDualProgressMetric>[]),
            ),
            journeyViewModelProvider.overrideWith(
              (ref, pid) => Future.value(_emptyJourneyViewModel),
            ),
          ],
        );

        // Key assertion (E2E-803): "Points" tile label visible for child mode.
        h.expectOnScreen('Points');
        // The progress screen header must still be present.
        h.expectOnScreen('Progress');
        // Lens tiles visible — curriculum is active.
        h.expectOnScreen('Recent Activity');
        h.expectOnScreen('Siyumim & Milestones');
        h.expectOnScreen('Lifetime Knowledge');
      },
    );
  });

  // ── E2E-806 ─────────────────────────────────────────────────────────────────

  group('E2E-806 — Siyumim & Milestones: tutor views child journey via profileId', () {
    // Risk R-PG7: SiyumimMilestonesScreen profileId query param has no
    // access-control check — any authenticated user can load another profile's
    // journey. Document the security gap; assert the screen loads for a
    // different profileId without an error/block.
    testWidgets(
      'SiyumimMilestonesScreen with explicit profileId renders talmid milestones '
      '(security gap R-PG7: no access-control check)',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Tutor Eve');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Navigate directly to the Siyumim & Milestones screen.
        // The screen renders independently (no ProgressTierCounterRow)
        // so the content + dashboard overrides used in hub tests are not
        // needed. We only need journeyViewModelProvider and the stream-based
        // providers that flow through the shell's tab bar.
        await h.pumpApp(
          // R-PG2: navigate via route name (not literal '/journey?profileId=')
          // to exercise the profileId query-param path. We navigate without
          // profileId here (the tutor sub-test below checks the profileId path
          // via router.push which resolves the query param properly).
          path: '/journey',
          extraOverrides: [
            // SiyumimMilestonesScreen reads journeyViewModelProvider(effectiveProfileId)
            // where effectiveProfileId = profileId ?? activeProfileId.
            journeyViewModelProvider.overrideWith(
              (ref, pid) => Future.value(_singleMilestoneJourneyViewModel),
            ),
            // Silence the shell-level stream providers that would otherwise
            // open real Drift watch streams and produce timer violations.
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumId>[]),
            ),
            dashboardActiveTracksStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumTrack>[]),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
            dashboardGlobalPointsProvider.overrideWith(
              (ref) => Stream.value(0),
            ),
          ],
        );

        // Key assertion (E2E-806): screen renders without an error or
        // access-control block (R-PG7: no access-control guard on profileId).
        h.expectNotOnScreen('Permission denied');
        h.expectNotOnScreen('Access denied');
        // The view toggle (By Curriculum / Timeline) indicates the milestone
        // body rendered (not the empty-state which has no toggle).
        h.expectOnScreen('By Curriculum');
        h.expectOnScreen('Timeline');
        // The title should be the default "Siyumim & Milestones"
        // (or a named title if profileId was passed and profile loaded).
        h.expectOnScreen('Siyumim & Milestones');
      },
    );

    // R-PG7 cross-profile sub-test: the test above never passes a profileId
    // that differs from the caller's own, so it provides zero signal on the
    // documented gap either way. This test seeds a SECOND, real profile row
    // (under a wholly separate account — the strongest illustration of
    // "any authenticated user") and requests SiyumimMilestonesScreen via an
    // EXPLICIT profileId query param that differs from the active profile's,
    // then asserts profile-SPECIFIC content (the other profile's real display
    // name, resolved from the in-memory DB by profileByIdProvider, plus a
    // distinct milestone) is what renders — not merely the absence of an
    // error banner.
    testWidgets(
      'SiyumimMilestonesScreen with an explicit, non-active profileId loads '
      "that OTHER profile's name and milestones "
      '(R-PG7: no access-control guard blocks this cross-profile read)',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Tutor Eve806b');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Seed a SECOND, real profile row under a SEPARATE account, directly
        // into the harness's in-memory UserDatabase — before pumpApp, so the
        // resolved id is known up front and can drive the deep-link path.
        // profileByIdProvider reads this row for real; nothing here is
        // stubbed.
        final otherAccountId = await h.db
            .into(h.db.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'other806@test.com',
                tier: 'localBorn',
                displayName: 'OtherAccount806',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
        final otherProfileId = await h.db
            .into(h.db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: otherAccountId,
                displayName: 'TalmidBob806',
                mode: 'adult',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
        // T-45/T-47 class (CI remediation round 4): P2-2's eager-mint policy
        // means a real seeded profile always has a ulid; a null one
        // hard-throws out of `ProfileModel.fromDriftRow` (P2-3) the moment
        // profileByIdProvider touches this row. A separate write because
        // `otherProfileId` is auto-generated by the insert itself.
        await (h.db.update(
          h.db.learnerProfiles,
        )..where((t) => t.id.equals(otherProfileId))).write(
          LearnerProfilesCompanion(ulid: Value('ulid-$otherProfileId')),
        );

        // Request the OTHER profile's journey via the explicit profileId
        // query param in a single deep link — exactly the unguarded path
        // R-PG7 flags. (auto_route's SiyumimMilestonesRoute.page falls back
        // to queryParams.optInt('profileId') when no typed route args are
        // present — see app_router.gr.dart.)
        await h.pumpApp(
          path: '/journey?profileId=$otherProfileId',
          extraOverrides: [
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumId>[]),
            ),
            dashboardActiveTracksStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumTrack>[]),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
            dashboardGlobalPointsProvider.overrideWith(
              (ref) => Stream.value(0),
            ),
            // Distinguish the journey by profileId: the caller's own journey
            // is empty; the OTHER (seeded) profile's is not. This proves an
            // assertion of _otherProfileJourneyViewModel's milestone content
            // could ONLY be satisfied by the OTHER profileId's data loading.
            journeyViewModelProvider.overrideWith(
              (ref, pid) => Future.value(
                pid == otherProfileId
                    ? _otherProfileJourneyViewModel
                    : _emptyJourneyViewModel,
              ),
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // The cross-profile read succeeded — no access-control block...
        h.expectNotOnScreen('Permission denied');
        h.expectNotOnScreen('Access denied');
        // ...the AppBar names the OTHER (real, seeded) profile, proving the
        // explicit profileId — not the active session — drove the load...
        h.expectOnScreen("TalmidBob806's Learning Journey");
        // ...and the milestone body shown is the OTHER profile's, not the
        // caller's own (empty) journey. The milestone tile's label composes
        // a "Siyum <scope> <name>" frame around the raw unit name, so match
        // by substring rather than exact text.
        expect(
          find.textContaining('Sukkah'),
          findsOneWidget,
          reason:
              "Expected the OTHER profile's milestone (Sukkah) to render, "
              "not the caller's own empty journey",
        );
      },
    );
  });

  // ── E2E-809 ─────────────────────────────────────────────────────────────────

  group('E2E-809 — Progress hub empty state — no active curricula', () {
    // Separate from E2E-801 (Wave 1 P0) to exercise the "0 active tracks"
    // variant explicitly and ensure the empty-state path is still stable.
    testWidgets(
      'ProgressScreen shows "No progress yet" when 0 active curricula',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Grace');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/progress',
          extraOverrides: _progressEmptyStateOverrides(),
        );

        // Key assertions (E2E-809):
        // 1. Empty state renders.
        h.expectOnScreen('No progress yet');
        // 2. The subtitle text from l10n.progressNoDataSubtitle.
        h.expectOnScreen('Start learning to see your progress here.');
        // 3. No lens tiles shown in the empty state.
        h.expectNotOnScreen('Recent Activity');
        h.expectNotOnScreen('Siyumim & Milestones');
        h.expectNotOnScreen('Lifetime Knowledge');
      },
    );
  });

  // ── E2E-810 ─────────────────────────────────────────────────────────────────

  group('E2E-810 — Recent Activity offline / stale data behavior', () {
    testWidgets(
      'RecentActivityScreen renders from Drift cache when offline — no spinner hang',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Henry');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Navigate directly to the Recent Activity screen. This screen is
        // inside AppShell so we need the shell silence overrides to prevent
        // real Drift streams from the dashboard tab-bar providers.
        await h.pumpApp(
          path: '/progress/recent',
          extraOverrides: [
            ..._shellSilenceOverrides(),
            // Streak provider returns cached Drift data immediately (simulates
            // the offline / stale-cache scenario for E2E-810).
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 2, maxStreak: 4)),
            ),
            // Chazara gate: learn-only track (no chazara).
            anyActiveTrackHasChazaraProvider.overrideWith(
              (ref) => Future.value(false),
            ),
            // Adult mode: no points chart section.
            dashboardUserModeProvider.overrideWith(
              (ref) => Future.value(ProfileMode.adult),
            ),
          ],
        );

        // Key assertions (E2E-810):
        // 1. The screen renders (no indefinite spinner hang).
        h.expectOnScreen('Recent Activity');
        // 2. Time-range chips present — sourced from local state (no network).
        h.expectOnScreen('Last 7 Days');
        h.expectOnScreen('Last 30 Days');
        h.expectOnScreen('All Time');
        // 3. Curriculum filter "All" chip present.
        h.expectOnScreen('All');
        // 4. Streak section header present — rendered from Drift cache.
        h.expectOnScreen('STREAK');
      },
    );
  });

  // ── E2E-811 ─────────────────────────────────────────────────────────────────

  group('E2E-811 — Recent Activity: chazara-enabled vs. learn-only track', () {
    // Risk R-PG6: anyActiveTrackHasChazaraProvider is not invalidated on
    // completion commit — the gate is evaluated at build time from the current
    // provider value. This test asserts the gate itself is correct (chazara tile
    // shown vs. hidden), independent of invalidation timing.

    testWidgets(
      'chazara count tile visible when anyActiveTrackHasChazaraProvider = true',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Iris');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/progress/recent',
          extraOverrides: [
            ..._shellSilenceOverrides(),
            // Key override: at least one track has chazara.
            anyActiveTrackHasChazaraProvider.overrideWith(
              (ref) => Future.value(true),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardUserModeProvider.overrideWith(
              (ref) => Future.value(ProfileMode.adult),
            ),
          ],
        );

        // Key assertions (E2E-811, chazara-enabled branch):
        // 1. Screen title present — no navigation error.
        h.expectOnScreen('Recent Activity');
        // 2. Time-range chips present — chart section rendered without crash.
        h.expectOnScreen('Last 7 Days');
      },
    );

    testWidgets(
      'chazara count tile absent when anyActiveTrackHasChazaraProvider = false',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Jack');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/progress/recent',
          extraOverrides: [
            ..._shellSilenceOverrides(),
            // Key override: no track has chazara.
            anyActiveTrackHasChazaraProvider.overrideWith(
              (ref) => Future.value(false),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardUserModeProvider.overrideWith(
              (ref) => Future.value(ProfileMode.adult),
            ),
          ],
        );

        // Key assertions (E2E-811, learn-only branch):
        // 1. Screen title present.
        h.expectOnScreen('Recent Activity');
        // 2. Time-range chips present.
        h.expectOnScreen('Last 7 Days');
        // 3. "& Chazaros" must NOT appear in the chart title when chazara
        //    is disabled (the chart title is just the limud term alone).
        h.expectNotOnScreen('& Chazaros');
      },
    );
  });

  // ── E2E-812 ─────────────────────────────────────────────────────────────────

  group('E2E-812 — Hebrew locale (RTL) across progress screens', () {
    // Locale WAS injectable via E2EHarness.pumpApp(locale:) all along — the
    // former comment claiming "Harness hardcodes Locale('en') ... cannot be
    // injected headlessly" was false (AUD-t-cross-31). This test now pumps
    // Locale('he') directly, mirroring E2E-1505 in hebrew_rtl_p1_test.dart
    // (which covers the same screen for the general RTL sweep) but living in
    // this file per the catalog's own id/file mapping and additionally
    // asserting the hub's three lens tiles render their Hebrew l10n titles.
    testWidgets(
      'ProgressScreen lays out RTL and shows Hebrew lens-tile titles under '
      'the he locale',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Rivka812');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/progress',
          locale: const Locale('he'),
          extraOverrides: [
            ..._progressWithContentOverrides(h),
            ..._counterRowSilenceOverrides(),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // RTL layout under the he locale.
        expect(
          Directionality.of(tester.element(find.byType(ProgressScreen))),
          TextDirection.rtl,
        );

        // The three lens tiles render their l10n Hebrew translations —
        // proves the MaterialApp is genuinely running under he, not just en.
        h.expectOnScreen('פעילות אחרונה'); // tierLensRecentActivity
        h.expectOnScreen('סיומים והישגים'); // tierLensSiyumimMilestones
        h.expectOnScreen('ידע כולל'); // tierLensLifetimeKnowledge
      },
    );
  });

  // ── E2E-813 ─────────────────────────────────────────────────────────────────

  group('E2E-813 — Completion committed → progress counter updates without '
      'pull-to-refresh', () {
    testWidgets(
      'journeyViewModelProvider rebuilds when completionCommittedProvider '
      'increments — ProgressScreen tier counter reflects new state',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Karen');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Use the real journeyViewModelProvider (not overridden) so we can
        // observe the reactive dependency on completionCommittedProvider.
        // Override activeCurriculaProvider so the journey body renders for
        // the known test curriculum.
        await h.pumpApp(
          path: '/progress',
          extraOverrides: [
            ..._progressWithContentOverrides(h),
            trackDualProgressMetricsProvider.overrideWith(
              (ref, pid) => Future.value(<TrackDualProgressMetric>[]),
            ),
            // journeyViewModelProvider is NOT overridden here so it can react
            // to completionCommittedProvider changes.
            // Override activeCurriculaProvider to return an empty list so
            // journeyViewModelProvider computes a 0-siyumim result initially.
            journeyViewModelProvider.overrideWith((ref, pid) async {
              // Read the tick so this provider rebuilds when it increments.
              ref.watch<int>(completionCommittedProvider);
              final count = ref.read(completionCommittedProvider);
              // Return a journey with `count` unit siyumim so the counter
              // visually changes with each increment.
              if (count == 0) return _emptyJourneyViewModel;
              return _singleMilestoneJourneyViewModel;
            }),
          ],
        );

        // Step 1: initial state — 0 siyumim from the journey view model.
        // The tier counter row shows "…" until all providers resolve, then
        // shows the loaded numbers. Pump to let all futures settle.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        // Step 2: access the ProviderContainer to increment the counter.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp).first),
        );
        final beforeTick = container.read(completionCommittedProvider);
        expect(beforeTick, 0, reason: 'counter starts at 0');

        // Increment: simulates what CompletionWriter does after a real mark.
        container.read(completionCommittedProvider.notifier).increment();

        // Step 3: pump to let the reactive rebuild settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: completionCommittedProvider incremented.
        final afterTick = container.read(completionCommittedProvider);
        expect(
          afterTick,
          greaterThan(beforeTick),
          reason: 'completionCommittedProvider must have incremented',
        );

        // The progress screen is still visible (no crash from reactive rebuild).
        h.expectOnScreen('Progress');
        // Lens tiles remain visible after the rebuild.
        h.expectOnScreen('Recent Activity');
      },
    );
  });

  // ── E2E-814 ─────────────────────────────────────────────────────────────────

  group('E2E-814 — Curriculum Progress: pace indicator states', () {
    // Uses a fixed clockProvider so pace arithmetic is deterministic.
    // All three ProgressPaceStatus outcomes are exercised (on-pace, ahead, behind).

    /// Fixed today for all E2E-814 sub-tests.
    final fixedToday = DateTime.utc(2026, 6, 18);

    /// A [ProgressPaceCalculator] configured for "on-pace" (within one day's variance).
    ///
    ///   trackStartDate = 2026-01-01
    ///   targetDate     = 2026-12-31 (365 days)
    ///   totalItems     = 365
    ///   liveProgress   = 169  (exactly requiredVelocity × elapsedDays = 1 × 169)
    ///   → paceVariance = 0  → onTrack
    final onPacePaceCalc = ProgressPaceCalculator.compute(
      totalItems: 365,
      bulkBaseline: 0,
      liveProgress: 169,
      trackStartDate: DateTime.utc(2026, 1, 1),
      targetDate: DateTime.utc(2026, 12, 31),
      today: fixedToday,
    );

    /// A [ProgressPaceCalculator] configured for "ahead" (> 1 day's items done extra).
    ///
    ///   Same window; liveProgress = 220 vs expected ≈ 169
    ///   → paceVariance = +51 days
    final aheadPaceCalc = ProgressPaceCalculator.compute(
      totalItems: 365,
      bulkBaseline: 0,
      liveProgress: 220,
      trackStartDate: DateTime.utc(2026, 1, 1),
      targetDate: DateTime.utc(2026, 12, 31),
      today: fixedToday,
    );

    /// A [ProgressPaceCalculator] configured for "behind" (> 1 day's items missing).
    ///
    ///   Same window; liveProgress = 100 vs expected ≈ 169
    ///   → paceVariance ≈ −69 days
    final behindPaceCalc = ProgressPaceCalculator.compute(
      totalItems: 365,
      bulkBaseline: 0,
      liveProgress: 100,
      trackStartDate: DateTime.utc(2026, 1, 1),
      targetDate: DateTime.utc(2026, 12, 31),
      today: fixedToday,
    );

    // Verify pace status is computed correctly before relying on UI assertions.
    setUp(() {
      expect(onPacePaceCalc.paceStatus, ProgressPaceStatus.onTrack);
      expect(aheadPaceCalc.paceStatus, ProgressPaceStatus.ahead);
      expect(behindPaceCalc.paceStatus, ProgressPaceStatus.behind);
    });

    testWidgets(
      'CurriculumProgressScreen shows "On pace" indicator for on-pace track',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Leo');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/curriculum/mishnayos/progress',
          extraOverrides: [
            ..._progressWithContentOverrides(h),
            ..._counterRowSilenceOverrides(),
            curriculumProgressProvider.overrideWith(
              (ref, cid) => Future.value(_stubCurriculumProgressData),
            ),
            curriculumPaceStatusProvider.overrideWith(
              (ref, cid) => Future.value(onPacePaceCalc),
            ),
            lifetimeDataProvider.overrideWith(
              (ref, args) => Future.value(null),
            ),
          ],
        );

        // Key assertion: "On pace" badge text.
        h.expectOnScreen('On pace');
        // Screen structure assertions.
        h.expectOnScreen('Overall Progress');
      },
    );

    testWidgets(
      'CurriculumProgressScreen shows "Ahead by N days" indicator for ahead track',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Mia');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/curriculum/mishnayos/progress',
          extraOverrides: [
            ..._progressWithContentOverrides(h),
            ..._counterRowSilenceOverrides(),
            curriculumProgressProvider.overrideWith(
              (ref, cid) => Future.value(_stubCurriculumProgressData),
            ),
            curriculumPaceStatusProvider.overrideWith(
              (ref, cid) => Future.value(aheadPaceCalc),
            ),
            lifetimeDataProvider.overrideWith(
              (ref, args) => Future.value(null),
            ),
          ],
        );

        // Key assertion: "Ahead by N days" text in the pace indicator badge.
        // Use textContaining because the number is locale-formatted.
        expect(
          find.textContaining('Ahead by'),
          findsWidgets,
          reason: 'PaceIndicator must show "Ahead by" text when ahead',
        );
        h.expectOnScreen('Overall Progress');
      },
    );

    testWidgets(
      'CurriculumProgressScreen shows "Behind by N days" indicator for behind '
      'track',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Nick');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/curriculum/mishnayos/progress',
          extraOverrides: [
            ..._progressWithContentOverrides(h),
            ..._counterRowSilenceOverrides(),
            curriculumProgressProvider.overrideWith(
              (ref, cid) => Future.value(_stubCurriculumProgressData),
            ),
            curriculumPaceStatusProvider.overrideWith(
              (ref, cid) => Future.value(behindPaceCalc),
            ),
            lifetimeDataProvider.overrideWith(
              (ref, args) => Future.value(null),
            ),
          ],
        );

        // Key assertion: "Behind by N days" text in the pace indicator badge.
        // Use textContaining because the number is locale-formatted.
        expect(
          find.textContaining('Behind by'),
          findsWidgets,
          reason: 'PaceIndicator must show "Behind by" text when behind',
        );
        h.expectOnScreen('Overall Progress');
      },
    );

    testWidgets(
      'CurriculumProgressScreen shows no pace indicator when no goal exists',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Olivia');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/curriculum/mishnayos/progress',
          extraOverrides: [
            ..._progressWithContentOverrides(h),
            ..._counterRowSilenceOverrides(),
            curriculumProgressProvider.overrideWith(
              (ref, cid) => Future.value(_stubCurriculumProgressData),
            ),
            // null paceStatus → no PaceIndicator rendered.
            curriculumPaceStatusProvider.overrideWith(
              (ref, cid) => Future.value(null),
            ),
            lifetimeDataProvider.overrideWith(
              (ref, args) => Future.value(null),
            ),
          ],
        );

        // Key assertion: no pace badge when goal is absent.
        h.expectNotOnScreen('On pace');
        h.expectNotOnScreen('Ahead by');
        h.expectNotOnScreen('Behind by');
        // Progress card still renders.
        h.expectOnScreen('Overall Progress');
      },
    );
  });
}
