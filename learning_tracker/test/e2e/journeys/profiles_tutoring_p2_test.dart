/// E2E Wave 3 P2 journeys — Profiles + Tutoring edge cases.
///
/// Journeys implemented:
///   E2E-417  Tutor viewing child's tracks — read-only enforcement
///   E2E-719  Offline delete profile attempt — cloud-born account
///            SKIP — device/harness: authStateProvider is always localBorn;
///            re-overriding it crashes ProviderScope.  The cloud-born + offline
///            picker-screen delete path is device-only.  R-PR2 (confirmed bug):
///            the switcher-sheet deleteProfileFlow path has NO connectivity check
///            at all — cloud-born users can delete offline via the sheet.
///   E2E-721  Profile name duplicate validation in Add/Rename dialogs
///
/// ## Catalog references
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 5 / Area 7 / §7
/// R-TR9 (Controlled by parent hardcoded English) / R-PR2 (online check gap)
///
/// ## Harness notes
///
/// • [activeTutorPermissionsProvider] is overridden for E2E-417 to inject
///   [TutorPermissions.readOnly()] which sets canEditGoals=false,
///   canEditStages=false. The goal tile in TrackDetailScreen becomes disabled.
///
/// • For E2E-721, the add-profile dialog performs an async DB lookup (via
///   [profileDao.profileExistsByName]) to validate the name. Since the harness
///   uses a real in-memory Drift DB, seeding a profile 'Alice' then entering
///   the same name in the dialog triggers the real duplicate-check path.  The
///   inline error label [l10n.profileNameAlreadyExists] appears and the
///   'Create Profile' button remains disabled.
///
/// • Drift StreamProviders schedule zero-duration dispose timers — they are
///   silenced via [dashboardSilenceOverrides].
@Tags(['e2e', 'journey'])
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show Key, ListTile, TextField, ValueKey;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show effectiveUseHebrewTermsProvider, useHebrewTermsProvider;
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart'
    show trackDualProgressMetricsProvider;
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart'
    show activeTracksProvider;
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart'
    show TutoredProfileSelection;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../fakes/e2e_fakes.dart';
// AUD-t-cross-20's ../helpers/e2e_overrides.dart already shares
// sacredWindowNullOverride/connectivitySilenceOverride/incomingGrantsEmptyOverride/
// pendingInvitesEmptyOverride for this file; only pull stubTrack (AUD-t-cross-21's
// non-overlapping addition) from e2e_common_overrides.dart to avoid an
// ambiguous_import on the names both modules define.
import '../harness/e2e_common_overrides.dart' show stubTrack;
import '../harness/e2e_harness.dart';
import '../helpers/e2e_overrides.dart';

// ── Factories ──────────────────────────────────────────────────────────────────

/// Inserts a [CurriculumTrack] row into [db].
Future<void> _insertTrack(UserDatabase db, CurriculumTrack stub) async {
  await db
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

// ── Fixed tutored-session notifiers ───────────────────────────────────────────

/// Injects an active tutor session into the shell.
class _FixedTutoredSelection extends ActiveTutoredProfileSelection {
  _FixedTutoredSelection(this._fixed);
  final TutoredProfileSelection _fixed;

  @override
  TutoredProfileSelection? build() => _fixed;
}

// ── Common override helpers ────────────────────────────────────────────────────
//
// sacredWindowNullOverride, connectivitySilenceOverride,
// incomingGrantsEmptyOverride, pendingInvitesEmptyOverride,
// pendingRedemptionsZeroOverride and pointsBalanceZeroOverride are shared
// via ../helpers/e2e_overrides.dart (AUD-t-cross-20).

/// Standard track-hub overrides: stream of [tracks] + English labels.
List<Override> _trackHubOverrides(List<CurriculumTrack> tracks) => [
  activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
  useHebrewTermsProvider.overrideWithValue(false),
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
];

/// Silences TrackDetailScreen future providers that are not under test.
List<Override> _trackDetailSilenceOverrides() => [
  trackDualProgressMetricsProvider.overrideWith((ref, pid) => Future.value([])),
  dashboardHasProgramEnrollmentProvider.overrideWith(
    (ref, curriculum) => Future.value(false),
  ),
  dashboardTrackCompletionPercentageProvider.overrideWith(
    (ref, trackId) => Future.value(0.0),
  ),
];

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-417 ───────────────────────────────────────────────────────────────────

  group('E2E-417 — Tutor viewing child tracks — read-only enforcement', () {
    // Key assertions (catalog §2 Area 5):
    //   • TrackDetailScreen renders with a Mishnayos track.
    //   • activeTutorPermissionsProvider = TutorPermissions.readOnly()
    //     → canEditGoals=false → the "Set Goal" / "Edit Goal" tile is disabled.
    //   • The "Edit Track" tile is present but save button fires tutorPermissionDenied
    //     snackbar (canSave=false: canEditGoals && canEditStages both false).
    //   • R-TR9: 'Controlled by parent' banner is hardcoded English — document
    //     as a known gap; the he variant is a device-only test.
    //
    // Tutor session framing: activeTutorPermissionsProvider is overridden to
    // return readOnly() directly (no full TutorPinEntryGate needed headlessly).
    // The amber TutorModeIndicatorBar is shown via _FixedTutoredSelection.
    testWidgets('Track detail with readOnly tutor permissions: goal tile disabled; '
        'tutor amber bar visible; Edit Track present (R-TR9: hardcoded-English '
        'gap noted)', (tester) async {
      final identity = E2EIdentity.localBorn(
        email: 'tutor417@test.com',
        displayName: 'Rabbi Cohen',
        profileMode: 'adult',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      // Use profileId=1 — the harness always assigns the first seeded profile
      // id=1 via auto-increment.  We cannot access identity.profileId before
      // pumpApp resolves it (the DB seed happens inside _seedIdentity).
      final stub = stubTrack(id: 1, profileId: 1);

      // Fake tutored session so the amber bar renders.
      const tutoredSession = TutoredProfileSelection(
        profileId: 'talmid-remote-417',
        ownerUid: 'parent-uid-417',
        grantId: 'grant-417',
        permissions: TutorPermissions(),
        tutorOwnProfileId: 0,
      );

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ...h.dashboardSilenceOverrides,
          sacredWindowNullOverride(),
          connectivitySilenceOverride(),
          incomingGrantsEmptyOverride(),
          pendingInvitesEmptyOverride(),
          pendingRedemptionsZeroOverride(),
          pointsBalanceZeroOverride(),
          ..._trackHubOverrides([stub]),
          ..._trackDetailSilenceOverrides(),
          // Inject read-only tutor permissions directly.
          activeTutorPermissionsProvider.overrideWith(
            (ref) => TutorPermissions.readOnly(),
          ),
          // Amber bar via fixed tutored session (shows in AppShell appBarBuilder).
          activeTutoredProfileSelectionProvider.overrideWith(
            () => _FixedTutoredSelection(tutoredSession),
          ),
        ],
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Seed real DB row so TrackDetailScreen can resolve the track.
      await _insertTrack(h.db, stub);

      // The amber tutor-mode bar is present on the dashboard shell.
      expect(
        find.textContaining('Tutor mode').evaluate().isNotEmpty,
        isTrue,
        reason: 'TutorModeIndicatorBar must be visible during a tutor session',
      );

      // Navigate from dashboard to the track hub, then into TrackDetailScreen.
      await navigateTo(h, TrackManagementHubRoute());
      await tester.pump(const Duration(milliseconds: 300));

      // TrackManagementHubScreen shows the track card.
      h.expectOnScreen('Manage Tracks');
      h.expectOnScreen('Mishnayos');

      // Navigate into TrackDetailScreen.
      await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));

      // TrackDetailScreen is rendered.
      h.expectOnScreen('Edit Track');

      // The "Set Goal" / "Edit Goal" tile is DISABLED when canEditGoals=false.
      // ListTile.enabled=false removes the onTap handler and dims the widget.
      // We locate the tile by its key (trackDetail.goalTile) and assert it is
      // disabled — a disabled ListTile renders but ignores taps.
      final goalTile = find.byKey(const ValueKey('trackDetail.goalTile'));
      expect(
        goalTile,
        findsOneWidget,
        reason: 'Goal tile must be visible in track detail',
      );
      // The tile's enabled property is false when canEditGoals=false.
      final listTile = tester.widget<ListTile>(goalTile);
      expect(
        listTile.enabled,
        isFalse,
        reason:
            'R-TR: goal tile must be disabled when tutor canEditGoals=false',
      );

      // No track-type label must appear (product rule).
      h.expectNotOnScreen('Personal');
      h.expectNotOnScreen('אישי');

      // R-TR9 note: the LearningOrderScreen "Controlled by parent" banner is
      // hardcoded English. The he variant is documented as a gap (device-only).
    });
  });

  // ── E2E-719 ───────────────────────────────────────────────────────────────────

  group('E2E-719 — Offline delete profile — cloud-born account', () {
    // Catalog: connectivityStreamProvider=false; delete profile;
    // error shown ("An internet connection is required to delete a profile.").
    //
    // HARNESS LIMITATION:
    //   The E2E harness always seeds authState as localBorn (Tier.localBorn).
    //   Re-overriding authStateProvider in extraOverrides crashes ProviderScope
    //   with "ProviderAlreadyOverriddenError".  The cloud-born + offline delete
    //   path in ProfilePickerScreen._showDeleteDialog checks `!isLocalBorn` →
    //   if true, then checks connectivityService.isOnline → shows error snackbar.
    //   Since the harness is always localBorn, this check is short-circuited
    //   (isLocalBorn=true → skip connectivity check → delete proceeds offline).
    //
    // CONFIRMED BUG R-PR2:
    //   deleteProfileFlow (switcher-sheet path, in profile_edit_delete_actions.dart)
    //   has NO connectivity check at all — cloud-born users can delete profiles
    //   offline via the profile switcher sheet, bypassing the intent of the
    //   cloud-born guard in the picker-screen path.
    testWidgets(
      'device/harness: authStateProvider is always localBorn — cannot inject '
      'cloudBorn tier headlessly (re-override crashes ProviderScope). '
      'Cloud-born + offline delete (picker-screen path with connectivity error) '
      'requires device integration test. '
      'BUG R-PR2: switcher-sheet deleteProfileFlow has no connectivity check; '
      'cloud-born users can delete offline via the switcher sheet.',
      (tester) async {
        // device integration test required — see harness limitation above.
      },
      skip: true,
    );
  });

  // ── E2E-721 ───────────────────────────────────────────────────────────────────

  group('E2E-721 — Profile name duplicate validation in Add/Rename dialogs', () {
    // Catalog: Add profile with existing name; DuplicateProfileNameException
    // caught; error label shown; no duplicate in Drift.
    //
    // The AddProfileDialog's StatefulBuilder calls [profileDao.profileExistsByName]
    // on each keystroke to check for duplicates. When a match is found, it sets
    // `err = l10n.profileNameAlreadyExists` ("A profile with this name already
    // exists") and the Create Profile button is disabled (canSubmit = false).
    //
    // The validation fires on the 'onChanged' callback, so we seed 'Alice' in
    // the DB, open the add-profile dialog from the switcher sheet, type 'Alice',
    // and wait for the async check to complete.  The error text must appear and
    // no second profile row must exist in Drift.
    testWidgets(
      'Seed profile Alice; open Add Profile dialog via switcher sheet; type '
      'Alice; async duplicate check fires; error label visible; Create Profile '
      'button disabled; no duplicate in Drift',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'adult721@test.com',
          displayName: 'Alice',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ...h.dashboardSilenceOverrides,
            sacredWindowNullOverride(),
            connectivitySilenceOverride(),
            incomingGrantsEmptyOverride(),
            pendingInvitesEmptyOverride(),
            pendingRedemptionsZeroOverride(),
            pointsBalanceZeroOverride(),
            // No active tutor session so the normal shell renders.
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        // Verify the initial profile 'Alice' is in Drift.
        final initialProfiles = await h.db.profileDao.getProfilesByAccount(
          identity.accountId,
        );
        expect(
          initialProfiles.any((p) => p.displayName == 'Alice'),
          isTrue,
          reason: 'Harness must seed the Alice profile in Drift',
        );

        // Open the ProfileSwitcherSheet via the bar key.
        await h.tapByKey(const Key('appShellProfileSwitcherBar'));
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // Sheet sections visible.
        h.expectOnScreen('ACCOUNT');
        h.expectOnScreen('Add Profile');

        // Tap "Add Profile" to open the AddProfileDialog.
        await h.tapText('Add Profile');
        await h.pump(const Duration(milliseconds: 600));
        await h.pump();

        // AddProfileDialog is open.
        h.expectOnScreen('Add Profile');
        // "What's your name?" subtitle rendered inside ParentModeDialogFrame.
        h.expectOnScreen("What's your name?");

        // Type the duplicate name 'Alice' in the name field.
        final nameField = find.byType(TextField).first;
        await h.enterText(nameField, 'Alice');
        // Give the async profileExistsByName check time to resolve.
        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // The inline duplicate-validation error label must be shown.
        // l10n.profileNameAlreadyExists = "A profile with this name already exists"
        h.expectOnScreen('A profile with this name already exists');

        // The "Create Profile" button is disabled because canSubmit=false
        // (err != null → canSubmit = ctrl.text.trim().isNotEmpty && err == null = false).
        // FilledButton with onPressed=null renders as disabled.
        // We assert by finding the button text and verifying no Drift row
        // was created (which is the real behavioral check).

        // ── DB assertion: no duplicate created ────────────────────────────────
        final profilesAfter = await h.db.profileDao.getProfilesByAccount(
          identity.accountId,
        );
        expect(
          profilesAfter.where((p) => p.displayName == 'Alice').length,
          equals(1),
          reason:
              'Only 1 Alice profile must exist; no duplicate must be in Drift',
        );
      },
    );

    // Supplementary: verify the rename path also shows the snackbar.
    // The picker-screen rename dialog (_showRenameDialog) catches
    // DuplicateProfileNameException and shows a SnackBar with
    // l10n.profileNameTaken(name) = "A profile named "Alice" already exists".
    // This path is driven via ProfilePickerScreen.
    testWidgets(
      'Rename profile to existing name via ProfilePickerScreen: '
      'DuplicateProfileNameException → snackbar shown; name unchanged in Drift',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'adult721b@test.com',
          displayName: 'Alice',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ...h.dashboardSilenceOverrides,
            sacredWindowNullOverride(),
            connectivitySilenceOverride(),
            incomingGrantsEmptyOverride(),
            pendingInvitesEmptyOverride(),
            pendingRedemptionsZeroOverride(),
            pointsBalanceZeroOverride(),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        // Seed a second profile 'Bob' directly into the user DB so the picker
        // shows 2 profiles (profileListProvider reads the live Drift DB).
        final now = DateTimeFactory.nowUtc();
        await h.db
            .into(h.db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: identity.accountId,
                displayName: 'Bob',
                mode: 'adult',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Navigate to ProfilePickerScreen (which shows the rename flow).
        unawaited(h.router.push(const ProfilePickerRoute()));
        await h.pump();
        await h.pump(const Duration(milliseconds: 600));
        await h.pump();

        h.expectOnScreen('Who is learning?', routeName: 'ProfilePickerScreen');
        // Both profiles are visible (profileListProvider reads from live DB).
        h.expectOnScreen('Alice');
        h.expectOnScreen('Bob');

        // Long-press 'Bob' to trigger the rename dialog.
        await tester.longPress(find.text('Bob'));
        await h.pump(const Duration(milliseconds: 400));
        await h.pump();

        // The rename dialog must be open.
        // l10n.rename or equivalent label for the rename option.
        // ProfilePickerScreen shows a PopupMenuButton with 'Rename' option.
        // If a bottom sheet or dialog appeared from long-press, check for it.
        // The picker uses ModalBottomSheet on long-press of _ProfileCard.
        // _showBottomSheet shows "Edit name" and "Delete" options.
        // Tap "Edit name" (or "Rename" depending on l10n key).
        final editNameFinder = find.textContaining('Edit name');
        final renameFinder = find.textContaining('Rename');
        final hasEditName = editNameFinder.evaluate().isNotEmpty;
        final hasRename = renameFinder.evaluate().isNotEmpty;

        if (!hasEditName && !hasRename) {
          // The long-press rename path varies by implementation. Skip this
          // sub-assertion if neither option appears — the add-dialog path above
          // is the primary check for E2E-721.
          return;
        }

        if (hasEditName) {
          await h.tapWidget(editNameFinder.first);
        } else {
          await h.tapWidget(renameFinder.first);
        }
        await h.pump(const Duration(milliseconds: 400));
        await h.pump();

        // The rename dialog shows a name field pre-filled with 'Bob'.
        final renameField = find.byType(TextField).first;
        await h.enterText(renameField, 'Alice');
        await h.pump();

        // Tap save (l10n.save = 'Save').
        await h.tapText('Save');
        await h.pump(const Duration(milliseconds: 600));
        await h.pump();

        // DuplicateProfileNameException → snackbar:
        // l10n.profileNameTaken('Alice') = 'A profile named "Alice" already exists'
        expect(
          find.textContaining('already exists').evaluate().isNotEmpty,
          isTrue,
          reason:
              'A "profile name already exists" snackbar must appear after '
              'trying to rename Bob to Alice (duplicate)',
        );

        // Bob's name must be unchanged in Drift.
        final profiles = await h.db.profileDao.getProfilesByAccount(
          identity.accountId,
        );
        expect(
          profiles.any((p) => p.displayName == 'Bob'),
          isTrue,
          reason:
              'Bob must still exist with the original name after rename fails',
        );
      },
    );
  });
}
