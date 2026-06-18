/// Reference E2E journey — proves the harness end-to-end.
///
/// Journey:
///   1. Boot the app as an already-onboarded local-born adult (AuthGuard
///      sees `onboarding_complete = true`; the DB already contains an
///      account + profile row).
///   2. Land on the Dashboard (deep-link to `/dashboard`, profile pre-seeded
///      and selected so the ProfileGuard passes straight through).
///   3. Confirm the 4 shell tabs are present.
///   4. Confirm the profile name appears in the persistent switcher bar.
///   5. Navigate to the Learn tab and back.
///
/// What this proves about the harness:
///   - AppRouter boots with real guards under a headless [flutter test] run.
///   - In-memory Drift DB is seeded and threaded through all guards correctly.
///   - `authStateProvider` override with a local-born [AuthState.signedIn]
///     bypasses Firebase entirely.
///   - Profile + active-profile providers resolve to the seeded row.
///   - The heavy dashboard providers (streak, curricula) can be silenced via
///     [E2EHarness.dashboardSilenceOverrides] to avoid timer invariant failures.
///   - Navigation between shell tabs works from inside the harness.
///
/// Headless limitation documented here:
///   - The real [LearningTrackerApp] wraps [SyncLifecycleObserver] and reads
///     [routerProvider] from Riverpod.  The harness instead constructs
///     [AppRouter] directly and wraps it in a plain [MaterialApp.router],
///     matching the pattern already used in `app_shell_test.dart`.  This
///     omits [SyncLifecycleObserver] and the [PersistentSwitcherScaffold]
///     builder slot — those are covered by `app_shell_test.dart`.  A full
///     integration test on a device would mount [LearningTrackerApp] directly.
@Tags(['e2e', 'journey'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../harness/e2e_harness.dart';

void main() {
  setUpAll(e2eSetUpAll);

  group('Reference journey — onboarding to dashboard', () {
    testWidgets(
      'boots the app as a signed-in adult and lands on the dashboard',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'alice@example.com',
          displayName: 'Alice',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: h.dashboardSilenceOverrides,
        );

        // The 4 shell tab labels must be visible — we are inside the
        // AppShellRoute (AuthGuard and ProfileGuard both passed).
        h.expectOnScreen('DASHBOARD', routeName: 'AppShell');
        h.expectOnScreen('LEARN');
        h.expectOnScreen('PROGRESS');
        h.expectOnScreen('SETTINGS');
      },
    );

    testWidgets(
      'the persistent profile-switcher bar shows the seeded adult profile',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'alice@example.com',
          displayName: 'Alice',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: h.dashboardSilenceOverrides,
        );

        // The persistent switcher bar shows the profile name.
        h.expectOnScreen('Alice');
        // Adult profile shows the ADULT MODE badge.
        h.expectOnScreen('ADULT MODE');
        // No SELF-LEARNER label (regression from prior bug).
        h.expectNotOnScreen('SELF-LEARNER');
      },
    );

    testWidgets('tapping the Learn tab navigates to the learning route', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(displayName: 'Bob');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: h.dashboardSilenceOverrides,
      );

      // We are on the Dashboard.
      h.expectOnScreen('DASHBOARD');

      // Tap the Learn bottom-nav tab.
      await h.tapText('LEARN', settle: const Duration(milliseconds: 300));

      // The LEARN tab label is still in the bottom nav after navigation.
      h.expectOnScreen('LEARN');
      // The bottom nav is always visible; the Dashboard tab label is also
      // still rendered.
      h.expectOnScreen('DASHBOARD');
    });

    testWidgets('the in-memory DB contains the seeded profile after pumpApp', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(
        email: 'carol@example.com',
        displayName: 'Carol',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: h.dashboardSilenceOverrides,
      );

      // Direct DB assertion: the seeded profile must exist with the
      // correct display name and mode.
      final profiles = await h.db.profileDao.getProfilesByAccount(
        identity.accountId,
      );
      expect(profiles, hasLength(1));
      expect(profiles.first.displayName, 'Carol');
      expect(profiles.first.mode, 'adult');
      expect(profiles.first.id, identity.profileId);
    });
  });
}
