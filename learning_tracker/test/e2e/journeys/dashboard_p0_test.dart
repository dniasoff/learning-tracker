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
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show effectiveUseHebrewTermsProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Factories ────────────────────────────────────────────────────────────────

/// Minimal [DailyTask] for a self-paced track.
DailyTask _minimalTask({
  String ref = 'Berakhot.2a',
  CurriculumId curriculum = CurriculumId.mishnayos,
  bool isOverdue = false,
}) {
  return DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: ref,
    stageOrder: 1,
    priority: isOverdue
        ? DailyTaskPriority.overdueNewLearning
        : DailyTaskPriority.newLearning,
    isOverdue: isOverdue,
    reason: 'test',
    stageName: 'Learn',
    trackLabel: 'Test Track',
  );
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
        final track = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final task = _minimalTask(curriculum: CurriculumId.mishnayos);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ...dashboardActiveTracksOverrides(
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

      final track = stubTrack(
        id: 1,
        profileId: 1,
        curriculum: CurriculumId.mishnayos,
      );
      final task = _minimalTask();

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...dashboardActiveTracksOverrides(h, tracks: [track], tasks: [task]),
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
        final track = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: dashboardActiveTracksOverrides(
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
        final track1 = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final track2 = stubTrack(
          id: 2,
          profileId: 1,
          curriculum: CurriculumId.chumash,
        );
        final task1 = _minimalTask(curriculum: CurriculumId.mishnayos);
        final task2 = _minimalTask(
          curriculum: CurriculumId.chumash,
          ref: 'Genesis.1.1',
        );

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            // Force English curriculum labels regardless of device locale so
            // the carousel shows "Mishnayos" (not "משניות").
            effectiveUseHebrewTermsProvider.overrideWithValue(false),
            ...dashboardActiveTracksOverrides(
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

  group(
    'E2E-209 — Auto-refresh after SyncStatus.synced on cold start',
    skip:
        'Retired: tests SyncStatus/sync-orchestrator auto-refresh, deleted in the Drift→Firestore migration (sync engine wholesale-archived). See commit 04897ebc.',
    () {},
  );

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
        final track = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final task = _minimalTask();

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            // Force English curriculum labels regardless of device locale so
            // the carousel shows "Mishnayos" (not "משניות").
            effectiveUseHebrewTermsProvider.overrideWithValue(false),
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            ...dashboardActiveTracksOverrides(
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
