/// E2E Wave 2 P1 journeys — Sync / Offline area.
///
/// E2E-1302, E2E-1303, and E2E-1304 are retained as individually skipped
/// retirement records because the old sync engine was intentionally archived.
/// E2E-1306 remains active against the current connectivity and auth model.
///
/// ## E2E-1306 — Offline banner
///
/// The [OfflineTopBanner] is rendered inside AppShell with:
///   `offlineBannerVisible = isCloudBorn && !isOnline`
/// The harness always sets `authState.isCloudBorn = false` (localBorn tier),
/// so even with `connectivityStreamProvider = offline` the banner must remain
/// hidden. The cloud-born offline path (banner visible) is harness-limited
/// because `authStateProvider` is already overridden by the harness and cannot
/// be re-overridden in `extraOverrides`.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 13 / §7
@Tags(['e2e', 'journey'])
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart'
    show AuthState, AuthUser, Tier;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;

import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Shared silence helpers ───────────────────────────────────────────────────

/// Standard silence overrides for sync tests that land on /dashboard.
/// Silence overrides that omit connectivityStreamProvider so the test can
/// inject its own offline connectivity without a "provider overridden twice"
/// error.
List<Override> _syncSilencesNoConnectivity(E2EHarness h) => [
  ...h.dashboardSilenceOverrides,
  sacredWindowNullOverride(),
  incomingGrantsEmptyOverride(),
  pendingInvitesEmptyOverride(),
  // connectivityStreamProvider intentionally NOT overridden here.
];

/// Offline connectivity override.
Override _offlineOverride() =>
    connectivityStreamProvider.overrideWith((ref) => Stream.value(false));

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  group(
    'E2E-1302 — Outbox write queued offline → row present in DB',
    skip:
        'Retired: tests outbox write queuing, deleted in the Drift→Firestore migration (sync engine wholesale-archived). See commit 04897ebc.',
    () {},
  );

  group(
    'E2E-1303 — Sync status indicator: all SyncStatus states render in BackupSyncSection',
    skip:
        'Retired: tests SyncStatus indicator states, deleted in the Drift→Firestore migration (sync engine wholesale-archived). See commit 04897ebc.',
    () {},
  );

  group(
    'E2E-1304 — Two-device sync: LWW merge collapses duplicate completion to one row',
    skip:
        'Retired: tests two-device LWW merge, deleted in the Drift→Firestore migration (sync engine wholesale-archived). See commit 04897ebc.',
    () {},
  );

  group(
    'E2E-1306 — Offline banner: local-born + offline → banner absent; cloud-born + offline → banner visible (device-only)',
    () {
      testWidgets('local-born user offline: OfflineTopBanner is absent '
          '(isCloudBorn=false so banner visibility formula is false)', (
        tester,
      ) async {
        final identity = E2EIdentity.localBorn(
          email: 'localoffline1306@test.com',
          displayName: 'LocalOffline1306',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._syncSilencesNoConnectivity(h),
            _offlineOverride(),
          ],
        );

        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        expect(
          find.textContaining('Offline — changes will sync'),
          findsNothing,
          reason:
              'E2E-1306: local-born user must NOT see the OfflineTopBanner '
              'even when offline (banner is cloud-only)',
        );
      });

      testWidgets('cloud-born user offline: OfflineTopBanner is visible', (
        tester,
      ) async {
        final identity = E2EIdentity.cloudBorn(
          email: 'cloudoffline1306@test.com',
          displayName: 'CloudOffline1306',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._syncSilencesNoConnectivity(h),
            _offlineOverride(),
          ],
        );

        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        expect(
          find.textContaining('Offline — changes will sync'),
          findsWidgets,
          reason:
              'E2E-1306: cloud-born user must see the OfflineTopBanner '
              'when offline (isCloudBorn && !isOnline is true)',
        );
      });
    },
  );

  group('E2E-1306 (supplementary) — authStateProvider is local: '
      'offlineBannerVisible formula evaluates to false', () {
    test('AuthState.local isCloudBorn == false', () {
      const state = AuthState.signedIn(
        user: AuthUser(
          uid: 'uid-1306-local',
          email: 'test@test.com',
          displayName: 'Test',
        ),
        tier: Tier.local,
      );
      expect(
        state.isCloudBorn,
        isFalse,
        reason:
            'E2E-1306: local tier must have isCloudBorn=false so the '
            'offline banner formula always evaluates to false headlessly',
      );
    });

    test('AuthState.cloud isCloudBorn == true', () {
      const state = AuthState.signedIn(
        user: AuthUser(
          uid: 'uid-1306-cloud',
          email: 'test@test.com',
          displayName: 'Test',
        ),
        tier: Tier.cloud,
      );
      expect(
        state.isCloudBorn,
        isTrue,
        reason:
            'E2E-1306: cloud tier must have isCloudBorn=true so the '
            'offline banner formula evaluates to true when offline',
      );
    });
  });
}
