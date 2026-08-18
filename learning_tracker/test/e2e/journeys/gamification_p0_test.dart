/// E2E Wave 1 P0 journeys — Gamification area.
///
/// Journeys implemented:
///   E2E-601  Parent creates a reward and child redeems it
///   E2E-602  Parent fulfils a pending redemption — happy path
///   E2E-603  Parent declines a redemption — refund path
///   E2E-604  Parent configures point values per curriculum
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 6 / §7 R-GA*
///
/// ## Drift stream timer-leak note (R-GA-stream)
///
/// `pendingRedemptionsProvider`, `activeTracksProvider`, and
/// `childRedemptionBalanceProvider` are all Drift-backed `StreamProvider`s.
/// When a Drift reactive stream is cancelled on ProviderScope disposal,
/// `StreamQueryStore.markAsClosed` creates a zero-duration timer for cleanup.
/// In headless `flutter test` (fake async) `_verifyInvariants` runs before
/// `addTearDown` callbacks, so the timer fires outside the test window —
/// triggering a false "pending timer" error.
///
/// Fix: override the providers with non-reactive factories using
/// `Stream.fromFuture` (one-shot query, no Drift reactive subscription, no
/// cleanup timer). The overridden `pendingRedemptionsProvider` still responds
/// correctly to `ref.invalidate` — each invalidation re-runs the factory,
/// emitting the current DB state, so the card disappears after fulfil/decline.
@Tags(['e2e', 'journey'])
library;

import 'package:flutter/material.dart' show Icons, TextField;
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_redemption.dart'
    show RewardRedemptionStatus, rewardRedemptionFromFirestore;
import 'package:learning_tracker/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart'
    show pendingRedemptionsProvider;

import '../../helpers/firestore_fixtures.dart';
import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const _harnessAccountId = 'e2e-account';
const _harnessProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA';

/// Standard silence overrides for dashboard heavy providers.
List<Override> _dashboardSilence(E2EHarness h) => h.dashboardSilenceOverrides;

/// Reads the seeded pending requests directly from this journey's fake
/// Firestore. The shared adapter override is production-shaped, but its
/// resilient stream can emit before a post-pump fixture write is observable
/// in this headless harness; this one-shot query is re-run on invalidation.
Override _pendingRedemptionsFromFirestore(
  E2EHarness h, {
  required String uid,
  required String profileId,
}) => pendingRedemptionsProvider.overrideWith((ref) {
  final query = h.firestore
      .collection('users')
      .doc(uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('reward_redemptions')
      .where('status', isEqualTo: RewardRedemptionStatus.pendingFulfilment);
  return Stream.fromFuture(
    query.get().then(
      (snapshot) => snapshot.docs
          .map((doc) => rewardRedemptionFromFirestore(doc.data()))
          .toList(),
    ),
  );
});

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-601 ─────────────────────────────────────────────────────────────────

  group('E2E-601 — Parent creates a reward and child redeems it', () {
    testWidgets('parent opens RewardConfigurationScreen, creates a reward, '
        'child opens ChildRedemptionScreen and sees it (happy path)', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(
        email: 'parent601@test.com',
        displayName: 'Parent601',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      // Include the one-shot childRedemptionBalanceProvider override to avoid
      // a Drift reactive-stream timer leak (R-GA-stream) — ChildRedemptionScreen
      // (visited below) watches it via _BalanceCard.
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._dashboardSilence(h),
          childRedemptionBalanceOneShotOverride(),
        ],
      );

      h.markPinAuthenticated();

      await navigateTo(h, const RewardConfigurationRoute());

      h.expectOnScreen(
        'Reward Configuration',
        routeName: 'RewardConfigurationScreen',
      );
      h.expectOnScreen('Configure New Reward');

      // Fill the reward form with a name and a point cost.
      await h.enterText(
        find.widgetWithText(TextField, 'e.g., Bronze Star').first,
        'Golden Trophy',
      );
      await h.pump();
      await h.enterText(
        find.widgetWithText(TextField, 'e.g., 500').first,
        '50',
      );
      await h.pump();

      // Scroll to Save Reward (it may be below the 800×600 viewport). The
      // screen has two Scrollables — the form's outer SingleChildScrollView
      // and AvatarPickerRow's inner horizontal ListView — so the default
      // `find.byType(Scrollable)` scrollable finder is ambiguous ("Too many
      // elements"). `.first` resolves to the outer (ancestor) Scrollable,
      // found first in tree-order.
      await tester.scrollUntilVisible(
        find.text('Save Reward'),
        100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await h.tapText('Save Reward');
      await h.pump(const Duration(milliseconds: 500));
      await h.pump();

      h.expectOnScreen('Reward created');
      await h.tapText('OK');
      await h.pump(const Duration(milliseconds: 300));

      // Navigate to ChildRedemptionScreen and verify the new reward.
      await navigateTo(h, const ChildRedemptionRoute());
      h.expectOnScreen('Redeem Prizes', routeName: 'ChildRedemptionScreen');
      h.expectOnScreen('Golden Trophy');
    });
  });

  // ── E2E-602 ─────────────────────────────────────────────────────────────────

  group('E2E-602 — Parent fulfils a pending redemption', () {
    testWidgets('pending redemption appears on ParentPendingRedemptionsScreen; '
        'tap Fulfil → snackbar confirms; redemption status → fulfilled', (
      tester,
    ) async {
      // ── Seed ──────────────────────────────────────────────────────────────
      final identity = E2EIdentity.localBorn(
        email: 'parent602@test.com',
        displayName: 'Parent602',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      // Boot to dashboard so the Firestore account/profile rows are live.
      // Include the one-shot pending-redemptions override so this journey
      // reads the seeded Firestore request without a long-lived stream.
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._dashboardSilence(h),
          _pendingRedemptionsFromFirestore(
            h,
            uid: _harnessAccountId,
            profileId: _harnessProfileId,
          ),
        ],
      );

      // Seed a balance + a pre-created pending redemption to simulate the
      // child having already submitted a redemption request.
      await seedPointsLedgerEntry(
        h.firestore,
        uid: identity.accountId,
        profileId: identity.profileId,
        ulid: '01J6Q2H4A8M7K3P9R5T6V8WXY1',
        delta: 200,
      );
      await seedRewardRedemption(
        h.firestore,
        uid: identity.accountId,
        profileId: identity.profileId,
        ulid: '01J6Q2H4A8M7K3P9R5T6V8WXY2',
        rewardTitle: 'Silver Medal',
        pointsCost: 100,
        status: RewardRedemptionStatus.pendingFulfilment,
      );
      await h.pump();

      // Prime the PIN guard for parent-mode routes.
      h.markPinAuthenticated();

      // ── Navigate to ParentPendingRedemptionsScreen ─────────────────────
      await navigateTo(h, const ParentPendingRedemptionsRoute());
      await tester.pumpAndSettle();

      h.expectOnScreen(
        'Pending Prizes',
        routeName: 'ParentPendingRedemptionsScreen',
      );
      // The pending card for 'Silver Medal' is visible.
      h.expectOnScreen('Silver Medal');
      // The "Fulfil" action button is present.
      h.expectOnScreen('Fulfil');

      // ── Tap Fulfil ─────────────────────────────────────────────────────
      await tester.ensureVisible(find.text('Fulfil'));
      await h.tapText('Fulfil');
      await h.pump(const Duration(milliseconds: 500));
      await h.pump();

      // Snackbar confirms fulfilment.
      h.expectOnScreen('Prize marked as fulfilled!');

      // After fulfilment the one-shot override re-runs on invalidate and
      // emits [] — the card disappears.
      await h.pump(const Duration(milliseconds: 300));
      h.expectNotOnScreen('Silver Medal');

      // ── Firestore assertion ──────────────────────────────────────────────
      final redemption = await h.firestore
          .collection('users')
          .doc(identity.accountId)
          .collection('learner_profiles')
          .doc(identity.profileId)
          .collection('reward_redemptions')
          .doc('01J6Q2H4A8M7K3P9R5T6V8WXY2')
          .get();
      expect(redemption.exists, isTrue);
      expect(redemption.data()?['status'], 'fulfilled');
      expect(redemption.data()?['reward_title'], 'Silver Medal');
    });
  });

  // ── E2E-603 ─────────────────────────────────────────────────────────────────

  group('E2E-603 — Parent declines a redemption — refund path', () {
    testWidgets('pending redemption on ParentPendingRedemptionsScreen; '
        'tap Decline → snackbar confirms; balance refunded', (tester) async {
      // ── Seed ──────────────────────────────────────────────────────────────
      final identity = E2EIdentity.localBorn(
        email: 'parent603@test.com',
        displayName: 'Parent603',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._dashboardSilence(h),
          _pendingRedemptionsFromFirestore(
            h,
            uid: _harnessAccountId,
            profileId: _harnessProfileId,
          ),
        ],
      );

      // Seed balance of 150 and a pending redemption that cost 150 points.
      await seedPointsLedgerEntry(
        h.firestore,
        uid: identity.accountId,
        profileId: identity.profileId,
        ulid: '01J6Q2H4A8M7K3P9R5T6V8WXY3',
        delta: 150,
      );
      await seedRewardRedemption(
        h.firestore,
        uid: identity.accountId,
        profileId: identity.profileId,
        ulid: '01J6Q2H4A8M7K3P9R5T6V8WXY4',
        rewardTitle: 'Bronze Coin',
        pointsCost: 150,
        status: RewardRedemptionStatus.pendingFulfilment,
      );
      await h.pump();

      h.markPinAuthenticated();

      // ── Navigate ───────────────────────────────────────────────────────
      await navigateTo(h, const ParentPendingRedemptionsRoute());
      await tester.pumpAndSettle();

      h.expectOnScreen('Pending Prizes');
      h.expectOnScreen('Bronze Coin');
      // Both action buttons visible.
      h.expectOnScreen('Fulfil');
      h.expectOnScreen('Decline');

      // ── Tap Decline ────────────────────────────────────────────────────
      await tester.ensureVisible(find.text('Decline'));
      await h.tapText('Decline');
      await h.pump(const Duration(milliseconds: 500));
      await h.pump();

      // Snackbar confirms decline + refund.
      h.expectOnScreen('Prize request declined. Points refunded.');

      // The card disappears (row is no longer pending).
      await h.pump(const Duration(milliseconds: 300));
      h.expectNotOnScreen('Bronze Coin');

      // ── Firestore assertions ─────────────────────────────────────────────
      final redemption = await h.firestore
          .collection('users')
          .doc(identity.accountId)
          .collection('learner_profiles')
          .doc(identity.profileId)
          .collection('reward_redemptions')
          .doc('01J6Q2H4A8M7K3P9R5T6V8WXY4')
          .get();
      expect(redemption.exists, isTrue);
      expect(redemption.data()?['status'], 'declined');

      // Balance refunded: seeded 150, decline refunds 150 → new balance 300.
      final ledger = await h.firestore
          .collection('users')
          .doc(identity.accountId)
          .collection('learner_profiles')
          .doc(identity.profileId)
          .collection('points_ledger')
          .get();
      final newBalance = ledger.docs.fold<int>(
        0,
        (balance, doc) => balance + (doc.data()['delta'] as int),
      );
      expect(newBalance, 300);
    });
  });

  // ── E2E-604 ─────────────────────────────────────────────────────────────────

  group('E2E-604 — Parent configures point values per curriculum', () {
    testWidgets('PointConfigScreen renders per-curriculum cards; '
        'tap increment; save → _pointConfigDataProvider updated', (
      tester,
    ) async {
      // ── Seed ──────────────────────────────────────────────────────────────
      const accountId = 'parent604-account';
      const profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA';
      final identity = E2EIdentity.localBorn(
        email: 'parent604@test.com',
        displayName: 'Parent604',
        profileMode: 'child',
        accountId: accountId,
        profileId: profileId,
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      // Seed before pumpApp: activeTracksOneShotOverride reads its Firestore
      // snapshot once, during the initial dashboard build (R-GA-stream) —
      // some dashboard-phase provider already watches activeTracksProvider,
      // so seeding after pumpApp risks the one-shot freezing an empty result.
      await seedTrack(
        h.firestore,
        uid: accountId,
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
      );
      await seedStageDefinitions(
        h.firestore,
        uid: accountId,
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
      );

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._dashboardSilence(h),
          activeTracksOneShotOverride(),
        ],
      );

      h.markPinAuthenticated();

      // ── Navigate to PointConfigScreen ───────────────────────────────────
      await navigateTo(h, const PointConfigRoute());
      // Extra pump for the async _pointConfigDataProvider to resolve.
      await h.pump(const Duration(milliseconds: 500));

      // Screen title and key UI elements.
      h.expectOnScreen('Point Settings', routeName: 'PointConfigScreen');
      h.expectOnScreen('Rewards Strategy');
      h.expectOnScreen('Active Curricula');
      // At least one curriculum card with the "ACTIVE" badge.
      h.expectOnScreen('ACTIVE');
      // Points per task label inside the card.
      h.expectOnScreen('Points per Task');

      // ── Tap the increment (+) button once ──────────────────────────────
      final addButton = find.byIcon(Icons.add).first;
      await h.tapWidget(addButton);
      await h.pump(const Duration(milliseconds: 300));

      // The save bar is always shown; the button becomes enabled on edits.
      h.expectOnScreen('Save All Changes');

      // ── Tap Save All Changes ────────────────────────────────────────────
      await h.tapText('Save All Changes');
      await h.pump(const Duration(milliseconds: 800));
      await h.pump();

      // Saved snackbar confirms.
      h.expectOnScreen('Changes saved and synced.');

      // ── Firestore assertion ──────────────────────────────────────────────
      final configs = await h.firestore
          .collection('users')
          .doc(accountId)
          .collection('learner_profiles')
          .doc(profileId)
          .collection('point_configs')
          .where('curriculum_id', isEqualTo: CurriculumId.mishnayos.storageKey)
          .get();
      // At least one config row must exist after save.
      expect(configs.docs, isNotEmpty);
      // Primary stage (stageOrder=1) points must exceed the default (10)
      // since we tapped increment once.
      final primaryConfig = configs.docs
          .map((doc) => doc.data())
          .where((config) => config['stage_order'] == 1)
          .firstOrNull;
      expect(primaryConfig, isNotNull);
      expect(primaryConfig!['points'], greaterThan(10));
    });
  });
}
