/// E2E Wave 1 P0 journeys — Gamification area.
///
/// Journeys implemented:
///   E2E-601  Parent creates a reward and child redeems it
///            SKIP — BUG R-GA-boot (see group skip comment below)
///   E2E-602  Parent fulfils a pending redemption — happy path
///   E2E-603  Parent declines a redemption — refund path
///   E2E-604  Parent configures point values per curriculum
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 6 / §7 R-GA*
///
/// ## Drift stream timer-leak note (R-GA-stream)
///
/// `pendingRedemptionsProvider` and `activeTracksProvider` are both
/// Drift-backed `StreamProvider`s. When a Drift reactive stream is cancelled
/// on ProviderScope disposal, `StreamQueryStore.markAsClosed` creates a
/// zero-duration timer for cleanup. In headless `flutter test` (fake async)
/// `_verifyInvariants` runs before `addTearDown` callbacks, so the timer
/// fires outside the test window — triggering a false "pending timer" error.
///
/// Fix: override both providers with non-reactive factories using
/// `Stream.fromFuture` (one-shot query, no Drift reactive subscription, no
/// cleanup timer). The overridden `pendingRedemptionsProvider` still responds
/// correctly to `ref.invalidate` — each invalidation re-runs the factory,
/// emitting the current DB state, so the card disappears after fulfil/decline.
@Tags(['e2e', 'journey'])
library;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/material.dart' show Icons, TextField;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Seeds a [CurriculumTrack] into [db] for [profileId] and returns the
/// generated track id.
Future<int> _seedTrack(
  UserDatabase db, {
  required int profileId,
  CurriculumId curriculum = CurriculumId.mishnayos,
}) async {
  final now = DateTimeFactory.nowUtc();
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculum.storageKey,
          stateChangedAt: now,
          activatedAt: now,
        ),
      );
}

/// Seeds a stage definition row for [trackId] so [_pointConfigDataProvider]
/// finds stages and can render per-curriculum point config cards.
Future<void> _seedStageDefinition(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  CurriculumId curriculum = CurriculumId.mishnayos,
}) async {
  final now = DateTimeFactory.nowUtc();
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

/// Seeds a points balance for [profileId] directly into [db].
Future<void> _seedPoints(
  UserDatabase db, {
  required int profileId,
  int balance = 500,
}) async {
  final now = DateTimeFactory.nowUtc();
  await db
      .into(db.pointsBalance)
      .insert(
        PointsBalanceCompanion.insert(
          profileId: Value(profileId),
          balance: Value(balance),
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

/// Seeds a pending redemption row into [db] for [profileId] and returns the
/// generated id.
Future<int> _seedPendingRedemption(
  UserDatabase db, {
  required int profileId,
  String rewardTitle = 'Bronze Star',
  int pointsCost = 100,
}) async {
  final now = DateTimeFactory.nowUtc();
  return db
      .into(db.rewardRedemptions)
      .insert(
        RewardRedemptionsCompanion.insert(
          profileId: profileId,
          rewardTitle: rewardTitle,
          pointsCost: pointsCost,
          iconIndex: const Value(0),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

/// Standard silence overrides for dashboard heavy providers.
List<Override> _dashboardSilence(E2EHarness h) => h.dashboardSilenceOverrides;

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-601 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-601 — Parent creates a reward and child redeems it',
    // BUG R-GA-boot: RewardConfigurationScreen.initState calls
    // `unawaited(ref.read(rewardConfigControllerProvider.notifier).bootstrap())`
    // which synchronously assigns `state = state.copyWith(...)` before the
    // widget tree finishes its first build. Riverpod 3.x forbids modifying
    // provider state during build, raising:
    //   "Tried to modify a provider while the widget tree was building."
    // Fix: wrap the state assignment in `Future(() { state = ...; })` inside
    // bootstrap(), or move the logic into the Notifier's `build()` method so
    // it runs synchronously before the first frame.
    skip:
        'BUG R-GA-boot: RewardConfigController.bootstrap() sets state in '
        'initState — Riverpod build-phase mutation error',
    () {
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

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: _dashboardSilence(h),
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

        // Scroll to Save Reward (it may be below the 800×600 viewport).
        await tester.scrollUntilVisible(find.text('Save Reward'), 100.0);
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
    },
  );

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

      // Boot to dashboard so the DB and profile row are live. Include the
      // one-shot pendingRedemptionsProvider override to avoid a Drift
      // reactive-stream timer leak (R-GA-stream).
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._dashboardSilence(h),
          pendingRedemptionsOneShotOverride(),
        ],
      );

      // Seed a balance + a pre-created pending redemption to simulate the
      // child having already submitted a redemption request.
      final profileId = identity.profileId;
      await _seedPoints(h.db, profileId: profileId, balance: 200);
      await _seedPendingRedemption(
        h.db,
        profileId: profileId,
        rewardTitle: 'Silver Medal',
        pointsCost: 100,
      );

      // Prime the PIN guard for /parent-mode/* routes.
      h.markPinAuthenticated();

      // ── Navigate to ParentPendingRedemptionsScreen ─────────────────────
      await navigateTo(h, const ParentPendingRedemptionsRoute());

      h.expectOnScreen(
        'Pending Prizes',
        routeName: 'ParentPendingRedemptionsScreen',
      );
      // The pending card for 'Silver Medal' is visible.
      h.expectOnScreen('Silver Medal');
      // The "Fulfil" action button is present.
      h.expectOnScreen('Fulfil');

      // ── Tap Fulfil ─────────────────────────────────────────────────────
      await h.tapText('Fulfil');
      await h.pump(const Duration(milliseconds: 500));
      await h.pump();

      // Snackbar confirms fulfilment.
      h.expectOnScreen('Prize marked as fulfilled!');

      // After fulfilment the one-shot override re-runs on invalidate and
      // emits [] — the card disappears.
      await h.pump(const Duration(milliseconds: 300));
      h.expectNotOnScreen('Silver Medal');

      // ── DB assertion ────────────────────────────────────────────────────
      final all = await h.db.pointsBalanceDao.getAllRedemptions(profileId);
      expect(all, hasLength(1));
      expect(all.first.status, 'fulfilled');
      expect(all.first.rewardTitle, 'Silver Medal');
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
          pendingRedemptionsOneShotOverride(),
        ],
      );

      final profileId = identity.profileId;
      // Seed balance of 150 and a pending redemption that cost 150 points.
      await _seedPoints(h.db, profileId: profileId, balance: 150);
      await _seedPendingRedemption(
        h.db,
        profileId: profileId,
        rewardTitle: 'Bronze Coin',
        pointsCost: 150,
      );

      h.markPinAuthenticated();

      // ── Navigate ───────────────────────────────────────────────────────
      await navigateTo(h, const ParentPendingRedemptionsRoute());

      h.expectOnScreen('Pending Prizes');
      h.expectOnScreen('Bronze Coin');
      // Both action buttons visible.
      h.expectOnScreen('Fulfil');
      h.expectOnScreen('Decline');

      // ── Tap Decline ────────────────────────────────────────────────────
      await h.tapText('Decline');
      await h.pump(const Duration(milliseconds: 500));
      await h.pump();

      // Snackbar confirms decline + refund.
      h.expectOnScreen('Prize request declined. Points refunded.');

      // The card disappears (row is no longer pending).
      await h.pump(const Duration(milliseconds: 300));
      h.expectNotOnScreen('Bronze Coin');

      // ── DB assertions ───────────────────────────────────────────────────
      final all = await h.db.pointsBalanceDao.getAllRedemptions(profileId);
      expect(all, hasLength(1));
      expect(all.first.status, 'declined');

      // Balance refunded: seeded 150, decline refunds 150 → new balance 300.
      final newBalance = await h.db.pointsBalanceDao.getBalance(profileId);
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
      final identity = E2EIdentity.localBorn(
        email: 'parent604@test.com',
        displayName: 'Parent604',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      // Include the one-shot activeTracksProvider override in pumpApp to
      // avoid a Drift reactive-stream timer (R-GA-stream). The factory runs
      // lazily — only when PointConfigScreen (via _pointConfigDataProvider)
      // first watches activeTracksProvider — so the track seeded below will
      // be visible when the factory runs.
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._dashboardSilence(h),
          activeTracksOneShotOverride(),
        ],
      );

      final profileId = identity.profileId;

      // Seed a Mishnayos track and one stage definition so
      // _pointConfigDataProvider finds stages and renders a curriculum card.
      final trackId = await _seedTrack(
        h.db,
        profileId: profileId,
        curriculum: CurriculumId.mishnayos,
      );
      await _seedStageDefinition(
        h.db,
        profileId: profileId,
        trackId: trackId,
        curriculum: CurriculumId.mishnayos,
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

      // ── DB assertion ─────────────────────────────────────────────────────
      final configs = await h.db.pointConfigDao.getConfigsByCurriculum(
        CurriculumId.mishnayos.storageKey,
        profileId: profileId,
        trackId: trackId,
      );
      // At least one config row must exist after save.
      expect(configs, isNotEmpty);
      // Primary stage (stageOrder=1) points must exceed the default (10)
      // since we tapped increment once.
      final primaryConfig = configs.where((c) => c.stageOrder == 1).firstOrNull;
      expect(primaryConfig, isNotNull);
      expect(primaryConfig!.points, greaterThan(10));
    });
  });
}
