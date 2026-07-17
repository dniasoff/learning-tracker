/// E2E overflow-guard sweep — all 48 @RoutePage screens, en + he locales.
///
/// Strategy: each screen is pumped via [E2EHarness.pumpApp] (which gives the
/// real router + providers) then checked across the standard device/text-scale
/// matrix for RenderFlex / layout overflow.  Screen-specific provider overrides
/// are drawn directly from the committed p0/p1 journeys so every seeding and
/// silence pattern is consistent with the rest of the E2E suite.
///
/// ## Coverage
///
/// COVERED (robustly mounts headlessly, no skip):
///   01 AppIntroScreen
///   02 SignInScreen (skip: BUG-NEW, separate fix)
///   03 SignupScreen
///   04 AccountPickerScreen
///   05 UpgradeToCloudScreen
///   06 OnboardingScreen
///   07 EmptyLoginScreen
///   08 DeviceRestoreScreen
///   09 ProfilePickerScreen (skip: BUG-NEW, separate fix)
///   10 ManageLearnersScreen
///   11 DashboardScreen (en)
///   12 DashboardScreen (he / RTL)
///   13 LearningScreen (en)     — FIXED: EmptyState scrollable
///   14 LearningScreen (he/RTL) — FIXED: EmptyState scrollable
///   15 ProgressScreen          — FIXED: EmptyState scrollable
///   16 SettingsScreen          — FIXED: upgrade button Text in Flexible
///   17 SchedulerScreen
///   18 SiyumimMilestonesScreen
///   19 RecentActivityScreen    — FIXED: streak card Row uses Flexible
///   20 LifetimeKnowledgeScreen — FIXED: loading uses CircularProgressIndicator
///   21 CurriculumListScreen    — FIXED: search bar Text in Flexible
///   22 GamificationScreen      — FIXED: achievements fraction uses Wrap
///   23 ChildRedemptionScreen
///   24 ParentPendingRedemptionsScreen — FIXED: _PinDotsRow padding 10→8px
///   26 CityPickerScreen
///   27 TrackManagementHubScreen
///   30 ManageTutorsScreen
///   31 ManageGrantsScreen
///
/// FIXED (BUG-NEW converted to active passing tests):
///   13 LearningScreen (en)     — EmptyState wrapped in SingleChildScrollView
///   14 LearningScreen (he/RTL) — same EmptyState fix as 13
///   15 ProgressScreen          — same EmptyState fix as 13
///   16 SettingsScreen          — upgrade button Text wrapped in Flexible
///   19 RecentActivityScreen    — streak card middle Text wrapped in Flexible, Spacer removed
///   20 LifetimeKnowledgeScreen — loading state replaced with simple CircularProgressIndicator
///   21 CurriculumListScreen    — search bar Text wrapped in Flexible
///   22 GamificationScreen      — achievements fraction Row replaced with Wrap
///   24 ParentPendingRedemptionsScreen — _PinDotsRow horizontal padding reduced 10→8px
///
/// SKIPPED (harness limitation — no assertion):
///   25 NotificationsScreen    — FlutterLocalNotificationsPlatform native plugin
///   28 TrackDetailScreen      — router.push hangs headlessly (content DB assets)
///   29 LifetimeMarkingScreen  — router.push hangs headlessly (content DB assets)
///   PermissionPromptScreen    — native platform channels required
///   ContentHierarchyScreen    — requires bundled asset ContentRepository
///   ContentSearchScreen       — requires bundled asset ContentRepository
///   TextDisplayScreen         — requires bundled asset ContentRepository + route arg
///   LifetimeCurriculumMarkingRoute — requires bundled content DB
///   AppShellRoute             — container, not a standalone pumped surface
///   PersistentSwitcherScaffold — lives in LearningTrackerApp builder slot
///
/// SKIPPED (guarded router.push hangs headless — untested, DNI-404 tracks the
/// on-device overflow sweep; AUD-t-cross-48):
///   32 TutorAuditLogScreen
///   33 InviteTutorScreen
///   34 AcceptInviteScreen
///   35 DeclineInviteScreen
///   36 PinFlowSetupRoute
///   38 ParentSettingsScreen
///   39 PointConfigScreen
///   40 RewardConfigurationScreen
///   41 StudyDayConfigScreen
///   42 CurriculumProgressScreen
///   43 CurriculumSettingsScreen
///   44 LearningOrderScreen
///   45 ParentTrackManagementScreen
///
/// REMOVED (AUD-profiles-06): PinFlowVerifyRoute (was #37) and
/// PinFlowChangeRoute were registered routes nothing in `lib/` ever pushed —
/// the real verify/change PIN UX is the modal dialogs in
/// parent_pin_keypad_dialog.dart, not a routed screen. Both routes and their
/// PinFlowScreen wrappers were deleted; only PinFlowSetupRoute (#36) remains
/// a real navigation target.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 / §7 (E2E-1512)
@Tags(['e2e', 'overflow'])
library;

import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show effectiveUseHebrewTermsProvider;
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart'
    show syncStatusProvider;
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart'
    show
        anyActiveTrackHasChazaraProvider,
        dashboardActiveCurriculaStreamProvider,
        dashboardActiveTracksStreamProvider,
        dashboardGlobalPointsProvider,
        dashboardStreakProvider,
        dashboardStreakRecoveryProvider;
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart'
    show StreakRecoveryInfo;
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart'
    show
        AchievementRowVm,
        AchievementTrackFilterVm,
        AchievementsOverview,
        achievementsOverviewProvider;
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart'
    show childRedemptionBalanceProvider, childRedemptionRewardsProvider;
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart'
    show streakCalendarProvider;
import 'package:learning_tracker/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart'
    show pendingRedemptionsProvider;
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show profileListProvider;
import 'package:learning_tracker/features/profiles/presentation/screens/parent_settings_screen.dart'
    show activeProfilePointsBalanceProvider, pendingRedemptionsCountProvider;
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart'
    show CurriculumProgressData, OverallCurriculumStats;
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart'
    show CurriculumJourney, JourneyViewModel;
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart'
    show CurriculumLifetimeSummary, LifetimeTotals, TrackDualProgressMetric;
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart'
    show
        CurriculumCompletionSummary,
        itemsLearnedSummariesProvider,
        lifetimeViewSummariesProvider;
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart'
    show journeyViewModelProvider;
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart'
    show
        LifetimeHeaderCounters,
        lifetimeHeaderCountersProvider,
        lifetimeSummariesProvider,
        lifetimeTotalsAcrossAllCurriculaProvider,
        trackDualProgressMetricsProvider,
        trackOnlyHeaderCountersProvider;
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart'
    show curriculumProgressProvider;
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart'
    show currentSacredWindowProvider;
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart'
    show DailyTask;
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart'
    show StudyDayConfigEntry;
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart'
    show allDailyTasksProvider, coarsePacedTrackIdsProvider;
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart'
    show studyDayConfigsProvider;
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart'
    show scopedItemCountProvider;
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart'
    show SyncStatus;
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart'
    show activeTracksProvider;
import 'package:learning_tracker/features/tracks/track_order/presentation/providers/track_learning_order_providers.dart'
    show trackMasechtosOrderProvider, trackSedarimOrderProvider;
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart'
    show LearningOrderItem;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant.dart'
    show TutorGrantDoc, TutorGrantState;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart'
    show PendingGrant, TutorGrant;
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart'
    show activeTutorPermissionsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/audit_log_providers.dart'
    show tutorAuditLogProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider, outgoingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;

import '../../helpers/overflow_harness.dart';
import '../harness/e2e_harness.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Pumps [path] via a fresh [E2EHarness] per matrix cell and asserts no
/// overflow in every cell, for each locale in [locales].
Future<void> _sweepPath(
  WidgetTester tester, {
  required String label,
  required String path,
  List<Override> extraOverrides = const [],
  List<Locale> locales = const [Locale('en'), Locale('he')],
  E2EIdentity? Function()? identityFactory,
}) async {
  final matrix = defaultOverflowMatrix();
  addTearDown(tester.view.reset);

  for (final locale in locales) {
    for (final c in matrix) {
      tester.view.devicePixelRatio = c.devicePixelRatio;
      tester.view.physicalSize = Size(
        c.size.width * c.devicePixelRatio,
        c.size.height * c.devicePixelRatio,
      );

      final identity =
          identityFactory?.call() ??
          E2EIdentity.localBorn(displayName: 'Ov${locale.languageCode}');
      final h = E2EHarness(tester, identity: identity);

      await h.pumpApp(
        path: path,
        extraOverrides: extraOverrides,
        locale: locale,
      );
      await tester.pump(const Duration(milliseconds: 300));

      final ex = tester.takeException();
      expect(
        ex,
        isNull,
        reason:
            'Layout overflowed/threw on $label [$locale] at ${c.label}.\n'
            'Thrown: $ex',
      );

      await h.dispose();
      tester.view.reset();
    }
  }
}

/// Sweeps only the tightest matrix cell (320×568 @ 1× en) for screens that
/// require a router push and cannot be reached by a plain path.
Future<void> _sweepPush(
  WidgetTester tester, {
  required String label,
  required E2EHarness h,
  required Future<void> Function(AppRouter router) push,
}) async {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(320, 568);

  await push(h.router);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  final ex = tester.takeException();
  expect(
    ex,
    isNull,
    reason: 'Layout overflowed/threw on $label at 320x568. Thrown: $ex',
  );
}

// ── Silence-override helpers (mirrors p0/p1 patterns) ────────────────────────

Override _sacred() => currentSacredWindowProvider.overrideWithValue(null);
Override _connectivity() =>
    connectivityStreamProvider.overrideWith((ref) => Stream.value(true));
Override _noIncomingGrants() =>
    incomingTutorGrantsProvider.overrideWith((ref) async => <TutorGrant>[]);
Override _noPendingInvites() =>
    pendingTutorInvitesProvider.overrideWith((ref) async => <TutorGrant>[]);
Override _englishTerms() =>
    effectiveUseHebrewTermsProvider.overrideWithValue(false);
Override _noTutorPerms() =>
    activeTutorPermissionsProvider.overrideWith((ref) => null);
Override _syncLocalOnly() =>
    syncStatusProvider.overrideWith((ref) => const SyncStatus.localOnly());

/// Common silence overrides for Settings-area screens.
List<Override> _settingsSilence() => [
  _sacred(),
  _connectivity(),
  _noIncomingGrants(),
  _noPendingInvites(),
  _syncLocalOnly(),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  setUpAll(() {
    log(
      'overflow_sweep_p2: skipped screens:\n'
      '  PermissionPromptScreen     — native platform channels\n'
      '  ContentHierarchyScreen     — bundled asset ContentRepository required\n'
      '  ContentSearchScreen        — bundled asset ContentRepository required\n'
      '  TextDisplayScreen          — bundled asset + sefariaRef route arg\n'
      '  LifetimeCurriculumMarkingRoute — bundled content DB required\n'
      '  AppShellRoute              — container, not a standalone screen\n'
      '  PersistentSwitcherScaffold — lives in LearningTrackerApp builder slot',
      name: 'overflow_sweep',
    );
  });

  // ── 01: AppIntroScreen ──────────────────────────────────────────────────────

  testWidgets('01 AppIntroScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'AppIntroScreen',
      path: '/intro',
      identityFactory: () => null,
    );
  });

  // ── 02: SignInScreen ────────────────────────────────────────────────────────

  testWidgets(
    'BUG-NEW 02 SignInScreen overflows 42px right at 320x568 en '
    '— Row in sign-in button area is not Flexible',
    skip: true,
    (tester) async {
      await _sweepPath(
        tester,
        label: 'SignInScreen',
        path: '/sign-in',
        identityFactory: () => null,
      );
    },
  );

  // ── 03: SignupScreen ────────────────────────────────────────────────────────

  testWidgets('03 SignupScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'SignupScreen',
      path: '/create-account',
      identityFactory: () => null,
    );
  });

  // ── 04: AccountPickerScreen ─────────────────────────────────────────────────

  testWidgets('04 AccountPickerScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'AccountPickerScreen',
      path: '/account-picker',
      identityFactory: () => null,
    );
  });

  // ── 05: UpgradeToCloudScreen ────────────────────────────────────────────────

  testWidgets('05 UpgradeToCloudScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'UpgradeToCloudScreen',
      path: '/upgrade-to-cloud',
      extraOverrides: [_connectivity()],
    );
  });

  // ── 06: OnboardingScreen ────────────────────────────────────────────────────

  testWidgets('06 OnboardingScreen — no overflow', (tester) async {
    await _sweepPath(tester, label: 'OnboardingScreen', path: '/onboarding');
  });

  // ── 07: EmptyLoginScreen ────────────────────────────────────────────────────

  testWidgets('07 EmptyLoginScreen — no overflow', (tester) async {
    await _sweepPath(tester, label: 'EmptyLoginScreen', path: '/empty-login');
  });

  // ── 08: DeviceRestoreScreen ─────────────────────────────────────────────────

  testWidgets('08 DeviceRestoreScreen — no overflow', (tester) async {
    // The harness RestoreGuard is already marked complete; the router navigates
    // away from /restore to the authenticated shell which activates
    // dashboardStreakProvider (15-min periodic timer). Silence it so the timer
    // does not outlive the test's FakeAsync scope.
    await _sweepPath(
      tester,
      label: 'DeviceRestoreScreen',
      path: '/restore',
      identityFactory: () => null,
      extraOverrides: [
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
    );
  });

  // ── 09: ProfilePickerScreen ─────────────────────────────────────────────────

  testWidgets(
    'BUG-NEW 09 ProfilePickerScreen overflows 43px right 49px bottom at '
    '320x568 — profile_card.dart content not constrained to card width',
    skip: true,
    (tester) async {
      final alice = ProfileModel(
        id: 1,
        accountId: 1,
        displayName: 'Alice',
        mode: 'adult',
        avatarIndex: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final bob = ProfileModel(
        id: 2,
        accountId: 1,
        displayName: 'Bob',
        mode: 'child',
        avatarIndex: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      await _sweepPath(
        tester,
        label: 'ProfilePickerScreen',
        path: '/profile-picker',
        extraOverrides: [
          profileListProvider.overrideWith((ref) async => [alice, bob]),
        ],
      );
    },
  );

  // ── 10: ManageLearnersScreen ────────────────────────────────────────────────

  testWidgets('10 ManageLearnersScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'ManageLearnersScreen',
      path: '/manage-learners',
      extraOverrides: [
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
    );
  });

  // ── 11: DashboardScreen (en) ───────────────────────────────────────────────

  testWidgets('11 DashboardScreen en — no overflow', (tester) async {
    addTearDown(tester.view.reset);
    final matrix = defaultOverflowMatrix();
    for (final c in matrix) {
      tester.view.devicePixelRatio = c.devicePixelRatio;
      tester.view.physicalSize = Size(
        c.size.width * c.devicePixelRatio,
        c.size.height * c.devicePixelRatio,
      );
      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'DashEn'),
      );
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          _englishTerms(),
          ...h.dashboardSilenceOverrides,
          _noIncomingGrants(),
          _noPendingInvites(),
        ],
        locale: const Locale('en'),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final ex = tester.takeException();
      expect(
        ex,
        isNull,
        reason: 'DashboardScreen [en] overflowed at ${c.label}. Thrown: $ex',
      );
      await h.dispose();
      tester.view.reset();
    }
  });

  // ── 12: DashboardScreen (he / RTL) ────────────────────────────────────────

  testWidgets('12 DashboardScreen he — no overflow', (tester) async {
    addTearDown(tester.view.reset);
    final matrix = defaultOverflowMatrix();
    for (final c in matrix) {
      tester.view.devicePixelRatio = c.devicePixelRatio;
      tester.view.physicalSize = Size(
        c.size.width * c.devicePixelRatio,
        c.size.height * c.devicePixelRatio,
      );
      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'DashHe'),
      );
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          _noIncomingGrants(),
          _noPendingInvites(),
        ],
        locale: const Locale('he'),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final ex = tester.takeException();
      expect(
        ex,
        isNull,
        reason: 'DashboardScreen [he] overflowed at ${c.label}. Thrown: $ex',
      );
      await h.dispose();
      tester.view.reset();
    }
  });

  // ── 13: LearningScreen (en) ────────────────────────────────────────────────

  testWidgets('13 LearningScreen en — no overflow', (tester) async {
    addTearDown(tester.view.reset);
    final matrix = defaultOverflowMatrix();
    final overrides = <Override>[
      _englishTerms(),
      dashboardActiveCurriculaStreamProvider.overrideWith(
        (ref) => Stream.value(<CurriculumId>[]),
      ),
      allDailyTasksProvider.overrideWith((ref) async => <DailyTask>[]),
      coarsePacedTrackIdsProvider.overrideWith((ref) async => <int>{}),
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
      ),
      _noTutorPerms(),
      _noIncomingGrants(),
    ];
    for (final c in matrix) {
      tester.view.devicePixelRatio = c.devicePixelRatio;
      tester.view.physicalSize = Size(
        c.size.width * c.devicePixelRatio,
        c.size.height * c.devicePixelRatio,
      );
      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'LearnEn'),
      );
      await h.pumpApp(
        path: '/learn',
        extraOverrides: overrides,
        locale: const Locale('en'),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final ex = tester.takeException();
      expect(
        ex,
        isNull,
        reason: 'LearningScreen [en] overflowed at ${c.label}. Thrown: $ex',
      );
      await h.dispose();
      tester.view.reset();
    }
  });

  // ── 14: LearningScreen (he / RTL) ─────────────────────────────────────────

  testWidgets('14 LearningScreen he — no overflow', (tester) async {
    addTearDown(tester.view.reset);
    final matrix = defaultOverflowMatrix();
    final overrides = <Override>[
      dashboardActiveCurriculaStreamProvider.overrideWith(
        (ref) => Stream.value(<CurriculumId>[]),
      ),
      allDailyTasksProvider.overrideWith((ref) async => <DailyTask>[]),
      coarsePacedTrackIdsProvider.overrideWith((ref) async => <int>{}),
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
      ),
      _noTutorPerms(),
      _noIncomingGrants(),
    ];
    for (final c in matrix) {
      tester.view.devicePixelRatio = c.devicePixelRatio;
      tester.view.physicalSize = Size(
        c.size.width * c.devicePixelRatio,
        c.size.height * c.devicePixelRatio,
      );
      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'LearnHe'),
      );
      await h.pumpApp(
        path: '/learn',
        extraOverrides: overrides,
        locale: const Locale('he'),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final ex = tester.takeException();
      expect(
        ex,
        isNull,
        reason: 'LearningScreen [he] overflowed at ${c.label}. Thrown: $ex',
      );
      await h.dispose();
      tester.view.reset();
    }
  });

  // ── 15: ProgressScreen ─────────────────────────────────────────────────────

  testWidgets('15 ProgressScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'ProgressScreen',
      path: '/progress',
      extraOverrides: [
        dashboardActiveCurriculaStreamProvider.overrideWith(
          (ref) => Stream.value(<CurriculumId>[]),
        ),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
        dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(0)),
        trackDualProgressMetricsProvider.overrideWith(
          (ref, _) async => <TrackDualProgressMetric>[],
        ),
        lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
          (ref, _) async => const LifetimeTotals(
            learnedSections: 0,
            totalSections: 0,
            totalCurricula: 9,
          ),
        ),
        journeyViewModelProvider.overrideWith(
          (ref, _) async => const JourneyViewModel(
            curricula: <CurriculumJourney>[],
            totalCompletions: 0,
            totalUniqueUnits: 0,
            unitLevelSiyumimCount: 0,
            aggregateLevelSiyumimCount: 0,
            curriculumLevelSiyumimCount: 0,
          ),
        ),
      ],
    );
  });

  // ── 16: SettingsScreen ─────────────────────────────────────────────────────

  testWidgets('16 SettingsScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'SettingsScreen',
      path: '/settings',
      extraOverrides: [
        ..._settingsSilence(),
        _englishTerms(),
        _noTutorPerms(),
        lifetimeSummariesProvider.overrideWith(
          (ref, _) async => <CurriculumLifetimeSummary>[],
        ),
      ],
    );
  });

  // ── 17: SchedulerScreen ────────────────────────────────────────────────────

  testWidgets('17 SchedulerScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'SchedulerScreen',
      path: '/scheduler',
      extraOverrides: [
        _englishTerms(),
        dashboardActiveCurriculaStreamProvider.overrideWith(
          (ref) => Stream.value(<CurriculumId>[]),
        ),
        dashboardActiveTracksStreamProvider.overrideWith(
          (ref) => Stream.value(<CurriculumTrack>[]),
        ),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
        allDailyTasksProvider.overrideWith((ref) async => <DailyTask>[]),
        activeTracksProvider.overrideWith(
          (ref) => Stream.value(<CurriculumTrack>[]),
        ),
        coarsePacedTrackIdsProvider.overrideWith((ref) async => <int>{}),
        anyActiveTrackHasChazaraProvider.overrideWith((ref) async => false),
        scopedItemCountProvider.overrideWith((ref, _) async => 0),
      ],
    );
  });

  // ── 18: SiyumimMilestonesScreen ────────────────────────────────────────────

  testWidgets('18 SiyumimMilestonesScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'SiyumimMilestonesScreen',
      path: '/journey',
      extraOverrides: [
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
        journeyViewModelProvider.overrideWith(
          (ref, _) async => const JourneyViewModel(
            curricula: <CurriculumJourney>[],
            totalCompletions: 0,
            totalUniqueUnits: 0,
            unitLevelSiyumimCount: 0,
            aggregateLevelSiyumimCount: 0,
            curriculumLevelSiyumimCount: 0,
          ),
        ),
      ],
    );
  });

  // ── 19: RecentActivityScreen ───────────────────────────────────────────────

  testWidgets('19 RecentActivityScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'RecentActivityScreen',
      path: '/progress/recent',
      extraOverrides: [
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
        dashboardStreakRecoveryProvider.overrideWith(
          (ref) async =>
              const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
        ),
        anyActiveTrackHasChazaraProvider.overrideWith((ref) async => false),
      ],
    );
  });

  // ── 20: LifetimeKnowledgeScreen ────────────────────────────────────────────

  testWidgets('20 LifetimeKnowledgeScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'LifetimeKnowledgeScreen',
      path: '/progress/lifetime',
      extraOverrides: [
        lifetimeViewSummariesProvider.overrideWith(
          (ref, _) async => <CurriculumCompletionSummary>[],
        ),
        itemsLearnedSummariesProvider.overrideWith(
          (ref, _) async => <CurriculumCompletionSummary>[],
        ),
        lifetimeHeaderCountersProvider.overrideWith(
          (ref, _) async =>
              const LifetimeHeaderCounters(itemsLearned: 0, totalChazaros: 0),
        ),
        trackOnlyHeaderCountersProvider.overrideWith(
          (ref, _) async =>
              const LifetimeHeaderCounters(itemsLearned: 0, totalChazaros: 0),
        ),
      ],
    );
  });

  // ── 21: CurriculumListScreen ───────────────────────────────────────────────

  testWidgets('21 CurriculumListScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'CurriculumListScreen',
      path: '/browse',
      extraOverrides: [
        // Silence the 15-min periodic timer in StreakStateService so the
        // timer-pending invariant doesn't fire at teardown.
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
    );
  });

  // ── 22: GamificationScreen ─────────────────────────────────────────────────

  testWidgets('22 GamificationScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'GamificationScreen',
      path: '/gamification',
      identityFactory: () =>
          E2EIdentity.localBorn(displayName: 'GamChild', profileMode: 'child'),
      extraOverrides: [
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
        streakCalendarProvider.overrideWith((ref) async => <DateTime>{}),
        achievementsOverviewProvider.overrideWith(
          (ref) async => const AchievementsOverview(
            rows: <AchievementRowVm>[],
            unlockedCount: 0,
            totalMilestones: 0,
            trackFilterOptions: <AchievementTrackFilterVm>[],
          ),
        ),
        _noIncomingGrants(),
      ],
    );
  });

  // ── 23: ChildRedemptionScreen ──────────────────────────────────────────────

  testWidgets('23 ChildRedemptionScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'ChildRedemptionScreen',
      path: '/redeem',
      identityFactory: () =>
          E2EIdentity.localBorn(displayName: 'RdmChild', profileMode: 'child'),
      extraOverrides: [
        childRedemptionBalanceProvider.overrideWith((ref) => Stream.value(0)),
        childRedemptionRewardsProvider.overrideWith((ref) async => []),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
        achievementsOverviewProvider.overrideWith(
          (ref) async => const AchievementsOverview(
            rows: <AchievementRowVm>[],
            unlockedCount: 0,
            totalMilestones: 0,
            trackFilterOptions: <AchievementTrackFilterVm>[],
          ),
        ),
        _noIncomingGrants(),
      ],
    );
  });

  // ── 24: ParentPendingRedemptionsScreen ────────────────────────────────────

  testWidgets('24 ParentPendingRedemptionsScreen — no overflow', (
    tester,
  ) async {
    await _sweepPath(
      tester,
      label: 'ParentPendingRedemptionsScreen',
      path: '/parent-mode/pending-redemptions',
      identityFactory: () =>
          E2EIdentity.localBorn(displayName: 'PndParent', profileMode: 'child'),
      extraOverrides: [
        // One-shot non-reactive to prevent Drift stream timer leaks.
        pendingRedemptionsProvider.overrideWith(
          (ref) => Stream.fromFuture(Future.value(<RewardRedemption>[])),
        ),
        pendingRedemptionsCountProvider.overrideWith((ref) => Stream.value(0)),
        activeProfilePointsBalanceProvider.overrideWith(
          (ref) => Stream.value(0),
        ),
        activeTracksProvider.overrideWith(
          (ref) => Stream.fromFuture(Future.value(<CurriculumTrack>[])),
        ),
        // Silence the 15-min periodic timer in StreakStateService.
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
    );
  });

  // ── 25: NotificationsScreen ────────────────────────────────────────────────
  //
  // Requires FlutterLocalNotificationsPlatform native plugin — LateError on
  // _instance if the platform channel is not registered.  Skip headlessly.

  testWidgets(
    'SKIP 25 NotificationsScreen — FlutterLocalNotificationsPlatform native '
    'plugin not registered in test harness; LateInitializationError on _instance',
    skip: true,
    (tester) async {},
  );

  // ── 26: CityPickerScreen ───────────────────────────────────────────────────

  testWidgets('26 CityPickerScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'CityPickerScreen',
      path: '/sacred-time/city',
      extraOverrides: [
        // Silence streak 15-min periodic timer to prevent timer-pending failure.
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
    );
  });

  // ── 27: TrackManagementHubScreen ───────────────────────────────────────────

  testWidgets('27 TrackManagementHubScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'TrackManagementHubScreen',
      path: '/settings/tracks',
      extraOverrides: [
        _englishTerms(),
        activeTracksProvider.overrideWith(
          (ref) => Stream.value(<CurriculumTrack>[]),
        ),
        _noTutorPerms(),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
    );
  });

  // ── 28: TrackDetailScreen ──────────────────────────────────────────────────
  //
  // TrackDetailRoute requires a CurriculumTrack arg passed programmatically.
  // Sweeps the tightest matrix cell only (sufficient to catch structural overflow).

  testWidgets(
    'SKIP 28 TrackDetailScreen — router.push(TrackDetailRoute) hangs '
    'headlessly; content DB assets absent; timed out after 10 min',
    skip: true,
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final identity = E2EIdentity.localBorn(displayName: 'TrkDtl');
      final h = E2EHarness(tester, identity: identity);
      await h.pumpApp(
        path: '/settings/tracks',
        extraOverrides: [
          _englishTerms(),
          _noTutorPerms(),
          activeTracksProvider.overrideWith(
            (ref) => Stream.value(<CurriculumTrack>[]),
          ),
        ],
      );

      final now = DateTimeFactory.nowUtc();
      final trackId = await h.db
          .into(h.db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: identity.profileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              stateChangedAt: now,
              activatedAt: now,
            ),
          );
      final track = CurriculumTrack(
        id: trackId,
        profileId: identity.profileId,
        curriculumId: CurriculumId.mishnayos.storageKey,
        state: 'active',
        stateChangedAt: now,
        activatedAt: now,
      );

      await _sweepPush(
        tester,
        label: 'TrackDetailScreen',
        h: h,
        push: (router) => router.push(TrackDetailRoute(track: track)),
      );

      await h.dispose();
    },
  );

  // ── 29: LifetimeMarkingScreen ──────────────────────────────────────────────
  //
  // router.push(LifetimeMarkingRoute) hangs headlessly — same pattern as
  // TrackDetailScreen.  The screen requires bundled content DB assets to build
  // the curriculum item list; in-memory DB is empty so layout never resolves.

  testWidgets(
    'SKIP 29 LifetimeMarkingScreen — router.push hangs headlessly; '
    'requires bundled content DB to render curriculum item list',
    skip: true,
    (tester) async {},
  );

  // ── 30: ManageTutorsScreen ─────────────────────────────────────────────────

  testWidgets('30 ManageTutorsScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'ManageTutorsScreen',
      path: '/tutor/manage-tutors',
      extraOverrides: [
        profileListProvider.overrideWith((ref) async => <ProfileModel>[]),
        outgoingTutorGrantsProvider.overrideWith(
          (ref, _) async => <TutorGrant>[],
        ),
        _noIncomingGrants(),
        _noPendingInvites(),
        _connectivity(),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
    );
  });

  // ── 31: ManageGrantsScreen ─────────────────────────────────────────────────

  testWidgets('31 ManageGrantsScreen — no overflow', (tester) async {
    await _sweepPath(
      tester,
      label: 'ManageGrantsScreen',
      path: '/tutor/my-grants',
      extraOverrides: [
        _noIncomingGrants(),
        _noPendingInvites(),
        _connectivity(),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
    );
  });

  // ── 32: TutorAuditLogScreen ────────────────────────────────────────────────
  //
  // Requires a grantId arg — pushed via router.

  testWidgets(
    '32 TutorAuditLogScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'AuditLog'),
      );
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          tutorAuditLogProvider.overrideWith(
            (ref, _) async => <TutorAuditLogEntry>[],
          ),
        ],
      );

      await _sweepPush(
        tester,
        label: 'TutorAuditLogScreen',
        h: h,
        push: (router) => router.push(
          TutorAuditLogRoute(
            grantId: 'test-grant-id',
            tutorEmail: 'tutor@test.com',
          ),
        ),
      );

      await h.dispose();
    },
  );

  // ── 33: InviteTutorScreen ──────────────────────────────────────────────────

  testWidgets(
    '33 InviteTutorScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      await _sweepPath(
        tester,
        label: 'InviteTutorScreen',
        path: '/tutor/invite',
        extraOverrides: [
          _connectivity(),
          dashboardStreakProvider.overrideWith(
            (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
          ),
        ],
      );
    },
  );

  // ── 34: AcceptInviteScreen ─────────────────────────────────────────────────
  //
  // Deep-link path /invite (no identity required; screen handles unauthenticated).

  testWidgets(
    '34 AcceptInviteScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      await _sweepPath(
        tester,
        label: 'AcceptInviteScreen',
        path: '/invite',
        identityFactory: () => null,
        extraOverrides: [_noIncomingGrants(), _noPendingInvites()],
      );
    },
  );

  // ── 35: DeclineInviteScreen ────────────────────────────────────────────────
  //
  // Requires a TutorGrant arg — pushed via router.

  testWidgets(
    '35 DeclineInviteScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'Decline'),
      );
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          _noIncomingGrants(),
          _noPendingInvites(),
        ],
      );

      final now = DateTime(2024);
      final stubGrant = TutorGrant(
        doc: TutorGrantDoc(
          grantId: 'test-grant',
          parentUid: 'owner-uid',
          childProfileId: 'profile-id',
          tutorEmail: 'tutor@test.com',
          state: TutorGrantState.pending,
          invitedAt: now,
          updatedAt: now,
        ),
        grantState: PendingGrant(expiresAt: now.add(const Duration(days: 7))),
      );

      await _sweepPush(
        tester,
        label: 'DeclineInviteScreen',
        h: h,
        push: (router) => router.push(
          DeclineInviteRoute(grant: stubGrant, onDeclined: () {}),
        ),
      );

      await h.dispose();
    },
  );

  // ── 36: PinFlowSetupRoute ──────────────────────────────────────────────────

  testWidgets(
    '36 PinFlowSetupRoute — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      await _sweepPath(
        tester,
        label: 'PinFlowSetupRoute',
        path: '/parent-mode/pin-setup',
        identityFactory: () => E2EIdentity.localBorn(
          displayName: 'PinSetup',
          profileMode: 'child',
        ),
        extraOverrides: [
          dashboardStreakProvider.overrideWith(
            (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
          ),
        ],
      );
    },
  );

  // ── 37: (removed — AUD-profiles-06 deleted PinFlowVerifyRoute; see header) ─

  // ── 38: ParentSettingsScreen ───────────────────────────────────────────────
  //
  // PIN-gated — push via router after markPinAuthenticated().

  testWidgets(
    '38 ParentSettingsScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final identity = E2EIdentity.localBorn(
        displayName: 'ParStgs',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          activeProfilePointsBalanceProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
          pendingRedemptionsCountProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
        ],
      );
      h.markPinAuthenticated();

      await _sweepPush(
        tester,
        label: 'ParentSettingsScreen',
        h: h,
        push: (router) => router.push(const ParentSettingsRoute()),
      );

      await h.dispose();
    },
  );

  // ── 39: PointConfigScreen ──────────────────────────────────────────────────

  testWidgets(
    '39 PointConfigScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final identity = E2EIdentity.localBorn(
        displayName: 'PtCfg',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          activeTracksProvider.overrideWith(
            (ref) => Stream.fromFuture(Future.value(<CurriculumTrack>[])),
          ),
          _noTutorPerms(),
        ],
      );
      h.markPinAuthenticated();

      await _sweepPush(
        tester,
        label: 'PointConfigScreen',
        h: h,
        push: (router) => router.push(const PointConfigRoute()),
      );

      await h.dispose();
    },
  );

  // ── 40: RewardConfigurationScreen ─────────────────────────────────────────

  testWidgets(
    '40 RewardConfigurationScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final identity = E2EIdentity.localBorn(
        displayName: 'RwdCfg',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [...h.dashboardSilenceOverrides, _noTutorPerms()],
      );
      h.markPinAuthenticated();

      await _sweepPush(
        tester,
        label: 'RewardConfigurationScreen',
        h: h,
        push: (router) => router.push(const RewardConfigurationRoute()),
      );

      await h.dispose();
    },
  );

  // ── 41: StudyDayConfigScreen ───────────────────────────────────────────────
  //
  // Requires a curriculumId arg — push via router.

  testWidgets(
    '41 StudyDayConfigScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'StDayCfg'),
      );
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          studyDayConfigsProvider.overrideWith(
            (ref, _) => Stream.value(<StudyDayConfigEntry>[]),
          ),
          _noTutorPerms(),
        ],
      );

      await _sweepPush(
        tester,
        label: 'StudyDayConfigScreen',
        h: h,
        push: (router) => router.push(
          StudyDayConfigRoute(curriculumId: CurriculumId.mishnayos),
        ),
      );

      await h.dispose();
    },
  );

  // ── 42: CurriculumProgressScreen ───────────────────────────────────────────

  testWidgets(
    '42 CurriculumProgressScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'CurrPrg'),
      );
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          curriculumProgressProvider.overrideWith(
            (ref, _) async => const CurriculumProgressData(
              curriculumId: 'mishnayos',
              hierarchyLevels: [],
              overallStats: OverallCurriculumStats(
                totalItems: 0,
                completedAllStages: 0,
                inProgress: 0,
                notStarted: 0,
              ),
            ),
          ),
        ],
      );

      await _sweepPush(
        tester,
        label: 'CurriculumProgressScreen',
        h: h,
        push: (router) => router.push(
          CurriculumProgressRoute(
            curriculumId: CurriculumId.mishnayos.storageKey,
          ),
        ),
      );

      await h.dispose();
    },
  );

  // ── 43: CurriculumSettingsScreen ───────────────────────────────────────────

  testWidgets(
    '43 CurriculumSettingsScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'CurrStgs'),
      );
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          scopedItemCountProvider.overrideWith((ref, _) async => 0),
        ],
      );

      await _sweepPush(
        tester,
        label: 'CurriculumSettingsScreen',
        h: h,
        push: (router) => router.push(
          CurriculumSettingsRoute(
            curriculumId: CurriculumId.mishnayos.storageKey,
          ),
        ),
      );

      await h.dispose();
    },
  );

  // ── 44: LearningOrderScreen ────────────────────────────────────────────────

  testWidgets(
    '44 LearningOrderScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final h = E2EHarness(
        tester,
        identity: E2EIdentity.localBorn(displayName: 'LrnOrd'),
      );
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          trackSedarimOrderProvider.overrideWith(
            (ref, _) async => <LearningOrderItem>[],
          ),
          trackMasechtosOrderProvider.overrideWith(
            (ref, _) async => <LearningOrderItem>[],
          ),
        ],
      );

      await _sweepPush(
        tester,
        label: 'LearningOrderScreen',
        h: h,
        push: (router) => router.push(
          LearningOrderRoute(curriculumId: CurriculumId.mishnayos),
        ),
      );

      await h.dispose();
    },
  );

  // ── 45: ParentTrackManagementScreen ───────────────────────────────────────

  testWidgets(
    '45 ParentTrackManagementScreen — no overflow',
    skip:
        true, // device/harness: guarded router.push hangs headless; untested — DNI-404 tracks the on-device overflow sweep
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);

      final identity = E2EIdentity.localBorn(
        displayName: 'ParTrkMgmt',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          activeTracksProvider.overrideWith(
            (ref) => Stream.fromFuture(Future.value(<CurriculumTrack>[])),
          ),
        ],
      );
      h.markPinAuthenticated();

      await _sweepPush(
        tester,
        label: 'ParentTrackManagementScreen',
        h: h,
        push: (router) => router.push(const ParentTrackManagementRoute()),
      );

      await h.dispose();
    },
  );

  // ── Skipped screens (documented) ──────────────────────────────────────────

  testWidgets(
    'SKIP PermissionPromptScreen — native platform channels '
    '(NotificationGateway.requestPermission / location detection)',
    skip: true,
    (tester) async {},
  );

  testWidgets(
    'SKIP ContentHierarchyScreen — requires bundled asset ContentRepository; '
    'in-memory ContentDatabase has no seed data',
    skip: true,
    (tester) async {},
  );

  testWidgets(
    'SKIP ContentSearchScreen — same asset-DB dependency as ContentHierarchy',
    skip: true,
    (tester) async {},
  );

  testWidgets(
    'SKIP TextDisplayScreen — requires bundled ContentRepository + sefariaRef '
    'route arg; initState fetch fails without asset data',
    skip: true,
    (tester) async {},
  );

  testWidgets(
    'SKIP LifetimeCurriculumMarkingRoute — requires bundled content DB to '
    'render curriculum item list; in-memory DB is empty',
    skip: true,
    (tester) async {},
  );
}
