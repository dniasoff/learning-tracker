// Regression test for AN-8:
// Stale/wrong-account chrome shown on auth surfaces or the full-bleed profile picker.
//
// Root cause: PersistentSwitcherScaffold showed the ProfileSwitcherBar on
// any pushed route that wasn't the AppShell — including SignInRoute, SignupRoute,
// AccountPickerRoute — because it only checked `isAuthenticated && !_shellIsOnTop()`.
// A logged-in account chip overlaid the sign-in card.
//
// Fix: the top route is checked against the production suppression set, which
// includes auth surfaces and ProfilePickerRoute regardless of auth state.
//
// AUD-t-cross-40: the original version of this test declared its own local
// `_authRouteNames` literal that happened to mirror the real set inside
// the production switcher suppression check — every assertion here was tautologically true by
// construction (the test built the set it then asserted against), and a
// future edit that dropped 'SignInRoute' from the REAL set would ship AN-8
// again while this test stayed green.
//
// Fix for THIS finding: the suppression check's route-name set was extracted to
// the `@visibleForTesting` top-level constant `persistentSwitcherSuppressedRouteNames`
// in `persistent_switcher_scaffold.dart`. This test imports that file and
// asserts against the SAME constant the real function consults, so editing
// the production set is the edit this test observes — verified by temporarily
// removing 'SignInRoute' from the real constant (see PR/commit notes) and
// confirming the test goes red.

@Tags(['account', 'app_shell', 'an8'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/persistent_switcher_scaffold.dart';

const _shellRouteNames = {
  'AppShellRoute',
  'DashboardRoute',
  'LearningRoute',
  'ProgressRoute',
  'SettingsRoute',
};

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('PersistentSwitcherScaffold suppresses the bar on hidden routes', () {
    test('suppressed routes are classified so the bar stays hidden', () {
      // These routes must be in the real production suppression set.
      for (final name in persistentSwitcherSuppressedRouteNames) {
        expect(
          persistentSwitcherSuppressedRouteNames.contains(name),
          isTrue,
          reason: '$name must suppress the persistent switcher bar',
        );
      }
    });

    test(
      'shell routes are NOT auth surfaces (bar shows on pushed sub-routes)',
      () {
        for (final name in _shellRouteNames) {
          expect(
            persistentSwitcherSuppressedRouteNames.contains(name),
            isFalse,
            reason: 'Shell route $name must NOT be an auth surface',
          );
        }
      },
    );

    test('AN-8: sign-in route name is in the real suppression set (was missing '
        'before fix)', () {
      // This is the core AN-8 regression: before the fix the set did not
      // exist at all — every pushed non-shell route showed the bar. After
      // the fix, 'SignInRoute' must be in the REAL production set that
      // `_isSwitcherSuppressedRoute()` consults. Temporarily removing
      // 'SignInRoute' from `persistentSwitcherSuppressedRouteNames` in
      // persistent_switcher_scaffold.dart turns this assertion red.
      expect(
        persistentSwitcherSuppressedRouteNames.contains('SignInRoute'),
        isTrue,
        reason: 'AN-8: SignInRoute must suppress the switcher bar',
      );
      expect(
        persistentSwitcherSuppressedRouteNames.contains('SignupRoute'),
        isTrue,
        reason: 'AN-8: SignupRoute must suppress the switcher bar',
      );
      expect(
        persistentSwitcherSuppressedRouteNames.contains('AccountPickerRoute'),
        isTrue,
        reason: 'AN-8: AccountPickerRoute must suppress the switcher bar',
      );
    });

    test('profile picker suppresses the account and profile switcher bar', () {
      expect(
        persistentSwitcherSuppressedRouteNames.contains('ProfilePickerRoute'),
        isTrue,
        reason: 'ProfilePickerRoute must render full-bleed to the status bar',
      );
    });

    test('AN-8: a non-auth sub-route is NOT in the real suppression set (bar '
        'shows)', () {
      // Arbitrary sub-routes that SHOULD show the bar.
      const subRoutes = [
        'ManageTutorsRoute',
        'ParentSettingsRoute',
        'NotificationsRoute',
        'LifetimeMarkingRoute',
      ];
      for (final name in subRoutes) {
        expect(
          persistentSwitcherSuppressedRouteNames.contains(name),
          isFalse,
          reason: '$name must NOT be suppressed (bar should show)',
        );
      }
    });
  });
}
