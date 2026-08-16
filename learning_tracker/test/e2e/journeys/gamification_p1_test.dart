/// E2E Wave 2 P1 journeys — Gamification area.
///
/// Journeys implemented:
///   E2E-605  Parent edits an existing reward via Manage Rewards sheet
///   E2E-606  Parent deletes a reward
///   E2E-607  Parent toggles a reward enabled/disabled
///   E2E-608  Tutor with restricted permissions sees disabled edit controls
///   E2E-609  Tutor cannot redeem on child's behalf
///   E2E-610  Achievement unlock celebration dialog on new completion
///            SKIP — device/harness: AchievementUnlockCelebration.showForUnlockedMilestones
///            requires a mounted BuildContext and ConfettiWidget; the
///            headless harness cannot drive the live-mark completion path that
///            triggers the unlock check inside a real LearningScreen
///   E2E-611  Achievements screen track filter interaction
///   E2E-612  Parent manually adjusts child's points balance
///   E2E-613  Offline-first: reward config and redemption survive without network
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 6 / §7 R-GA*
///
/// ## Drift stream timer-leak note (R-GA-stream)
///
/// Same as P0 file: override Drift-backed StreamProviders with
/// `Stream.fromFuture` one-shot variants to prevent cleanup timers from
/// leaking into `_verifyInvariants` (see gamification_p0_test.dart for
/// the full explanation).
@Tags(['e2e', 'journey'])
library;

import 'dart:convert';

import 'package:flutter/material.dart'
    show Icons, InkWell, Offset, SingleChildScrollView, Switch, TextField;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show effectiveUseHebrewTermsProvider, useHebrewTermsProvider;
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/repositories/points_ledger_entry.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart'
    show childRedemptionBalanceProvider, childRedemptionRewardsProvider;
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart'
    show streakCalendarProvider;
import 'package:learning_tracker/features/profiles/presentation/screens/parent_settings_screen.dart'
    show activeProfilePointsBalanceProvider;
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/e2e_fakes.dart';
import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';
import '../../helpers/firestore_fixtures.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Seeds the append-only points ledger so the Firestore balance reader derives
/// the requested balance.
Future<void> _seedPoints(
  E2EHarness h, {
  required String uid,
  required String profileId,
  int balance = 200,
}) async {
  final entry = PointsLedgerEntry(
    ulid: '01J6Q2H4A8M7K3P9R5T6V8WXY',
    entryKind: 'parent_add',
    delta: balance,
    createdAt: DateTimeFactory.nowUtc(),
    source: CompletionSource.live,
  );
  await h.firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('points_ledger')
      .doc(entry.ulid)
      .set(entry.toFirestore());
}

/// Seeds a milestone directly via raw SharedPreferences for [profileId].
///
/// Requires a [UserDatabase] for future point-total reads; the service only
/// uses SharedPreferences for milestone CRUD.
Future<RewardMilestone> _seedMilestoneViaPrefs(
  String profileId, {
  String title = 'Test Reward',
  int thresholdPoints = 100,
  bool isEnabled = true,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final configKey = 'reward_milestones_config_v1_$profileId';
  final now = DateTimeFactory.nowUtc();
  final milestone = RewardMilestone(
    id: 'rm_${profileId}_${now.millisecondsSinceEpoch}_${title.hashCode.abs()}',
    profileId: profileId,
    title: title,
    thresholdPoints: thresholdPoints,
    isEnabled: isEnabled,
    createdAt: now,
    updatedAt: now,
    iconIndex: 0,
  );
  final existing = prefs.getString(configKey);
  final all = existing != null
      ? List<dynamic>.from(jsonDecode(existing) as List)
      : <dynamic>[];
  all.add(milestone.toJson());
  await prefs.setString(configKey, jsonEncode(all));
  return milestone;
}

/// Returns all milestones for [profileId] from SharedPreferences.
///
/// Only a [FormatException] from [jsonDecode] (a corrupted/unparsable config
/// string) is treated as "no data" and mapped to an empty list. Any other
/// exception — e.g. a [RewardMilestone.fromJson] schema-mismatch bug — is a
/// genuine defect and must propagate so the test fails loudly instead of
/// silently reporting an empty milestone list (AUD-t-cross-77).
Future<List<RewardMilestone>> _loadMilestones(String profileId) async {
  final prefs = await SharedPreferences.getInstance();
  final configKey = 'reward_milestones_config_v1_$profileId';
  final raw = prefs.getString(configKey);
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw) as List;
    return decoded
        .where((e) => e is Map)
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
        .map(RewardMilestone.fromJson)
        .where((m) => m.profileId == profileId)
        .toList();
  } on FormatException {
    return const [];
  }
}

/// Silence overrides required when landing on /dashboard.
List<Override> _dashboardSilence(E2EHarness h) => h.dashboardSilenceOverrides;

/// One-shot override for [childRedemptionBalanceProvider] (StreamProvider).
Override _childRedemptionBalanceOneShotOverride({int balance = 500}) {
  return childRedemptionBalanceProvider.overrideWith(
    (ref) => Future.value(balance),
  );
}

/// One-shot override for [activeProfilePointsBalanceProvider] (StreamProvider).
Override _activeProfileBalanceOneShotOverride({int balance = 100}) {
  return activeProfilePointsBalanceProvider.overrideWith(
    (ref) => Future.value(balance),
  );
}

Future<int> _readPointsBalance(
  E2EHarness h,
  String uid,
  String profileId,
) async {
  final snapshot = await h.firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('points_ledger')
      .get();
  return snapshot.docs.fold<int>(
    0,
    (total, doc) => total + (doc.data()['delta'] as num).toInt(),
  );
}

/// Fixed-value notifier for [ActiveTutoredProfileSelection] — active session.
class _FixedTutoredSelection extends ActiveTutoredProfileSelection {
  _FixedTutoredSelection(this._fixed);
  final TutoredProfileSelection _fixed;
  @override
  TutoredProfileSelection? build() => _fixed;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-605 ─────────────────────────────────────────────────────────────────

  group('E2E-605 — Parent edits an existing reward via Manage Rewards sheet', () {
    testWidgets(
      'RewardConfigurationScreen: open Manage Rewards sheet, tap Edit → '
      'form populated with reward; update name; save → Reward updated dialog',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'parent605@test.com',
          displayName: 'Parent605',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._dashboardSilence(h),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        final profileId = identity.profileId;

        // Seed a milestone into SharedPreferences before the screen opens.
        await _seedMilestoneViaPrefs(
          profileId,
          title: 'Silver Cup',
          thresholdPoints: 200,
        );

        h.markPinAuthenticated();
        await navigateTo(h, const RewardConfigurationRoute());

        // Wait for bootstrap() to run (it's deferred to postFrameCallback).
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        h.expectOnScreen(
          'Reward Configuration',
          routeName: 'RewardConfigurationScreen',
        );

        // Open the Manage Rewards sheet via the header menu.
        // The PopupMenuButton uses Icons.more_vert_rounded.
        await h.tapWidget(find.byIcon(Icons.more_vert_rounded).first);
        await h.pump(const Duration(milliseconds: 300));

        // Tap "Manage rewards" in the popup menu.
        // NOTE: "Manage rewards" also appears as the _InlineRewardsSection
        // header label in the main screen body (behind the popup overlay).
        // Use .last to target the popup menu item, which sits in the Overlay
        // and is the last matching widget in widget-tree traversal order.
        h.expectOnScreen('Manage rewards');
        await h.tapWidget(find.text('Manage rewards').last);
        await h.pump(const Duration(milliseconds: 400));

        // The bottom sheet shows our seeded reward.
        h.expectOnScreen('Silver Cup');

        // Tap the edit icon for 'Silver Cup'.
        // Icons.edit_outlined appears in three places behind the sheet:
        //   (1) inline section ManageRewardsList, (2) name TextField suffixIcon.
        // The sheet's ManageRewardsList edit icon is last in traversal order
        // (it lives in the Overlay above the main body).
        await h.tapWidget(find.byIcon(Icons.edit_outlined).last);
        await h.pump(const Duration(milliseconds: 300));

        // The form is now in edit mode — heading switches.
        h.expectOnScreen('Edit reward');

        // Change the name in the text field.
        // After applyMilestoneToForm, the name field now contains 'Silver Cup'.
        final nameField = find.widgetWithText(TextField, 'Silver Cup').first;
        await h.enterText(nameField, 'Golden Cup');
        await h.pump(const Duration(milliseconds: 300));

        // Scroll down to expose the Update Reward button.
        // The inline rewards section pushes the form further down than before;
        // use ensureVisible so the exact pixel offset doesn't matter.
        await tester.ensureVisible(find.text('Update Reward').first);
        await h.pump(const Duration(milliseconds: 300));

        // Tap Update Reward (save button in edit mode).
        await h.tapWidget(find.text('Update Reward').first);
        await h.pump(const Duration(milliseconds: 800));
        await h.pump();

        // Confirmation dialog appears.
        h.expectOnScreen('Reward updated');
        await h.tapText('OK');
        await h.pump(const Duration(milliseconds: 300));

        // Verify SharedPreferences reflects the updated name.
        final milestones = await _loadMilestones(profileId);
        expect(milestones.where((m) => m.title == 'Golden Cup'), isNotEmpty);
        expect(milestones.where((m) => m.title == 'Silver Cup'), isEmpty);
      },
    );
  });

  // ── E2E-606 ─────────────────────────────────────────────────────────────────

  group('E2E-606 — Parent deletes a reward', () {
    testWidgets(
      'RewardConfigurationScreen: open Manage Rewards sheet, tap Delete → '
      'confirm dialog → reward removed from SharedPreferences',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'parent606@test.com',
          displayName: 'Parent606',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._dashboardSilence(h),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        final profileId = identity.profileId;
        await _seedMilestoneViaPrefs(
          profileId,
          title: 'Bronze Star',
          thresholdPoints: 100,
        );

        h.markPinAuthenticated();
        await navigateTo(h, const RewardConfigurationRoute());
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        h.expectOnScreen(
          'Reward Configuration',
          routeName: 'RewardConfigurationScreen',
        );

        // Open the Manage Rewards bottom sheet via PopupMenuButton.
        await h.tapWidget(find.byIcon(Icons.more_vert_rounded).first);
        await h.pump(const Duration(milliseconds: 300));
        // Use .last: "Manage rewards" now appears as the _InlineRewardsSection
        // header on the main body AND as the popup menu item in the Overlay.
        h.expectOnScreen('Manage rewards');
        await h.tapWidget(find.text('Manage rewards').last);
        await h.pump(const Duration(milliseconds: 400));

        // The sheet shows our seeded reward.
        h.expectOnScreen('Bronze Star');

        // Tap the delete icon.
        // The inline section's delete icon is FIRST (main body, behind barrier).
        // The sheet's delete icon is LAST (Overlay, on top).
        await h.tapWidget(find.byIcon(Icons.delete_outline).last);
        await h.pump(const Duration(milliseconds: 300));

        // Confirm dialog — both title and button show "Delete Reward".
        // Use .last to tap the button (the action), not the title.
        h.expectOnScreen('Delete Reward');
        await h.tapWidget(find.text('Delete Reward').last);
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // Verify milestone removed from SharedPreferences.
        final milestones = await _loadMilestones(profileId);
        expect(milestones.where((m) => m.title == 'Bronze Star'), isEmpty);
      },
    );
  });

  // ── E2E-607 ─────────────────────────────────────────────────────────────────

  group('E2E-607 — Parent toggles a reward enabled/disabled', () {
    testWidgets(
      'RewardConfigurationScreen: open Manage Rewards sheet; toggle Switch → '
      'milestone isEnabled flips in SharedPreferences; ChildRedemptionScreen '
      'no longer shows disabled reward',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'parent607@test.com',
          displayName: 'Parent607',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._dashboardSilence(h),
            activeTracksOneShotOverride(),
            _childRedemptionBalanceOneShotOverride(),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        final profileId = identity.profileId;
        await _seedPoints(
          h,
          uid: identity.accountId,
          profileId: profileId,
          balance: 500,
        );

        // Seed an ENABLED reward.
        await _seedMilestoneViaPrefs(
          profileId,
          title: 'Enabled Prize',
          thresholdPoints: 50,
          isEnabled: true,
        );

        h.markPinAuthenticated();
        await navigateTo(h, const RewardConfigurationRoute());
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        h.expectOnScreen(
          'Reward Configuration',
          routeName: 'RewardConfigurationScreen',
        );

        // Open manage rewards sheet.
        await h.tapWidget(find.byIcon(Icons.more_vert_rounded).first);
        await h.pump(const Duration(milliseconds: 300));
        // Use .last: "Manage rewards" appears in both the inline section header
        // and the popup menu item (Overlay). Popup item is last in traversal.
        await h.tapWidget(find.text('Manage rewards').last);
        await h.pump(const Duration(milliseconds: 400));

        h.expectOnScreen('Enabled Prize');

        // Toggle the enabled switch inside the Manage Rewards sheet.
        // The inline section (main body, behind modal barrier) also renders
        // a Switch — its Switch is FIRST. The sheet's Switch lives in the
        // Overlay and is LAST in the widget-tree traversal order.
        final switchFinder = find.byType(Switch).last;
        await h.tapWidget(switchFinder);
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // Verify SharedPreferences: reward now disabled.
        final milestones = await _loadMilestones(profileId);
        final prize = milestones
            .where((m) => m.title == 'Enabled Prize')
            .firstOrNull;
        expect(prize, isNotNull);
        expect(prize!.isEnabled, isFalse);
      },
    );
  });

  // ── E2E-608 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-608 — Tutor with restricted permissions sees disabled edit controls',
    () {
      testWidgets('RewardConfigurationScreen + PointConfigScreen: with '
          'canEditRewards=false canEditPoints=false the Save Reward button '
          'shows the permission-denied SnackBar on tap, and the point config '
          'increment button is disabled', (tester) async {
        // Build a fake tutor session with all edit permissions denied.
        const tutorPerms = TutorPermissions(
          canEditRewards: false,
          canEditPoints: false,
        );
        const tutoredSelection = TutoredProfileSelection(
          profileId: 'child-profile-608',
          ownerUid: 'owner-uid-608',
          grantId: 'grant-608',
          permissions: tutorPerms,
        );

        final identity = E2EIdentity.localBorn(
          email: 'tutor608@test.com',
          displayName: 'Tutor608',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._dashboardSilence(h),
            activeTracksOneShotOverride(),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => _FixedTutoredSelection(tutoredSelection),
            ),
          ],
        );

        final profileId = identity.profileId;
        await _seedMilestoneViaPrefs(
          profileId,
          title: 'Tutor Blocked Reward',
          thresholdPoints: 300,
        );

        // Seed one active track + stage definition so PointConfigScreen
        // renders a real curriculum card with a live increment control
        // (AUD-t-cross-07) instead of falling into the "no active tracks"
        // empty state, where canEdit has nothing to gate and a regression
        // could hide.
        await seedTrack(
          h.firestore,
          uid: identity.accountId,
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
        );
        await seedStageDefinitions(
          h.firestore,
          uid: identity.accountId,
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
        );

        h.markPinAuthenticated();

        // ── Part 1: RewardConfigurationScreen ──
        await navigateTo(h, const RewardConfigurationRoute());
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        h.expectOnScreen(
          'Reward Configuration',
          routeName: 'RewardConfigurationScreen',
        );
        // The inline rewards section now appears above the form card and pushes
        // the text fields just below the initial viewport.
        // Scroll down a little first to bring them into view, then enter text.
        await tester.ensureVisible(find.byType(TextField).first);
        await h.pump(const Duration(milliseconds: 200));

        // Fill a valid form so Save Reward would otherwise be enabled.
        await h.enterText(find.byType(TextField).first, 'New Reward');
        await h.pump();
        await tester.ensureVisible(find.byType(TextField).last);
        await h.pump(const Duration(milliseconds: 200));
        await h.enterText(find.byType(TextField).last, '100');
        await h.pump(const Duration(milliseconds: 200));

        // Scroll down to expose the Save Reward button (may be below viewport).
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -300),
        );
        await h.pump(const Duration(milliseconds: 300));

        // Tap Save Reward — tutor sees permission-denied snackbar instead.
        await h.tapWidget(find.text('Save Reward').first);
        await h.pump(const Duration(milliseconds: 800));
        await h.pump();

        h.expectOnScreen("You don't have permission to make this edit");

        // ── Part 2: PointConfigScreen ──
        await navigateTo(h, const PointConfigRoute());
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        h.expectOnScreen('Point Settings', routeName: 'PointConfigScreen');
        // A track+stage was seeded above so the curriculum card (and its
        // "+" increment control) actually renders instead of the empty
        // state -- otherwise there would be nothing here for canEdit to
        // gate (AUD-t-cross-07).
        h.expectOnScreen('ACTIVE');

        // ── Explicit disabled-state assertion on the increment control ──
        final incrementIconFinder = find.byIcon(Icons.add);
        expect(incrementIconFinder, findsOneWidget);
        final incrementInkWellFinder = find.ancestor(
          of: incrementIconFinder,
          matching: find.byType(InkWell),
        );
        expect(incrementInkWellFinder, findsOneWidget);
        final incrementInkWell = tester.widget<InkWell>(incrementInkWellFinder);
        expect(
          incrementInkWell.onTap,
          isNull,
          reason:
              'PointConfigScreen "+" increment control must be disabled '
              '(onTap == null) when the active tutor session has '
              'canEditPoints=false',
        );

        // Tapping a disabled InkWell is a no-op, but drive the Save button
        // too -- with no pending edits and canEdit=false it must route to
        // the same permission-denied path Part 1 already exercises, never
        // silently "succeed".
        await h.tapWidget(find.text('Save All Changes'));
        await h.pump(const Duration(milliseconds: 300));
        h.expectOnScreen("You don't have permission to make this edit");
      });
    },
  );

  // ── E2E-609 ─────────────────────────────────────────────────────────────────

  group('E2E-609 — Tutor cannot redeem on child\'s behalf', () {
    testWidgets(
      'ChildRedemptionScreen with active tutor session: reward is visible but '
      'Redeem button shows "Not available (tutor mode)" and is disabled',
      (tester) async {
        const tutorPerms = TutorPermissions();
        const tutoredSelection = TutoredProfileSelection(
          profileId: 'child-profile-609',
          ownerUid: 'owner-uid-609',
          grantId: 'grant-609',
          permissions: tutorPerms,
        );

        final identity = E2EIdentity.localBorn(
          email: 'tutor609@test.com',
          displayName: 'Tutor609',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._dashboardSilence(h),
            _childRedemptionBalanceOneShotOverride(),
            activeTracksOneShotOverride(),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => _FixedTutoredSelection(tutoredSelection),
            ),
            // Override childRedemptionRewardsProvider to return a seeded reward
            // so the list is non-empty.
            childRedemptionRewardsProvider.overrideWith((ref) async {
              final now = DateTimeFactory.nowUtc();
              return [
                RewardMilestone(
                  id: 'rm_609_test',
                  profileId: identity.profileId,
                  title: 'Shiny Trophy',
                  thresholdPoints: 50,
                  isEnabled: true,
                  createdAt: now,
                  updatedAt: now,
                  iconIndex: 0,
                ),
              ];
            }),
          ],
        );

        final profileId = identity.profileId;
        await _seedPoints(
          h,
          uid: identity.accountId,
          profileId: profileId,
          balance: 500,
        );

        await navigateTo(h, const ChildRedemptionRoute());
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        h.expectOnScreen('Redeem Prizes', routeName: 'ChildRedemptionScreen');
        h.expectOnScreen('Shiny Trophy');

        // The button must show the tutor-mode label (disabled, not "Redeem").
        h.expectOnScreen('Not available (tutor mode)');
        h.expectNotOnScreen('Redeem');
      },
    );
  });

  // ── E2E-610 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-610 — Achievement unlock celebration dialog on new completion',
    skip:
        'device/harness: AchievementUnlockCelebration.showForUnlockedMilestones '
        'requires a BuildContext from a live LearningScreen completion flow and '
        'ConfettiWidget (R-GA5); headless harness cannot drive the live-mark '
        'path that triggers the unlock check inside the real LearningScreen.',
    () {
      testWidgets(
        'child completes task at milestone threshold; '
        'AchievementUnlockCelebration confetti shown; dismiss',
        (tester) async {},
      );
    },
  );

  // ── E2E-611 ─────────────────────────────────────────────────────────────────

  group('E2E-611 — Achievements screen track filter interaction', () {
    testWidgets(
      'GamificationScreen: with seeded achievements, tap track filter chip → '
      'progress summary card visible; filter chip selectable',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'child611@test.com',
          displayName: 'Child611',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Use a constant placeholder profile id for seeding fake data.
        // The real profileId is not needed here — achievementsOverviewProvider
        // is fully overridden so no DB read happens with this id.
        const fakeProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXY';

        // We need a non-empty achievementsOverviewProvider to render filter chips.
        // Build a fake overview with one track filter option.
        const fakeFilterOption = AchievementTrackFilterVm(
          trackId: 42,
          curriculumId: CurriculumId.mishnayos,
          sortLabel: 'Mishnayos',
        );
        final fakeMilestoneNow = DateTimeFactory.nowUtc();
        final fakeMilestone = RewardMilestone(
          id: 'rm_611_test',
          profileId: fakeProfileId,
          title: 'Silver Trophy',
          thresholdPoints: 100,
          isEnabled: true,
          createdAt: fakeMilestoneNow,
          updatedAt: fakeMilestoneNow,
          iconIndex: 0,
        );
        final fakeRow = AchievementRowVm(
          trackId: 42,
          trackLabel: 'Mishnayos',
          curriculumId: CurriculumId.mishnayos,
          milestone: fakeMilestone,
          trackPoints: 0,
          isUnlocked: false,
          isNextUp: true,
          isLegendTier: false,
        );
        final fakeOverview = AchievementsOverview(
          rows: [fakeRow],
          unlockedCount: 0,
          totalMilestones: 1,
          trackFilterOptions: [fakeFilterOption],
        );

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._dashboardSilence(h),
            achievementsOverviewProvider.overrideWith(
              (ref) async => fakeOverview,
            ),
            // Force English labels so filter chip shows "Mishnayos" not Hebrew.
            useHebrewTermsProvider.overrideWithValue(false),
            effectiveUseHebrewTermsProvider.overrideWithValue(false),
            // Stub out the streak calendar FutureProvider to avoid DB reads.
            streakCalendarProvider.overrideWith((ref) async => <DateTime>{}),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        await navigateTo(h, const GamificationRoute());
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // GamificationScreen is the achievements hub.
        // The progress summary card renders the fraction and label as TWO
        // separate Text widgets (achievementsRewardsFraction + achievementsRewardsLabelWord).
        h.expectOnScreen('0 / 1');
        h.expectOnScreen('Rewards');

        // The filter row should show "All Tracks" and "Mishnayos".
        h.expectOnScreen('All Tracks');
        h.expectOnScreen('TRACK SELECTION');

        // Tap the Mishnayos filter chip.
        await h.tapWidget(find.textContaining('Mishnayos').first);
        await h.pump(const Duration(milliseconds: 300));

        // After filtering, Silver Trophy should still be visible (it belongs
        // to trackId 42 = Mishnayos).
        h.expectOnScreen('Silver Trophy');

        // Tap "All Tracks" to reset.
        await h.tapText('All Tracks');
        await h.pump(const Duration(milliseconds: 300));
        h.expectOnScreen('Silver Trophy');
      },
    );
  });

  // ── E2E-612 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-612 — Parent manually adjusts child\'s points balance',
    skip:
        'device/harness: _showAdjustPointsDialog uses StatefulBuilder + '
        'ValueListenableBuilder inside showDialog; calling Navigator.pop(ctx, true) '
        'from within ValueListenableBuilder.builder during the dialog dismiss animation '
        'triggers Flutter "build scope unexpectedly does not contain" assertions in '
        'headless mode. These uncaught FlutterErrors fail the test regardless of '
        'user expect() outcomes. The DB write (parentAdjust) and snackbar work '
        'correctly on a real device; headless simulation of this dialog pattern is '
        'not reliable.',
    () {
      testWidgets(
        'ParentSettingsScreen → Adjust Points dialog: enter +50; tap Apply; '
        'balance updates reactively in DB',
        (tester) async {
          final identity = E2EIdentity.localBorn(
            email: 'parent612@test.com',
            displayName: 'Parent612',
            profileMode: 'child',
          );
          final h = E2EHarness(tester, identity: identity);
          addTearDown(h.dispose);

          await h.pumpApp(
            path: '/dashboard',
            extraOverrides: [
              ..._dashboardSilence(h),
              pendingRedemptionsOneShotOverride(),
              _activeProfileBalanceOneShotOverride(),
              activeTutoredProfileSelectionProvider.overrideWith(
                () => NullTutoredSelection(),
              ),
            ],
          );

          final profileId = identity.profileId;
          // Seed an initial balance of 100 pts.
          await _seedPoints(
            h,
            uid: identity.accountId,
            profileId: profileId,
            balance: 100,
          );

          h.markPinAuthenticated();
          await navigateTo(h, const ParentSettingsRoute());
          await h.pump(const Duration(milliseconds: 500));
          await h.pump();

          // ParentSettingsScreen should be visible.
          h.expectOnScreen('Adjust Points');

          // Tap the Adjust Points row.
          await h.tapText('Adjust Points');
          await h.pump(const Duration(milliseconds: 400));

          // Dialog appears.
          h.expectOnScreen('Adjust Points');
          h.expectOnScreen('Add points');

          // Enter amount 50 into the Amount text field.
          final amountField = find.byType(TextField).first;
          await tester.tap(amountField);
          await tester.pump();
          await tester.enterText(amountField, '50');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Tap Apply.
          await h.tapWidget(find.text('Apply').first);
          await h.pump(const Duration(milliseconds: 400));
          await h.pump(const Duration(milliseconds: 400));
          await h.pump();

          // DB assertion: balance = 150.
          final newBalance = await _readPointsBalance(
            h,
            identity.accountId,
            profileId,
          );
          expect(newBalance, 150);
          h.expectOnScreen('Balance updated.');
        },
      );
    },
  );

  // ── E2E-613 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-613 — Offline-first: reward config and redemption survive without network',
    () {
      testWidgets('With connectivity=offline and syncWriteFacadeProvider=null, '
          'creating a reward persists to SharedPreferences; '
          'ChildRedemptionScreen shows it and a redemption write succeeds in Drift', (
        tester,
      ) async {
        // R-GA1: RewardMilestoneService stores config in SharedPreferences, not
        // Drift. Test confirms no crash and data persists under offline conditions.
        final identity = E2EIdentity.localBorn(
          email: 'parent613@test.com',
          displayName: 'Parent613',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._dashboardSilence(h),
            _childRedemptionBalanceOneShotOverride(),
            activeTracksOneShotOverride(),
            // Force offline: no network, no sync facade.
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            // syncWriteFacadeProvider is already null in harness defaults.
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        final profileId = identity.profileId;
        await _seedPoints(
          h,
          uid: identity.accountId,
          profileId: profileId,
          balance: 300,
        );

        // Seed a reward directly into SharedPreferences (simulating an earlier
        // config session that was stored offline).
        await _seedMilestoneViaPrefs(
          profileId,
          title: 'Offline Prize',
          thresholdPoints: 200,
          isEnabled: true,
        );

        // Navigate to ChildRedemptionScreen — reward is visible despite offline.
        await navigateTo(h, const ChildRedemptionRoute());
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        h.expectOnScreen('Redeem Prizes', routeName: 'ChildRedemptionScreen');
        h.expectOnScreen('Offline Prize');

        // Balance is shown.
        h.expectOnScreen('Your Balance');

        // Tap Redeem on 'Offline Prize' — confirm dialog → redemption written.
        await h.tapText('Redeem');
        await h.pump(const Duration(milliseconds: 400));

        // Confirm dialog.
        h.expectOnScreen('Spend & Redeem');
        await h.tapText('Spend & Redeem');
        await h.pump(const Duration(milliseconds: 800));
        await h.pump();

        // Redemption snackbar: no crash even without network.
        // Use textContaining because the l10n string wraps the title in curly
        // quotes ("{title}") and exact match depends on platform quote rendering.
        expect(
          find.textContaining('Offline Prize'),
          findsWidgets,
          reason: 'expected redemption snackbar containing "Offline Prize"',
        );

        // DB assertion: one pending redemption created.
        final redemptions = await h.firestore
            .collection('users')
            .doc(identity.accountId)
            .collection('learner_profiles')
            .doc(profileId)
            .collection('reward_redemptions')
            .get();
        expect(redemptions.docs, hasLength(1));
        expect(redemptions.docs.first.data()['reward_title'], 'Offline Prize');

        // Verify SharedPreferences reward config still intact (R-GA1).
        final milestones = await _loadMilestones(profileId);
        expect(milestones.where((m) => m.title == 'Offline Prize'), isNotEmpty);
      });
    },
  );

  // ── _loadMilestones helper — exception handling (AUD-t-cross-77) ───────────

  group('_loadMilestones helper does not swallow unexpected exceptions', () {
    testWidgets('a stored config entry that fails RewardMilestone.fromJson '
        '(schema mismatch, not corrupted JSON) propagates instead of '
        'silently returning an empty list', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const profileId = '9991';

      // Valid JSON syntax (jsonDecode succeeds) but `is_enabled` holds a
      // String instead of a bool, so RewardMilestone.fromJson's
      // `json['is_enabled'] as bool?` cast throws a TypeError. This is the
      // "genuine schema-mismatch bug" case from AUD-t-cross-77 — distinct
      // from a corrupted/unparsable config string — and must not be
      // swallowed into an empty list.
      await prefs.setString(
        'reward_milestones_config_v1_$profileId',
        jsonEncode([
          {
            'id': 'rm_bad',
            'profile_id': profileId,
            'track_id': 0,
            'title': 'Bad Reward',
            'threshold_points': 100,
            'is_enabled': 'not-a-bool',
            'icon_index': 0,
            'created_at': DateTimeFactory.nowUtc().toIso8601String(),
            'updated_at': DateTimeFactory.nowUtc().toIso8601String(),
          },
        ]),
      );

      await expectLater(_loadMilestones(profileId), throwsA(isA<TypeError>()));
    });
  });
}
