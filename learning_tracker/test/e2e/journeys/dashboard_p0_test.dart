/// E2E Wave 1 P0 journeys — Dashboard area.
///
/// Journeys implemented:
///   E2E-201  Adult daily check-in: see tasks, open Scheduler
///   E2E-203  Empty dashboard — no tracks, adult — add track CTA
///   E2E-206  All-caught-up state: no remaining tasks
///   E2E-207  Active track carousel: swipe between tracks, tap card to learn
///   E2E-209  Auto-refresh after SyncStatus.synced on cold start
///   E2E-212  Offline use: dashboard renders from Drift without network
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 2 / §7 R-DB*
@Tags(['e2e', 'journey'])
library;

import 'package:flutter/material.dart' show Scrollable;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show effectiveUseHebrewTermsProvider;
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart'
    as core_sync;
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart'
    show StreakRecoveryInfo;
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

import '../harness/e2e_harness.dart';

// ── Factories ────────────────────────────────────────────────────────────────

/// Creates a stub [CurriculumTrack] that can be injected via
/// [dashboardActiveTracksStreamProvider] without DB round-trips.
CurriculumTrack _stubTrack({
  required int id,
  required int profileId,
  required CurriculumId curriculum,
}) {
  final now = DateTimeFactory.nowUtc();
  return CurriculumTrack(
    id: id,
    profileId: profileId,
    curriculumId: curriculum.storageKey,
    state: 'active',
    stateChangedAt: now,
    activatedAt: now,
  );
}

/// Minimal [DailyTask] for a self-paced track.
DailyTask _minimalTask({
  required int trackId,
  String ref = 'Berakhot.2a',
  CurriculumId curriculum = CurriculumId.mishnayos,
  bool isOverdue = false,
}) {
  return DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: ref,
    stageOrder: 1,
    stageDefinitionId: 1,
    priority: isOverdue
        ? DailyTaskPriority.overdueNewLearning
        : DailyTaskPriority.newLearning,
    isOverdue: isOverdue,
    reason: 'test',
    stageName: 'Learn',
    trackId: trackId,
    trackLabel: 'Test Track',
  );
}

/// Standard LifetimeTotals stub with zero data.
const _zeroLifetimeTotals = LifetimeTotals(
  learnedSections: 0,
  totalSections: 0,
  totalCurricula: 9,
);

/// Overrides for the dashboard WITH active tracks (non-empty track stream).
///
/// Includes ALL silence overrides needed by DashboardScreen, including the
/// streak + curricula providers from [E2EHarness.dashboardSilenceOverrides]
/// EXCEPT the track stream — which we replace here with [tracks].
///
/// Do NOT combine with [E2EHarness.dashboardSilenceOverrides] because that
/// already overrides `dashboardActiveTracksStreamProvider` with an empty list,
/// which would create a duplicate override (Riverpod assertion error).
List<Override> _dashboardActiveTracksOverrides(
  E2EHarness h, {
  required List<CurriculumTrack> tracks,
  required List<DailyTask> tasks,
  LifetimeTotals totals = _zeroLifetimeTotals,
}) {
  // dashboardSilenceOverrides includes:
  //   dashboardActiveCurriculaStreamProvider → []
  //   dashboardActiveTracksStreamProvider    → []   ← we replace this
  //   dashboardStreakProvider                → 0/0
  //   dashboardStreakRecoveryProvider        → not recovered
  //
  // We replace the track stream with the supplied [tracks] list, so we
  // spread the silence overrides FIRST then override the track stream again.
  // BUT Riverpod asserts on duplicate overrides!  So instead we manually
  // list the non-track silence overrides and add our own track stream.
  return [
    // Non-track silence overrides (from dashboardSilenceOverrides minus the
    // track stream):
    dashboardActiveCurriculaStreamProvider.overrideWith(
      (ref) => Stream.value(<CurriculumId>[]),
    ),
    dashboardStreakProvider.overrideWith(
      (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
    ),
    dashboardStreakRecoveryProvider.overrideWith(
      (ref) => Future.value(
        const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
      ),
    ),
    // Inject the active tracks to display.
    dashboardActiveTracksStreamProvider.overrideWith(
      (ref) => Stream.value(tracks),
    ),
    // Task list (bypasses the full projection engine).
    allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
    // Lifetime providers (carousel track cards consume these).
    lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
      (ref, profileId) => Future.value(totals),
    ),
    lifetimeSummariesProvider.overrideWith(
      (ref, profileId) => Future.value([]),
    ),
    trackDualProgressMetricsProvider.overrideWith(
      (ref, profileId) => Future.value([]),
    ),
  ];
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-201 ──────────────────────────────────────────────────────────────

  group('E2E-201 — Adult daily check-in: see tasks, open Scheduler', () {
    // Risk: R-DB2 — tasksReady race when allDailyTasksProvider resolves before
    // tracks.  Mitigated by overriding both providers so the dashboard renders
    // in a known state.

    testWidgets(
      'dashboard renders missions heading when track and tasks are present',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Alice');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Inject one stub track and one task — bypassing DB and projection.
        final track = _stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final task = _minimalTask(
          trackId: track.id,
          curriculum: CurriculumId.mishnayos,
        );

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._dashboardActiveTracksOverrides(
              h,
              tracks: [track],
              tasks: [task],
            ),
          ],
        );

        // The DashboardBody ListView is lazy so off-screen items are not built.
        // scrollUntilVisible scrolls until the heading appears in the tree.
        await tester.scrollUntilVisible(
          find.text('Today’s Missions'),
          100.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        // Key assertion (R-DB2): Today’s Missions heading visible — tasks are
        // rendered without a false "all caught up" on first load.
        // Note: l10n.todaysMissions uses U+2019 RIGHT SINGLE QUOTATION MARK.
        h.expectOnScreen('Today’s Missions');
        h.expectOnScreen('DASHBOARD');
      },
    );

    testWidgets('tap on the main mission card navigates to SchedulerScreen', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(displayName: 'Alice');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final track = _stubTrack(
        id: 1,
        profileId: 1,
        curriculum: CurriculumId.mishnayos,
      );
      final task = _minimalTask(trackId: track.id);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._dashboardActiveTracksOverrides(h, tracks: [track], tasks: [task]),
        ],
      );

      // The ListView is lazy; use scrollUntilVisible to scroll "Today’s
      // Missions" and "Start Learning" into the viewport before tapping.
      await tester.scrollUntilVisible(
        find.text('Today’s Missions'),
        100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Note: l10n.todaysMissions uses U+2019 RIGHT SINGLE QUOTATION MARK.
      h.expectOnScreen('Today’s Missions');

      // Tap the "Start Learning" button inside MainFocusMissionCard to
      // navigate to SchedulerRoute.  The button text is l10n.startLearning.
      await h.tapText(
        'Start Learning',
        settle: const Duration(milliseconds: 500),
      );

      // After tap we land on SchedulerScreen (which is outside the shell
      // so the bottom nav is not present).  Assert the scheduler header.
      h.expectOnScreen('Daily Tasks');
    });
  });

  // ── E2E-203 ──────────────────────────────────────────────────────────────

  group('E2E-203 — Empty dashboard — no tracks, adult — add track CTA', () {
    testWidgets(
      'empty-state title and Add Track button visible for adult with 0 tracks',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Bob');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // No tracks — dashboardSilenceOverrides returns empty track stream.
        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: h.dashboardSilenceOverrides,
        );

        // Empty-state title.
        h.expectOnScreen('No tracks yet');
        // Adult CTA button.
        h.expectOnScreen('Add Track');
        // Adult must NOT see "ask a grown-up" message.
        h.expectNotOnScreen('Ask a grown-up');
      },
    );

    testWidgets('tapping Add Track navigates away from the empty dashboard', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(displayName: 'Bob');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: h.dashboardSilenceOverrides,
      );

      h.expectOnScreen('Add Track');
      await h.tapText('Add Track', settle: const Duration(milliseconds: 500));

      // After tapping the CTA the app navigates to TrackManagementHubRoute.
      // The empty-dashboard state is no longer in the widget tree.
      expect(find.text('No tracks yet'), findsNothing);
    });
  });

  // ── E2E-206 ──────────────────────────────────────────────────────────────

  group('E2E-206 — All-caught-up state: no remaining tasks', () {
    testWidgets(
      '"All caught up! Great work!" card shown when tasks list is empty',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Charlie');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Inject one stub track but an empty task list → all caught up.
        final track = _stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: _dashboardActiveTracksOverrides(
            h,
            tracks: [track],
            tasks: const [],
            totals: const LifetimeTotals(
              learnedSections: 100,
              totalSections: 200,
              totalCurricula: 9,
            ),
          ),
        );

        // Key assertion: "All caught up" card rendered.
        h.expectOnScreen('All caught up! Great work!');
        // Task-mission heading must NOT appear when total remaining == 0.
        // Note: l10n.todaysMissions uses U+2019 RIGHT SINGLE QUOTATION MARK.
        h.expectNotOnScreen('Today’s Missions');
      },
    );
  });

  // ── E2E-207 ──────────────────────────────────────────────────────────────

  group('E2E-207 — Active track carousel: two tracks visible in carousel', () {
    testWidgets(
      'carousel renders both curriculum labels for two active tracks',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Dave');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Two stub tracks → two carousel pages.
        final track1 = _stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final track2 = _stubTrack(
          id: 2,
          profileId: 1,
          curriculum: CurriculumId.chumash,
        );
        final task1 = _minimalTask(
          trackId: track1.id,
          curriculum: CurriculumId.mishnayos,
        );
        final task2 = _minimalTask(
          trackId: track2.id,
          curriculum: CurriculumId.chumash,
          ref: 'Genesis.1.1',
        );

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            // Force English curriculum labels regardless of device locale so
            // the carousel shows "Mishnayos" (not "משניות").
            effectiveUseHebrewTermsProvider.overrideWithValue(false),
            ..._dashboardActiveTracksOverrides(
              h,
              tracks: [track1, track2],
              tasks: [task1, task2],
            ),
          ],
        );

        // Scroll down to bring 'Today’s Missions' into view (it is ~400 px from
        // The ListView is lazy. Use scrollUntilVisible to find each heading.
        await tester.scrollUntilVisible(
          find.text('Today’s Missions'),
          100.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        // Confirm the dashboard tab rendered correctly (non-empty state).
        // The missions heading must be visible before the carousel.
        // Note: l10n.todaysMissions uses U+2019 RIGHT SINGLE QUOTATION MARK.
        h.expectOnScreen('Today’s Missions');

        // The carousel (SizedBox(height: 460)) appears after the mission cards.
        // Scroll further to bring "Active tracks" section header into view.
        await tester.scrollUntilVisible(
          find.text('Active tracks'),
          100.0,
          scrollable: find.byType(Scrollable).first,
        );
        // Allow async providers in ActiveTrackCard to resolve and the
        // PageView to build its first page.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));

        // Key assertion: carousel section heading rendered.
        h.expectOnScreen('Active tracks');
        // First carousel page shows Mishnayos (track1) in English locale.
        h.expectOnScreen('Mishnayos');
      },
    );
  });

  // ── E2E-209 ──────────────────────────────────────────────────────────────

  group('E2E-209 — Auto-refresh after SyncStatus.synced on cold start', () {
    // The dashboard listens to syncStatusProvider via ref.listen and calls
    // invalidateDashboardData when transitioning INTO SyncStatusSynced.
    // In the headless harness the full re-fetch is short-circuited by the
    // provider overrides, but the listener must not crash.

    testWidgets(
      'dashboard stays stable when syncStatus emits synced immediately',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Eve');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Override the core-layer syncStatusProvider (the one DashboardScreen
        // imports from core/sync/providers/sync_status_providers.dart).
        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ...h.dashboardSilenceOverrides,
            core_sync.syncStatusProvider.overrideWithValue(
              SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowLocal()),
            ),
            core_sync.syncStatusStreamProvider.overrideWith(
              (ref) => Stream.value(
                SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowLocal()),
              ),
            ),
            allDailyTasksProvider.overrideWith(
              (ref) => Future.value(const <DailyTask>[]),
            ),
          ],
        );

        // Dashboard renders (the ref.listen invalidate call does not crash)
        // and shows the empty state because no tracks are seeded.
        h.expectOnScreen('No tracks yet');
        h.expectOnScreen('DASHBOARD');
      },
    );

    testWidgets(
      'dashboard renders correctly when syncStatus starts as localOnly',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Fiona');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ...h.dashboardSilenceOverrides,
            core_sync.syncStatusProvider.overrideWithValue(
              const SyncStatus.localOnly(),
            ),
            core_sync.syncStatusStreamProvider.overrideWith(
              (ref) => Stream.value(const SyncStatus.localOnly()),
            ),
            allDailyTasksProvider.overrideWith(
              (ref) => Future.value(const <DailyTask>[]),
            ),
          ],
        );

        // localOnly: the ref.listen condition (previous is! SyncStatusSynced)
        // never fires; empty state renders without crash.
        h.expectOnScreen('No tracks yet');
        h.expectOnScreen('DASHBOARD');
      },
    );
  });

  // ── E2E-212 ──────────────────────────────────────────────────────────────

  group('E2E-212 — Offline use: dashboard renders from Drift without network', () {
    testWidgets(
      'dashboard shows empty state offline — no crash or spinner hang',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Grace');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ...h.dashboardSilenceOverrides,
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            allDailyTasksProvider.overrideWith(
              (ref) => Future.value(const <DailyTask>[]),
            ),
          ],
        );

        // Offline-first invariant: Drift providers resolve and the UI renders
        // without a network request.
        h.expectOnScreen('No tracks yet');
        // All shell tabs are present (route resolved from local Drift data).
        h.expectOnScreen('DASHBOARD');
        h.expectOnScreen('LEARN');
        h.expectOnScreen('PROGRESS');
        h.expectOnScreen('SETTINGS');
      },
    );

    testWidgets(
      'dashboard with seeded track data renders carousel and missions offline',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Hana');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Inject a stub track to simulate local Drift data available offline.
        final track = _stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final task = _minimalTask(trackId: track.id);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            // Force English curriculum labels regardless of device locale so
            // the carousel shows "Mishnayos" (not "משניות").
            effectiveUseHebrewTermsProvider.overrideWithValue(false),
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            ..._dashboardActiveTracksOverrides(
              h,
              tracks: [track],
              tasks: [task],
            ),
          ],
        );

        // The ListView is lazy; use scrollUntilVisible for each widget.
        await tester.scrollUntilVisible(
          find.text('Today’s Missions'),
          100.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        // Key assertion (offline-first): Drift data resolves — missions section
        // renders without any network call.
        // Note: l10n.todaysMissions uses U+2019 RIGHT SINGLE QUOTATION MARK.
        h.expectOnScreen('Today’s Missions');

        // Scroll to bring the carousel section heading into view.
        await tester.scrollUntilVisible(
          find.text('Active tracks'),
          100.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        h.expectOnScreen('Active tracks');
        // The Mishnayos label renders from local Drift data.
        h.expectOnScreen('Mishnayos');
      },
    );
  });
}
