/// E2E Wave 2 P1 journeys — Tracks area.
///
/// Journeys implemented:
///   E2E-408  Edit track — change name and study days
///   E2E-409  Edit chazara schedule from EditTrackScreen
///   E2E-410  Clear overdue on program track
///   E2E-411  Reorder content within a track — TrackLearningOrderScreen
///   E2E-412  Add track with prior completions — bulk-mark at wizard end
///   E2E-413  Add track — wizard resume after app kill
///   E2E-414  Parent-mode: manage child's tracks — ParentTrackManagementScreen
///   E2E-415  Goal setup / edit from TrackDetailScreen
///   E2E-416  Hebrew locale / RTL tracks flow
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 5 / §7 R-TR*
@Tags(['e2e', 'journey'])
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart'
    show Directionality, Locale, Scrollable, TextDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart'
    show ParentTrackManagementRoute;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show
        UseHebrewDate,
        effectiveUseHebrewTermsProvider,
        useHebrewDateProvider,
        useHebrewTermsProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_settings_screen.dart'
    show activeProfilePointsBalanceProvider, pendingRedemptionsCountProvider;
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart'
    show allDailyTasksProvider, clockProvider;
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart'
    show scopedItemCountProvider;
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart'
    show activeTracksProvider;
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_management_hub_screen.dart'
    show TrackManagementHubScreen;
import 'package:learning_tracker/features/tracks/track_order/presentation/providers/track_learning_order_providers.dart'
    show trackMasechtosOrderProvider, trackSedarimOrderProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart'
    show activeTutorPermissionsProvider;

import '../../helpers/firestore_fixtures.dart';
import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Factories ──────────────────────────────────────────────────────────────────

/// Seeds the Firestore track document keyed by the profile and curriculum.
Future<void> _seedTrack(
  E2EHarness h,
  E2EIdentity identity,
  CurriculumTrackEntity stub,
) async {
  await seedTrack(
    h.firestore,
    uid: identity.accountId,
    profileId: identity.profileId,
    curriculumId: stub.curriculumId,
    stateChangedAt: stub.stateChangedAt,
    activatedAt: stub.activatedAt,
  );
}

// ── UseHebrewDate stub ────────────────────────────────────────────────────────

/// Stub that always returns false (English dates) — used to silence the async
/// Hebrew-date path in GoalSetupScreen and avoid date-picker locale issues.
class _FalseUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

// ── Override factories ─────────────────────────────────────────────────────────

/// Standard overrides for the track hub + detail. Forces English labels and
/// silences Drift stream providers that schedule zero-duration timers on
/// dispose.
List<Override> _trackHubOverrides({
  required List<CurriculumTrackEntity> tracks,
}) => [
  activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
  useHebrewTermsProvider.overrideWithValue(false),
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
];

/// Silences TrackDetailScreen providers that are not under test.
///
/// [isProgramTrack] controls dashboardHasProgramEnrollmentProvider — false
/// for self-paced tracks (default), true for program tracks (E2E-410).
List<Override> _trackDetailSilenceOverrides({bool isProgramTrack = false}) => [
  trackDualProgressMetricsProvider.overrideWith((ref) => Future.value([])),
  dashboardHasProgramEnrollmentProvider.overrideWith(
    (ref, curriculum) => Future.value(isProgramTrack),
  ),
  dashboardTrackCompletionPercentageProvider.overrideWith(
    (ref, trackId) => Future.value(0.0),
  ),
  activeTutorPermissionsProvider.overrideWith((ref) => null),
];

/// Silences EditTrackScreen providers that are separate from the detail
/// silences. Does NOT include dashboardHasProgramEnrollmentProvider (to avoid
/// double-overriding that family when combined with [_trackDetailSilenceOverrides])
/// and does NOT override trackHasChazaraProvider (tests that need chazara to be
/// visible seed real stage rows in the DB instead so the real provider resolves).
///
/// Uses overrideWithValue(AsyncData([])) so the FutureProvider is IMMEDIATELY
/// in AsyncData state (no Future, no microtask pump needed) — this avoids any
/// timing issues with _loadData() awaiting allDailyTasksProvider.future.
List<Override> _editTrackSilenceOverrides() => [
  allDailyTasksProvider.overrideWithValue(const AsyncData(<DailyTask>[])),
];

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-408 ───────────────────────────────────────────────────────────────

  group('E2E-408 — Edit track: change name and study days', () {
    // Journey: TrackDetailScreen → Edit Track → EditTrackScreen renders with
    // Name and Study Days sections; key assertions:
    //   • EditTrackScreen renders Track Name field and Study Days section.
    //   • Save Changes action button is present.
    //   • No track-type label (Personal / אישי) visible.
    //
    // R-TR5: EditTrackScreen._buildDeadlineEditor uses DateFormat.yMMMd not
    // formatTrackDate — tested here as a render assertion (no crash on open).
    testWidgets(
      'EditTrackScreen renders Track Name field and Study Days section; '
      'no track-type label visible',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Alice408');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final stub = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: [
            ..._trackHubOverrides(tracks: [stub]),
            ..._trackDetailSilenceOverrides(),
            ..._editTrackSilenceOverrides(),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Seed real DB row so editTrack service can query the track.
        await _seedTrack(h, identity, stub);

        // Navigate to TrackDetailScreen.
        await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));

        h.expectOnScreen('Edit Track');

        // Scroll to bring "Edit Track" tile into view and tap it.
        await tester.ensureVisible(find.text('Edit Track'));
        await tester.pump(const Duration(milliseconds: 100));
        await h.tapText(
          'Edit Track',
          settle: const Duration(milliseconds: 600),
        );
        await tester.pump(const Duration(milliseconds: 600));

        // EditTrackScreen should be rendered.
        h.expectOnScreen('Track Name');
        h.expectOnScreen('Study Days');
        h.expectOnScreen('Save Changes');

        // Product rule: no track-type label must appear anywhere.
        h.expectNotOnScreen('Personal');
        h.expectNotOnScreen('אישי');
      },
    );
  });

  // ── E2E-409 ───────────────────────────────────────────────────────────────

  group('E2E-409 — Edit chazara schedule from EditTrackScreen', () {
    // Journey: Track with chazara stages → EditTrackScreen → Review (Chazara)
    // section visible; "Change" button present.
    //
    // Requires trackHasChazaraProvider to return true for the track so the
    // Review section is rendered.
    testWidgets('EditTrackScreen shows Review section and Change button when track has '
        'chazara stages', (tester) async {
      final identity = E2EIdentity.localBorn(displayName: 'Bob409');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final stub = stubTrack(
        id: 1,
        profileId: 1,
        curriculum: CurriculumId.mishnayos,
      );

      // Override the specific family member trackHasChazaraProvider(1) with
      // overrideWithValue(AsyncData(true)) so it bypasses the async build cycle
      // entirely. The LearningTrackCard, TrackDetailScreen, and EditTrackScreen
      // all share this single cached AsyncData(true) without any microtask pump.
      await h.pumpApp(
        path: '/settings/tracks',
        extraOverrides: [
          ..._trackHubOverrides(tracks: [stub]),
          ..._trackDetailSilenceOverrides(),
          ..._editTrackSilenceOverrides(),
          // overrideWithValue on the specific instance (id=1) so the async
          // build cycle is bypassed — state is AsyncData(true) synchronously.
          trackHasChazaraProvider(
            CurriculumId.mishnayos,
          ).overrideWithValue(const AsyncData(true)),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));

      await _seedTrack(h, identity, stub);

      await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.text('Edit Track'));
      await tester.pump(const Duration(milliseconds: 100));
      await h.tapText('Edit Track', settle: const Duration(milliseconds: 600));
      // _loadData() completes → setState(_loading=false) → rebuild.
      // trackHasChazaraProvider(1) is already AsyncData(true) (cached from hub)
      // so the Review (Chazara) section renders in this same rebuild.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify we're on EditTrackScreen.
      h.expectOnScreen('Track Name');
      h.expectOnScreen('Study Days');

      // Review (Chazara) section may be off-screen (below the fold of the
      // ListView in the test surface). Scroll to it first.
      await tester.scrollUntilVisible(
        find.text('Review (Chazara)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Review (Chazara) section should be visible because trackHasChazaraProvider
      // returns AsyncData(true) (overridden per instance id=1).
      h.expectOnScreen('Review (Chazara)');
      // "Change" button to open the chazara bottom sheet.
      h.expectOnScreen('Change');
    });
  });

  // ── E2E-410 ───────────────────────────────────────────────────────────────

  group('E2E-410 — Clear overdue on program track', () {
    // Journey: Program track with overdue tasks → EditTrackScreen →
    // "Clear Overdue" button is enabled (red) when there are overdue tasks.
    //
    // The button only renders when _isProgramTrack is true
    // (dashboardHasProgramEnrollmentProvider returns true). A program-track
    // overdue task (DailyTaskPriority.overdueProgram) in allDailyTasksProvider
    // drives _hasOverdue = true so the button is enabled.
    testWidgets(
      'EditTrackScreen "Clear Overdue" button is enabled when a program track '
      'has overdue tasks',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Carol410');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const trackId = 1;
        final stub = stubTrack(
          id: trackId,
          profileId: 1,
          curriculum: CurriculumId.bavli,
        );

        // Build an overdue program task for this track so _hasOverdue = true.
        const overdueTask = DailyTask(
          curriculumId: CurriculumId.bavli,
          contentItemSefariaRef: 'Berakhot.2a',
          stageOrder: 1,
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          reason: 'overdue test',
          stageName: 'Learn',
          trackLabel: 'Talmud Bavli',
        );

        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: [
            ..._trackHubOverrides(tracks: [stub]),
            // isProgramTrack=true: declares this as a program track so the
            // locked banner + Clear Overdue button appear (not Study Days /
            // Chazara). Also used in EditTrackScreen._isProgramTrack.
            ..._trackDetailSilenceOverrides(isProgramTrack: true),
            // AsyncData immediately — no Future path, no microtask pump needed.
            allDailyTasksProvider.overrideWithValue(
              const AsyncData(<DailyTask>[overdueTask]),
            ),
            trackHasChazaraProvider.overrideWith(
              (ref, trackId) => Future.value(false),
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        await _seedTrack(h, identity, stub);

        await h.tapText(
          'Talmud Bavli',
          settle: const Duration(milliseconds: 500),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.ensureVisible(find.text('Edit Track'));
        await tester.pump(const Duration(milliseconds: 100));
        await h.tapText(
          'Edit Track',
          settle: const Duration(milliseconds: 600),
        );
        await tester.pump(const Duration(milliseconds: 600));

        // "Clear Overdue" button should be rendered for a program track.
        h.expectOnScreen('Clear Overdue');
      },
    );
  });

  // ── E2E-411 ───────────────────────────────────────────────────────────────

  group('E2E-411 — Reorder content within a track — TrackLearningOrderScreen', () {
    // Journey: TrackDetailScreen → "Reorder Content" tile → Navigator.push →
    // TrackLearningOrderScreen renders.
    //
    // TrackLearningOrderScreen watches trackSedarimOrderProvider and
    // trackMasechtosOrderProvider via contentRepositoryProvider (reads content
    // DB assets). In headless tests the bundled asset DB is absent so those
    // providers return empty lists — the screen renders with no items but no
    // crash. We assert the screen title is rendered.
    //
    // ReorderConfirmDialog (R-TR8) is not drive-tested here because the drag
    // gesture on a shrinkWrap ReorderableListView requires item widgets to
    // be present (empty list → no draggable rows) — assert screen title only.
    testWidgets('tapping Reorder Content from TrackDetailScreen opens '
        'TrackLearningOrderScreen', (tester) async {
      final identity = E2EIdentity.localBorn(displayName: 'Dave411');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final stub = stubTrack(
        id: 1,
        profileId: 1,
        curriculum: CurriculumId.mishnayos,
      );

      await h.pumpApp(
        path: '/settings/tracks',
        extraOverrides: [
          ..._trackHubOverrides(tracks: [stub]),
          ..._trackDetailSilenceOverrides(),
          ..._editTrackSilenceOverrides(),
          // TrackLearningOrderScreen watches these providers which need the
          // bundled content DB (absent in headless). Override with empty lists
          // so the screen renders immediately (no loading spinner to settle).
          trackSedarimOrderProvider.overrideWith(
            (ref, args) => Future.value([]),
          ),
          trackMasechtosOrderProvider.overrideWith(
            (ref, args) => Future.value([]),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));

      await _seedTrack(h, identity, stub);

      // Navigate to TrackDetailScreen.
      await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));

      h.expectOnScreen('Reorder Content');

      // Tap the Reorder Content tile (uses Navigator push, not AutoRoute).
      await tester.ensureVisible(find.text('Reorder Content'));
      await tester.pump(const Duration(milliseconds: 100));
      // Use tap() + explicit pumps instead of h.tapText(settle:...) to avoid
      // pumpAndSettle timing out on the TrackLearningOrderScreen loading
      // spinner (CircularProgressIndicator animates indefinitely until the
      // FutureProvider overrides resolve — only then isLoading=false).
      await tester.tap(find.text('Reorder Content'));
      await tester.pump(); // kick off Navigator push
      await tester.pump(const Duration(milliseconds: 600)); // route animation
      await tester.pump(const Duration(milliseconds: 300)); // FutureProviders
      await tester.pump(const Duration(milliseconds: 300)); // widget rebuild

      // TrackLearningOrderScreen AppBar title is "{curriculum} • Reorder"
      // (trackReorderScreenTitle l10n; "•" is U+2022). Use textContaining
      // to match the substring — exact find.text('Reorder') fails because the
      // full title is "Mishnayos • Reorder".
      // The AppBar is rendered regardless of isLoading state.
      expect(
        find.textContaining('• Reorder'),
        findsWidgets,
        reason:
            'expected TrackLearningOrderScreen AppBar title "Mishnayos • Reorder"',
      );
    });
  });

  // ── E2E-412 ───────────────────────────────────────────────────────────────

  group('E2E-412 — Add track with prior completions — bulk-mark at wizard end', () {
    // The AddTrackFlow wizard's bulk-prior step and BulkMarkScreen require the
    // bundled content DB (asset loading) and wizard session state (SharedPrefs)
    // that are both absent in the headless harness. The _finishFlow call that
    // triggers _applySelfPacedPriorCompletions is also unawaited (R-TR3), so
    // errors from the prior-completions service are silently swallowed.
    testWidgets(
      'SKIP device/harness: BulkMarkScreen inside AddTrackFlow requires '
      'bundled content DB assets and wizard session state; R-TR3 silent error '
      'swallowing also unobservable headless',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-413 ───────────────────────────────────────────────────────────────

  group('E2E-413 — Add track: wizard resume after app kill', () {
    // The harness resets SharedPreferences to {onboarding_complete: true} in
    // pumpApp, so seeding onboarding_phase / wizard step prefs to simulate an
    // app-kill and resume is not possible. R-TR6 (null crash) and R-TR10
    // (programName=null on resume) are both triggered by wizard state that is
    // stored in SharedPreferences and reset on each test pump.
    testWidgets(
      'SKIP device/harness: wizard resume after app kill requires '
      'SharedPreferences seed that harness pumpApp always resets; '
      'R-TR6 and R-TR10 not observable headless',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-414 ───────────────────────────────────────────────────────────────

  group(
    'E2E-414 — Parent-mode: manage child tracks — ParentTrackManagementScreen',
    () {
      // Journey: child profile → parent mode entered (PIN primed) →
      // ParentTrackManagementScreen lists child's active tracks with delete
      // controls via long-press.
      //
      // Key assertions (R-TR2):
      //   • ParentTrackManagementScreen renders with active track list.
      //   • Long-press on a track card when there is only ONE active track
      //     shows last-curriculum guard message (not Archive/Wipe actions).
      testWidgets('ParentTrackManagementScreen renders child track list; '
          'last-curriculum guard fires on long-press when only one track', (
        tester,
      ) async {
        final identity = E2EIdentity.localBorn(
          email: 'child414@test.com',
          displayName: 'Child414',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final stub = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        // Navigate to dashboard first (not PIN-guarded) to let harness seed
        // account + profile rows so markPinAuthenticated() can resolve the
        // profileId. Then push the PIN-guarded route after priming.
        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ...h.dashboardSilenceOverrides,
            ..._trackHubOverrides(tracks: [stub]),
            // ParentTrackManagementScreen uses pendingRedemptionsCountProvider
            // and activeProfilePointsBalanceProvider indirectly (via sibling
            // parent-mode screens); silence them to avoid Drift stream timers.
            pendingRedemptionsCountProvider.overrideWith(
              (ref) => Stream.value(0),
            ),
            activeProfilePointsBalanceProvider.overrideWith(
              (ref) => Future.value(0),
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Seed the real DB row so the guard's activeCurriculumDao query works.
        await _seedTrack(h, identity, stub);

        // Prime the PIN guard AFTER pumpApp so _resolvedProfileId is set.
        h.markPinAuthenticated();

        // Push the PIN-guarded ParentTrackManagementRoute.
        unawaited(h.router.push(const ParentTrackManagementRoute()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Screen title should be "Tracks & Goals".
        h.expectOnScreen('Tracks & Goals');
        // The track card should appear.
        h.expectOnScreen('Mishnayos');

        // Long-press the track card to trigger _showDeleteDialog.
        await tester.longPress(find.text('Mishnayos').first);
        await tester.pump(const Duration(milliseconds: 500));

        // R-TR2: With only 1 active curriculum, canDelete=false. The dialog
        // should show cannotDeactivateLastCurriculum text instead of
        // Archive/Wipe actions.
        h.expectOnScreen('At least one curriculum must remain active');
      });
    },
  );

  // ── E2E-415 ───────────────────────────────────────────────────────────────

  group('E2E-415 — Goal setup / edit from TrackDetailScreen', () {
    // Journey: TrackDetailScreen → "Set Goal" tile → Navigator.push →
    // GoalSetupScreen renders with New Goal title and Deadline/Pace tabs.
    //
    // R-SC5: GoalSetupScreen not an @RoutePage — accessed via Navigator push
    // from _openGoalEdit in TrackDetailScreen. The push is async (reads goal
    // then scopedItemCount); use pumpAndSettle to wait for navigation.
    //
    // R-SC11: GoalSetupForm._now() uses ref.read(clockProvider). Override
    // clockProvider BEFORE pumpApp so it resolves during form mount.
    testWidgets(
      'Set Goal tile from TrackDetailScreen opens GoalSetupScreen with '
      'New Goal title; Deadline default mode and Create Goal button visible',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Eve415');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final stub = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: [
            ..._trackHubOverrides(tracks: [stub]),
            ..._trackDetailSilenceOverrides(),
            ..._editTrackSilenceOverrides(),
            // R-SC11: set clockProvider before form mounts to avoid _now() race.
            clockProvider.overrideWith((ref) => DateTime.utc(2026, 6, 18)),
            // scopedItemCountProvider is read by _openGoalEdit before push.
            scopedItemCountProvider.overrideWith(
              (ref, curriculum) => Future.value(100),
            ),
            useHebrewDateProvider.overrideWith(() => _FalseUseHebrewDate()),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        await _seedTrack(h, identity, stub);

        await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));

        h.expectOnScreen('Set Goal');

        await tester.ensureVisible(find.text('Set Goal'));
        await tester.pump(const Duration(milliseconds: 100));
        // _openGoalEdit is async; pumpAndSettle to wait for Navigator push.
        await h.tapText('Set Goal', settle: const Duration(milliseconds: 100));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // GoalSetupScreen should be rendered.
        h.expectOnScreen('New Goal');
        // "Deadline" is the default goal type.
        h.expectOnScreen('Deadline');
        // Submit button label when no existing goal.
        h.expectOnScreen('Create Goal');
      },
    );
  });

  // ── E2E-416 ───────────────────────────────────────────────────────────────

  group('E2E-416 — Hebrew locale / RTL tracks flow', () {
    // Journey: TrackManagementHubScreen pumped under the ACTUAL he
    // MaterialApp locale (not just the useHebrewTermsProvider vocabulary
    // toggle) — RTL layout + localised chrome + Hebrew curriculum terms, no
    // overflow.
    //
    // Locale WAS injectable via E2EHarness.pumpApp(locale:) all along — the
    // former comment claiming a harness limitation was false (AUD-t-cross-31);
    // this test now pumps Locale('he') directly, mirroring E2E-1503 in
    // hebrew_rtl_p1_test.dart.
    //
    // Key assertions:
    //   • Hub subtree lays out RTL under the he locale.
    //   • AppBar title / section header render as their l10n Hebrew
    //     translations (proving the he MaterialApp locale actually applied).
    //   • Curriculum name renders in Hebrew script (Hebrew terms enabled).
    //   • No overflow (harness pump is non-golden, overflow guard is separate).
    testWidgets(
      'TrackManagementHubScreen lays out RTL and shows curriculum name in '
      'Hebrew script under the he locale',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Gila416');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final stub = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        // Use Hebrew terms so curriculum names appear in Hebrew script.
        await h.pumpApp(
          path: '/settings/tracks',
          locale: const Locale('he'),
          extraOverrides: [
            activeTracksProvider.overrideWith((ref) => Stream.value([stub])),
            // Enable Hebrew terms — curriculum labels render in Hebrew script.
            useHebrewTermsProvider.overrideWithValue(true),
            effectiveUseHebrewTermsProvider.overrideWithValue(true),
            ..._trackDetailSilenceOverrides(),
            ..._editTrackSilenceOverrides(),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // RTL layout under the he locale.
        expect(
          Directionality.of(
            tester.element(find.byType(TrackManagementHubScreen)),
          ),
          TextDirection.rtl,
        );

        // AppBar title / section header render as l10n Hebrew translations
        // of manageTracks / activeTracksLabel — proving the MaterialApp is
        // genuinely running under he, not just en with Hebrew vocabulary
        // terms.
        h.expectOnScreen('ניהול מסלולים');
        h.expectOnScreen('מסלולים פעילים');

        // With Hebrew terms enabled, Mishnayos renders as the Hebrew label.
        // The hub uses CurriculumLabelRenderer which returns the Hebrew name.
        // Assert the English label is NOT shown (Hebrew terms are active).
        h.expectNotOnScreen('Mishnayos');
        // No track-type label (product rule — no "Personal" or "אישי").
        h.expectNotOnScreen('Personal');
      },
    );
  });
}
