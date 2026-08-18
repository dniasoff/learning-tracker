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

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show effectiveUseHebrewTermsProvider, useHebrewTermsProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart'
    show activeTracksProvider;
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart'
    show curriculumTrackDetailRepositoryProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart'
    show activeTutorPermissionsProvider;

import '../../helpers/firestore_fixtures.dart' show seedTrack;
import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Factories ─────────────────────────────────────────────────────────────────

/// Seeds a [CurriculumTrackEntity] document after [E2EHarness.pumpApp].
Future<void> _seedTrack(
  E2EHarness h,
  E2EIdentity identity,
  CurriculumTrackEntity stub,
) {
  return seedTrack(
    h.firestore,
    uid: identity.accountId,
    profileId: identity.profileId,
    curriculumId: stub.curriculumId,
    state: stub.state,
    activatedAt: stub.activatedAt,
    stateChangedAt: stub.stateChangedAt,
    paceResetDate: stub.paceResetDate,
  );
}

/// Test seam for the wipe path. The production adapter delegates this call to
/// a Cloud Function; this fake applies the same observable document deletion
/// directly to the harness's in-memory Firestore.
class _FakeCurriculumTrackRepository extends Fake
    implements FirestoreCurriculumTrackRepositoryAdapter {
  _FakeCurriculumTrackRepository({
    required this.firestore,
    required this.identity,
  });

  final FakeFirebaseFirestore firestore;
  final E2EIdentity identity;

  @override
  Future<void> deleteTrackPermanently(CurriculumId curriculumId) async {
    await firestore
        .collection('users')
        .doc(identity.accountId)
        .collection('learner_profiles')
        .doc(identity.profileId)
        .collection('curriculum_tracks')
        .doc(curriculumId.storageKey)
        .delete();
  }
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
List<Override> _trackHubOverrides({
  required List<CurriculumTrackEntity> tracks,
}) => [
  activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
  // Force English labels so curriculum names are 'Mishnayos', 'Bavli', etc.
  useHebrewTermsProvider.overrideWithValue(false),
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
];

/// Provider overrides to silence providers that [TrackDetailScreen] touches
/// but are irrelevant to the track journeys.
List<Override> _trackDetailSilenceOverrides() => [
  // Dual progress labels.
  trackDualProgressMetricsProvider.overrideWith((ref) => Future.value([])),
  // Program-enrollment check (controls which tiles show).
  dashboardHasProgramEnrollmentProvider.overrideWith(
    (ref, curriculum) => Future.value(false),
  ),
  // Cycle-completion percentage in the header card.
  dashboardTrackCompletionPercentageProvider.overrideWith(
    (ref, curriculumId) => Future.value(0.0),
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
        // The harness seeds the account/profile documents in pumpApp.
        final stub = stubTrack(
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

        // The harness seeds the account/profile documents in pumpApp.
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
    // track state = 'retired' in Firestore (this screen's Archive choice
    // routes through deactivate()/retireTrack — see the assertion below for
    // why); completions retained.
    //
    // R-TR1: delete via TrackDetailScreen._showDeleteDialog (distinct code
    // path from hub long-press).
    //
    // Implementation note: [activeTracksProvider] is overridden with two stub
    // tracks to avoid the pending-Drift-timer issue.  The real DB is seeded
    // (after pumpApp) so [curriculumActivationServiceProvider.deactivate()]
    // has the related rows it needs. After the archive action the Firestore
    // document is
    // asserted directly.
    testWidgets(
      'archive track from detail screen: dialog appears; track archived in Firestore',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Eve');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final stubMishnayos = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final stubBavli = stubTrack(
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
            // _showDeleteDialog's last-curriculum pre-check (TRK-HUB-04) now
            // reads dashboardActiveCurriculaProvider directly (post-Drift
            // migration; see track_detail_screen.dart's "Active-curricula
            // guards reuse dashboardActiveCurriculaProvider" note), not the
            // hub's stubbed track stream above. Without this override the
            // harness default (empty list) makes the guard think there is
            // <=1 active curriculum and it short-circuits into the
            // last-curriculum error instead of ever opening the
            // Archive/Wipe dialog. Same override E2E-406 already applies for
            // the sibling wipe-path test.
            dashboardActiveCurriculaProvider.overrideWith(
              (ref) async => [CurriculumId.mishnayos, CurriculumId.bavli],
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Seed the Firestore track documents after pumpApp so the account and
        // profile documents already exist.
        await _seedTrack(h, identity, stubMishnayos);
        await _seedTrack(h, identity, stubBavli);

        // Navigate to detail for the Mishnayos track.
        await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

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
        //
        // This exercises curriculumActivationServiceProvider's REAL
        // (non-faked) path end-to-end — the sibling wipe-path test (E2E-406)
        // avoids it via a fake curriculumTrackDetailRepositoryProvider
        // instead. That was only possible after fixing a real lib/ defect:
        // FirestoreCurriculumTrackRepositoryAdapter's constructor used to
        // eagerly evaluate `FirebaseFunctions.instance` in its field
        // initializer, even though retire/archive never touch Cloud
        // Functions (only the wipe/delete path does). With no
        // Firebase.initializeApp() call in this fake-Firestore/fake-Auth
        // harness (by design — fakes are injected via provider overrides),
        // that eager access threw `[core/no-app]` the instant anything
        // resolved curriculumTrackRepositoryAdapterProvider, uncaught from
        // the button's fire-and-forget onTap. Fixed by making `_functions`
        // a `late final` field, so it resolves lazily on first actual use
        // (deleteTrackPermanently only) instead of at construction time.
        await h.tapText(
          'Archive (keep history)',
          settle: const Duration(milliseconds: 500),
        );
        await tester.pump(const Duration(milliseconds: 500));

        // Firestore archive keeps the curriculum document but changes its
        // lifecycle state to 'retired', NOT 'archived' — the old Drift
        // 'deleted' tombstone is intentionally not part of the migrated
        // identity model, and 'retired'/'archived' are two deliberately
        // distinct verbs post-migration (Phase 3 P3-36, commit 02b33ffb):
        // TrackDetailScreen._showDeleteDialog's "Archive (keep history)"
        // choice routes through CurriculumActivationService.deactivate() ->
        // FirestoreCurriculumTrackRepository.retireTrack() -> state
        // 'retired'. The separate .archive() -> archiveTrack() -> state
        // 'archived' path is only used by ParentTrackManagementScreen (a
        // different screen). Both are independently covered by passing
        // tests: track_management_hub_screen_l1_test.dart and
        // curriculum_activation_service_test.dart assert 'retired' for this
        // exact deactivate() call; parent_track_management_screen_l1_test.dart
        // and ts3_parent_track_archive_test.dart assert 'archived' for the
        // separate .archive() call. This test previously asserted 'archived'
        // here, which never matched what TrackDetailScreen's Archive button
        // actually writes.
        final trackDoc = await h.firestore
            .collection('users')
            .doc(identity.accountId)
            .collection('learner_profiles')
            .doc(identity.profileId)
            .collection('curriculum_tracks')
            .doc(CurriculumId.mishnayos.storageKey)
            .get();
        expect(trackDoc.exists, isTrue);
        expect(trackDoc.data()?['state'], 'retired');
      },
    );
  });

  // ── E2E-406 ──────────────────────────────────────────────────────────────

  group('E2E-406 — Delete track: wipe path (purge history)', () {
    // Journey: hub with 2 active tracks → tap 1st → TrackDetailScreen →
    // Delete → dialog → Wipe → track row gone; completion records purged.
    //
    // R-TR1: wipe path via TrackDetailScreen._showDeleteDialog.
    testWidgets(
      'wipe track from detail screen: track row purged from Firestore',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Frank');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final stubMishnayos = stubTrack(
          id: 1,
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
        );
        final stubBavli = stubTrack(
          id: 2,
          profileId: 1,
          curriculum: CurriculumId.bavli,
        );

        await h.pumpApp(
          path: '/settings/tracks',
          extraOverrides: [
            ..._trackHubOverrides(tracks: [stubMishnayos, stubBavli]),
            ..._trackDetailSilenceOverrides(),
            dashboardActiveCurriculaProvider.overrideWith(
              (ref) async => [CurriculumId.mishnayos, CurriculumId.bavli],
            ),
            curriculumTrackDetailRepositoryProvider.overrideWithValue(
              _FakeCurriculumTrackRepository(
                firestore: h.firestore,
                identity: identity,
              ),
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Seed Firestore track documents after pumpApp.
        await _seedTrack(h, identity, stubMishnayos);
        await _seedTrack(h, identity, stubBavli);

        await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

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

        // After wipe, the Firestore track document should be purged (the
        // migrated path hard-deletes the track and linked data).
        final trackDoc = await h.firestore
            .collection('users')
            .doc(identity.accountId)
            .collection('learner_profiles')
            .doc(identity.profileId)
            .collection('curriculum_tracks')
            .doc(CurriculumId.mishnayos.storageKey)
            .get();
        expect(trackDoc.exists, isFalse);
      },
    );
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
          ],
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Seed exactly ONE Firestore track so the guard's count query returns 1.
        await _seedTrack(h, identity, stub);

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

        // Firestore assertion: track must still be active.
        final trackDoc = await h.firestore
            .collection('users')
            .doc(identity.accountId)
            .collection('learner_profiles')
            .doc(identity.profileId)
            .collection('curriculum_tracks')
            .doc(CurriculumId.mishnayos.storageKey)
            .get();
        expect(trackDoc.exists, isTrue);
        expect(trackDoc.data()?['state'], 'active');
      },
    );
  });
}
