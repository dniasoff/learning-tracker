@Tags(['overflow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show effectiveUseHebrewTermsProvider;
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart'
    show syncStatusProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart'
    show
        anyActiveTrackHasChazaraProvider,
        dashboardActiveCurriculaStreamProvider,
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
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart'
    show streakCalendarProvider;
import 'package:learning_tracker/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart'
    show pendingRedemptionsProvider;
import 'package:learning_tracker/features/profiles/presentation/screens/parent_settings_screen.dart'
    show activeProfilePointsBalanceProvider, pendingRedemptionsCountProvider;
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart'
    show CurriculumJourney, JourneyViewModel;
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart'
    show LifetimeTotals, TrackDualProgressMetric;
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
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart'
    show currentSacredWindowProvider;
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart'
    show DailyTask;
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart'
    show allDailyTasksProvider, coarsePacedTrackIdsProvider;
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart'
    show SyncStatus;
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart'
    show activeTracksProvider;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart'
    show TutorGrant;
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart'
    show activeTutorPermissionsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import '../harness/e2e_harness.dart';

void main() {
  setUpAll(e2eSetUpAll);

  testWidgets('13 LearningScreen en debug', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);

    final h = E2EHarness(
      tester,
      identity: E2EIdentity.localBorn(displayName: 'LearnEn'),
    );
    await h.pumpApp(
      path: '/learn',
      extraOverrides: [
        effectiveUseHebrewTermsProvider.overrideWithValue(false),
        dashboardActiveCurriculaStreamProvider.overrideWith(
          (ref) => Stream.value(<CurriculumId>[]),
        ),
        allDailyTasksProvider.overrideWith((ref) async => <DailyTask>[]),
        coarsePacedTrackIdsProvider.overrideWith((ref) async => <int>{}),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
        activeTutorPermissionsProvider.overrideWith((ref) => null),
        incomingTutorGrantsProvider.overrideWith((ref) async => <TutorGrant>[]),
      ],
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await h.dispose();
  });

  testWidgets('15 ProgressScreen debug', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);

    final h = E2EHarness(
      tester,
      identity: E2EIdentity.localBorn(displayName: 'PrgEn'),
    );
    await h.pumpApp(
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
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await h.dispose();
  });

  testWidgets('16 SettingsScreen debug', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(280, 653);

    final h = E2EHarness(
      tester,
      identity: E2EIdentity.localBorn(displayName: 'StgsEn'),
    );
    await h.pumpApp(
      path: '/settings',
      extraOverrides: [
        currentSacredWindowProvider.overrideWithValue(null),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
        incomingTutorGrantsProvider.overrideWith((ref) async => <TutorGrant>[]),
        pendingTutorInvitesProvider.overrideWith((ref) async => <TutorGrant>[]),
        syncStatusProvider.overrideWith((ref) => const SyncStatus.localOnly()),
        effectiveUseHebrewTermsProvider.overrideWithValue(false),
        activeTutorPermissionsProvider.overrideWith((ref) => null),
        lifetimeSummariesProvider.overrideWith((ref, _) async => []),
      ],
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await h.dispose();
  });

  testWidgets('19 RecentActivityScreen debug 280', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(280, 653);

    final h = E2EHarness(
      tester,
      identity: E2EIdentity.localBorn(displayName: 'RecAct'),
    );
    await h.pumpApp(
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
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await h.dispose();
  });

  testWidgets('20 LifetimeKnowledgeScreen debug', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);

    final h = E2EHarness(
      tester,
      identity: E2EIdentity.localBorn(displayName: 'LKSEn'),
    );
    await h.pumpApp(
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
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await h.dispose();
  });

  testWidgets('21 CurriculumListScreen debug', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);

    final h = E2EHarness(
      tester,
      identity: E2EIdentity.localBorn(displayName: 'CurrList'),
    );
    await h.pumpApp(path: '/browse', locale: const Locale('en'));
    await tester.pump(const Duration(milliseconds: 300));
    await h.dispose();
  });

  testWidgets('22 GamificationScreen debug', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);

    final h = E2EHarness(
      tester,
      identity: E2EIdentity.localBorn(
        displayName: 'GamChild',
        profileMode: 'child',
      ),
    );
    await h.pumpApp(
      path: '/gamification',
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
        incomingTutorGrantsProvider.overrideWith((ref) async => <TutorGrant>[]),
      ],
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await h.dispose();
  });

  testWidgets('24 ParentPendingRedemptionsScreen debug', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(280, 653);

    final h = E2EHarness(
      tester,
      identity: E2EIdentity.localBorn(
        displayName: 'PndParent',
        profileMode: 'child',
      ),
    );
    await h.pumpApp(
      path: '/parent-mode/pending-redemptions',
      extraOverrides: [
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
      ],
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await h.dispose();
  });
}
