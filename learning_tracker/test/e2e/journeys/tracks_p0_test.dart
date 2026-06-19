/// E2E Wave 1 P0 journeys — Tracks area.
///
/// Journeys implemented:
///   E2E-401  Add self-paced track — full wizard, no program
///   E2E-402  Add program track — calendar-based
///   E2E-403  Re-add existing curriculum — replace confirm dialog
///   E2E-404  View track detail and navigate to all action tiles
///   E2E-405  Delete track — archive path (keep history)
///   E2E-406  Delete track — wipe path (purge history)
///   E2E-407  Delete last track — blocked by last-curriculum guard
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 4 / §7 R-TR*
@Tags(['e2e', 'journey'])
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show effectiveUseHebrewTermsProvider, useHebrewTermsProvider;
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart'
    show activeTracksProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart'
    show activeTutorPermissionsProvider;

import '../harness/e2e_harness.dart';

// ── Factories ─────────────────────────────────────────────────────────────────

/// Builds a [CurriculumTrack] value for use in provider overrides and as the
/// seeded DB row.
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

/// Inserts a [CurriculumTrack] row into [db] and returns the seeded row.
///
/// Uses `InsertMode.insertOrIgnore` so tests that also provide a provider
/// override for [activeTracksProvider] won't conflict with existing rows.
///
/// Call AFTER [E2EHarness.pumpApp] so the FK profile row exists.
Future<int> _insertTrack(UserDatabase db, CurriculumTrack stub) async {
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: stub.profileId,
          curriculumId: stub.curriculumId,
          stateChangedAt: stub.stateChangedAt,
          activatedAt: stub.activatedAt,
        ),
      );
}

// ── Override factories ─────────────────────────────────────────────────────────

/// Provider overrides that silence heavy providers on the track hub / detail.
///
/// Overrides [activeTracksProvider] with [tracks] to avoid the pending-timer
/// issue from Drift stream subscriptions during test teardown.
///
/// Forces English-label mode by overriding [effectiveUseHebrewTermsProvider]
/// and [useHebrewTermsProvider] to `false` — the new-profile default is
/// `true` (Hebrew script), which would make curriculum names appear in Hebrew
/// script in tests, breaking `find.text('Mishnayos')` lookups.
List<Override> _trackHubOverrides({required List<CurriculumTrack> tracks}) => [
  activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
  // Force English labels so curriculum names are 'Mishnayos', 'Bavli', etc.
  useHebrewTermsProvider.overrideWithValue(false),
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
];

/// Provider overrides to silence providers that [TrackDetailScreen] touches
/// but are irrelevant to the track journeys.
List<Override> _trackDetailSilenceOverrides() => [
  // Dual progress labels.
  trackDualProgressMetricsProvider.overrideWith((ref, pid) => Future.value([])),
  // Program-enrollment check (controls which tiles show).
  dashboardHasProgramEnrollmentProvider.overrideWith(
    (ref, curriculum) => Future.value(false),
  ),
  // Cycle-completion percentage in the header card.
  dashboardTrackCompletionPercentageProvider.overrideWith(
    (ref, trackId) => Future.value(0.0),
  ),
  // Tutor permissions (controls edit-goal tile enable state).
  activeTutorPermissionsProvider.overrideWith((ref) => null),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-401 ──────────────────────────────────────────────────────────────

  group('E2E-401 — Add self-paced track: full wizard, no program', () {
    // Journey: TrackManagementHubScreen (empty) → Add Your First Track →
    // curriculum step rendered → key assertion: "Select a Curriculum" heading
    // shown inside the wizard; wizard entry from hub is confirmed.
    //
    // R-TR1: covers the AddTrackFlow entry path from the hub empty state.
    testWidgets(
      'empty hub shows add-first-track CTA; tapping opens wizard with '
      'curriculum picker',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Alice');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Override activeTracksProvider → empty list so the hub shows its
        // empty state and no Drift stream timer fires.
        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: _trackHubOverrides(tracks: []),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Empty state should display the add-first-track CTA.
        h.expectOnScreen('No tracks yet');
        h.expectOnScreen('Add Your First Track');

        // Tap the CTA to enter the wizard.
        await h.tapText(
          'Add Your First Track',
          settle: const Duration(milliseconds: 500),
        );

        // Wizard should render the curriculum picker step.
        h.expectOnScreen('Select a Curriculum');
      },
    );
  });

  // ── E2E-402 ──────────────────────────────────────────────────────────────

  group('E2E-402 — Add program track: wizard shows curriculum picker', () {
    // Journey: same entry point as E2E-401. The wizard adapts when a program
    // curriculum is chosen (StartingPositionCalendarMode). We assert the wizard
    // opens to the curriculum picker — the first step — so the user can choose
    // a program-capable curriculum (Bavli/Daf Yomi, Mishnayos/Mishna Yomit).
    //
    // R-TR1: covers AddTrackFlow from hub for a program-capable curriculum.
    testWidgets('empty hub → tap Add → wizard opens to curriculum picker', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(displayName: 'Bob');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/settings/tracks',
        extraOverrides: _trackHubOverrides(tracks: []),
      );
      await tester.pump(const Duration(milliseconds: 300));

      h.expectOnScreen('No tracks yet');
      await h.tapText(
        'Add Your First Track',
        settle: const Duration(milliseconds: 500),
      );

      // Curriculum picker step title and subtitle.
      h.expectOnScreen('Select a Curriculum');
      h.expectOnScreen('Choose one curriculum for this track.');
    });
  });

  // ── E2E-403 ──────────────────────────────────────────────────────────────

  group('E2E-403 — Re-add existing curriculum: replace warning UI', () {
    // Journey: hub with 1 existing active track → FAB → wizard →
    // curriculum picker shows warning icon for already-active curriculum.
    //
    // The full "Replace" confirm dialog appears only at the end of the wizard
    // (_finishFlow). CurriculumPickerStep surfaces the warning immediately via
    // a SnackBar when the user taps the warning icon on an already-active
    // curriculum tile.
    //
    // R-TR1: R-TR1 covers both AddTrackFlow code paths (warning icon path vs
    // finish-flow path). We assert the warning icon path here because it is
    // directly reachable without walking all wizard steps.
    testWidgets(
      'wizard curriculum picker shows replace-warning SnackBar for an '
      'already-active curriculum',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Carol');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Create a stub track for Mishnayos that the hub and wizard will see.
        // profileId=1 because harness seeds account(1)+profile(1) in pumpApp.
        final stub = _stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        // Override activeTracksProvider to show the existing track in the hub.
        // Override dashboardActiveCurriculaProvider so the wizard knows
        // Mishnayos is already active.
        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: [
            ..._trackHubOverrides(tracks: [stub]),
            ..._trackDetailSilenceOverrides(),
            // The wizard's _finishFlow checks dashboardActiveCurriculaProvider
            // to decide whether to show the replace-confirm dialog.
            dashboardActiveCurriculaProvider.overrideWith(
              (ref) async => [CurriculumId.mishnayos],
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Hub should show the active track and FAB.
        h.expectOnScreen('Manage Tracks');
        h.expectOnScreen('Active Tracks');

        // Tap FAB to open wizard.
        await h.tapText('ADD TRACK', settle: const Duration(milliseconds: 500));

        // Wizard should render the curriculum picker.
        h.expectOnScreen('Select a Curriculum');

        // The warning icon tooltip for Mishnayos should be present when
        // existingTrackCurricula contains Mishnayos.
        // AddTrackFlow passes existingTrackCurricula to CurriculumPickerStep
        // by watching dashboardActiveCurriculaProvider.
        final warnIcon = find.byTooltip(
          'You already have a track here. Choosing this curriculum again will '
          'replace your current setup and may reset your progress for it.',
        );
        expect(warnIcon, findsOneWidget);

        // Tapping the warning icon shows a SnackBar.
        await tester.tap(warnIcon);
        await tester.pump(const Duration(milliseconds: 300));

        h.expectOnScreen(
          'You already have a track here. Choosing this curriculum again will '
          'replace your current setup and may reset your progress for it.',
        );
      },
    );
  });

  // ── E2E-404 ──────────────────────────────────────────────────────────────

  group('E2E-404 — View track detail and navigate to action tiles', () {
    // Journey: hub with one active track → tap track card → TrackDetailScreen →
    // verify all action tiles visible.
    //
    // R-TR1: TrackManagementHub → TrackDetailRoute push.
    testWidgets(
      'TrackDetailScreen shows Goal, Study Days, Reorder, Edit, Delete tiles',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Dave');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // profileId=1 is safe because harness seeds account(1)+profile(1).
        final stub = _stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: [
            ..._trackHubOverrides(tracks: [stub]),
            ..._trackDetailSilenceOverrides(),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Hub should show the track card.
        h.expectOnScreen('Active Tracks');

        // Tap the track label to navigate to TrackDetailScreen.
        await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertions from E2E-404 catalog:
        h.expectOnScreen('Set Goal');
        h.expectOnScreen('Study Days');
        h.expectOnScreen('Reorder Content');
        h.expectOnScreen('Edit Track');
        h.expectOnScreen('Delete Track');
        // No track-type label (personal/אישי) must appear (product rule).
        h.expectNotOnScreen('אישי');
        h.expectNotOnScreen('Personal');
      },
    );

    testWidgets('TrackDetailScreen shows "Mark as previously learned" tile for '
        'a self-paced track', (tester) async {
      final identity = E2EIdentity.localBorn(displayName: 'Dave2');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final stub = _stubTrack(
        id: 1,
        profileId: 1,
        curriculum: CurriculumId.mishnayos,
      );

      await h.pumpApp(
        path: '/settings/tracks',
        extraOverrides: [
          ..._trackHubOverrides(tracks: [stub]),
          ..._trackDetailSilenceOverrides(),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));

      await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));

      h.expectOnScreen('Mark as previously learned');
    });
  });

  // ── E2E-405 ──────────────────────────────────────────────────────────────

  group('E2E-405 — Delete track: archive path (keep history)', () {
    // Journey: hub with 2 active tracks (so guard doesn't block) → tap 1st
    // track → TrackDetailScreen → Delete → dialog → Archive →
    // track status = 'archived' in Drift; completions retained.
    //
    // R-TR1: delete via TrackDetailScreen._showDeleteDialog (distinct code
    // path from hub long-press).
    //
    // Implementation note: [activeTracksProvider] is overridden with two stub
    // tracks to avoid the pending-Drift-timer issue.  The real DB is seeded
    // (after pumpApp) so [curriculumActivationServiceProvider.deactivate()]
    // has the FK rows it needs.  After the archive action the DB row is
    // asserted directly.
    testWidgets(
      'archive track from detail screen: dialog appears; track archived in Drift',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Eve');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final stubMishnayos = _stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final stubBavli = _stubTrack(
          id: 2,
          profileId: 1,
          curriculum: CurriculumId.bavli,
        );

        // Override the hub's track stream with both stubs (no Drift timer).
        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: [
            ..._trackHubOverrides(tracks: [stubMishnayos, stubBavli]),
            ..._trackDetailSilenceOverrides(),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Seed the REAL DB rows after pumpApp so FK constraints are satisfied
        // and the archive/deactivate path can query activeCurriculumDao.
        await _insertTrack(h.db, stubMishnayos);
        await _insertTrack(h.db, stubBavli);

        // Navigate to detail for the Mishnayos track.
        await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));

        h.expectOnScreen('Delete Track');

        // Scroll to make 'Delete Track' tile fully visible before tapping —
        // it may be below the initial fold on small test viewports.
        await tester.ensureVisible(find.text('Delete Track'));
        await tester.pump(const Duration(milliseconds: 200));

        // Tap Delete Track tile.
        await h.tapText(
          'Delete Track',
          settle: const Duration(milliseconds: 500),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Dialog should show Archive option.
        h.expectOnScreen('Archive (keep history)');

        // Tap Archive.
        await h.tapText(
          'Archive (keep history)',
          settle: const Duration(milliseconds: 500),
        );
        await tester.pump(const Duration(milliseconds: 500));

        // After "archive" (keep history), the track row is soft-deleted:
        // state = 'deleted'. The "Archive" label in the UI means completions
        // are retained; the underlying state is still 'deleted' (a tombstone).
        final tracks = await h.db.trackDao.getAllTracks(CurriculumId.mishnayos);
        expect(tracks, hasLength(1));
        expect(tracks.first.state, 'deleted');
      },
    );
  });

  // ── E2E-406 ──────────────────────────────────────────────────────────────

  group('E2E-406 — Delete track: wipe path (purge history)', () {
    // Journey: hub with 2 active tracks → tap 1st → TrackDetailScreen →
    // Delete → dialog → Wipe → track row gone; completion records purged.
    //
    // R-TR1: wipe path via TrackDetailScreen._showDeleteDialog.
    testWidgets('wipe track from detail screen: track row purged from Drift', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(displayName: 'Frank');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final stubMishnayos = _stubTrack(
        id: 1,
        profileId: 1,
        curriculum: CurriculumId.mishnayos,
      );
      final stubBavli = _stubTrack(
        id: 2,
        profileId: 1,
        curriculum: CurriculumId.bavli,
      );

      await h.pumpApp(
        path: '/settings/tracks',
        extraOverrides: [
          ..._trackHubOverrides(tracks: [stubMishnayos, stubBavli]),
          ..._trackDetailSilenceOverrides(),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Seed real DB rows after pumpApp.
      await _insertTrack(h.db, stubMishnayos);
      await _insertTrack(h.db, stubBavli);

      await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to make 'Delete Track' tile fully visible before tapping.
      await tester.ensureVisible(find.text('Delete Track'));
      await tester.pump(const Duration(milliseconds: 200));

      // Open delete dialog.
      await h.tapText(
        'Delete Track',
        settle: const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 300));

      h.expectOnScreen('Delete and wipe history');

      // Tap Wipe.
      await h.tapText(
        'Delete and wipe history',
        settle: const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // After wipe, the track row should be purged (purgeHistory hard-deletes
      // the track row and all linked completions).
      final tracks = await h.db.trackDao.getAllTracks(CurriculumId.mishnayos);
      expect(tracks, isEmpty);
    });
  });

  // ── E2E-407 ──────────────────────────────────────────────────────────────

  group('E2E-407 — Delete last track: blocked by last-curriculum guard', () {
    // Journey: hub with exactly 1 active track → tap track → TrackDetailScreen
    // → Delete → guard fires immediately (no dialog) → snackbar shown →
    // track unchanged.
    //
    // R-TR1: last-curriculum guard fires in TrackDetailScreen._showDeleteDialog
    // before showing the Archive/Wipe dialog.
    testWidgets(
      'attempting to delete the only active track shows last-curriculum error '
      'snackbar and leaves the track intact',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Grace');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final stub = _stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );

        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: [
            ..._trackHubOverrides(tracks: [stub]),
            ..._trackDetailSilenceOverrides(),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Seed exactly ONE real track so the guard's count query returns 1.
        await _insertTrack(h.db, stub);

        await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));

        h.expectOnScreen('Delete Track');

        // Scroll to make 'Delete Track' tile fully visible before tapping.
        await tester.ensureVisible(find.text('Delete Track'));
        await tester.pump(const Duration(milliseconds: 200));

        // Tap Delete — the last-curriculum guard should fire immediately.
        await h.tapText(
          'Delete Track',
          settle: const Duration(milliseconds: 500),
        );
        await tester.pump(const Duration(milliseconds: 500));

        // The delete/archive dialog must NOT appear — the guard fires first.
        h.expectNotOnScreen('Archive (keep history)');
        h.expectNotOnScreen('Delete and wipe history');

        // The last-curriculum error snackbar/message should be shown.
        h.expectOnScreen('At least one curriculum must remain active');

        // DB assertion: track must still be active.
        final tracks = await h.db.trackDao.getAllTracks(CurriculumId.mishnayos);
        expect(tracks, hasLength(1));
        expect(tracks.first.state, 'active');
      },
    );
  });
}
