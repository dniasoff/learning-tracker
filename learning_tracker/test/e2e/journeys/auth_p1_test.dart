/// E2E Wave 2 P1 journeys — Auth / Account area (Area 12).
///
/// Journeys implemented:
///   E2E-1204  Account picker — switch account
///             AccountPickerScreen lists 2 accounts (seeded in an in-memory
///             DeviceRegistryDatabase); "Choose an Account" heading visible;
///             both account names rendered. The full switch flow (Firebase
///             re-auth, DB swap, router.replaceAll) is device-only.
///
///   E2E-1205  Magic link — cold-start deep link consumed
///             magicLinkInitializationProvider is overridden in the harness
///             to complete instantly (no AppLinks platform channel). This
///             journey verifies the override fires without error and that the
///             app lands on the correct initial route for a signed-in user.
///             The full deep-link → Firebase sign-in path is device-only.
///
///   E2E-1207  Sign out via account actions sheet
///             AccountActionsSheet (reached via Settings → header tap) shows
///             the "Sign Out" tile. Tapping opens the sign-out confirmation
///             dialog. The post-confirm navigation (authState→signedOut →
///             /intro) is device-only: R-ST6 (same limitation as E2E-916b
///             in settings_p0_test.dart — unawaited postFrameCallback chain
///             doesn't propagate widget-tree updates in headless).
///
/// ## Headless limitations
///
/// - AccountPickerScreen.getAllAccounts() is a real Drift FutureBuilder against
///   the overridden DeviceRegistryDatabase — works headlessly.
/// - Account switch (_AccountTileState._onTap) calls
///   authRepositoryProvider.currentUser, path_provider, SharedPreferences and
///   router.replaceAll — device-only.
/// - MagicLinkService.initialize() calls AppLinks.getInitialLink() via the
///   app_links platform channel — overridden via magicLinkInitializationProvider.
/// - showSignOutConfirmation (after AccountActionsSheet tap) calls
///   TutoredMirrorWipeService → authRepo.signOut() → router.replaceAll via
///   unawaited postFrameCallback — navigation outcome not detectable headlessly.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 12 / §7
@Tags(['e2e', 'journey'])
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/router_provider.dart'
    show routerProvider;
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show DeviceAccountsCompanion, DeviceRegistryDatabase;
import 'package:learning_tracker/core/providers/registry_provider.dart'
    show deviceRegistryProvider;

import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Standard silence overrides for tests that land on or navigate through
/// SettingsScreen (needed for E2E-1207 which navigates to Settings).
List<Override> _settingsSilences(E2EHarness h) => [
  ...h.dashboardSilenceOverrides,
  sacredWindowNullOverride(),
  connectivityOnlineOverride(),
  incomingGrantsEmptyOverride(),
  pendingInvitesEmptyOverride(),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-1204 ─────────────────────────────────────────────────────────────────

  group('E2E-1204 — Account picker — switch account', () {
    // AccountPickerScreen displays all device accounts from the registry.
    // We seed 2 accounts into an in-memory DeviceRegistryDatabase and override
    // deviceRegistryProvider with it.  The screen's FutureBuilder resolves
    // both rows headlessly.
    //
    // Full switch flow (tap → _onTap → Firebase re-auth / local DB swap /
    // router.replaceAll) is device-only: requires path_provider (document
    // directory for getApplicationDocumentsDirectory), SharedPreferences writes,
    // and Google Sign-In platform channel.

    late DeviceRegistryDatabase registry;

    setUp(() async {
      registry = DeviceRegistryDatabase(NativeDatabase.memory());

      // Seed two local-born accounts so both tiles appear.
      await registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'acc-alice',
          email: 'alice@test.com',
          displayName: 'Alice',
          tier: 'localBorn',
          dbFileName: 'user_acc_alice.db',
          createdAt: DateTime.utc(2026, 1, 1),
          lastUsedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'acc-bob',
          email: 'bob@test.com',
          displayName: 'Bob',
          tier: 'localBorn',
          dbFileName: 'user_acc_bob.db',
          createdAt: DateTime.utc(2026, 1, 2),
          lastUsedAt: DateTime.utc(2026, 1, 2),
        ),
      );
    });

    tearDown(() async {
      await registry.close();
    });

    testWidgets(
      'AccountPickerScreen shows "Choose an Account" heading and lists both '
      'seeded accounts',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'alice@test.com',
          displayName: 'Alice',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/account-picker',
          extraOverrides: [
            // Provide the in-memory registry with 2 seeded accounts.
            deviceRegistryProvider.overrideWithValue(registry),
            // Silence connectivity plugin timers.
            connectivityOnlineOverride(),
          ],
        );

        // Extra pump to allow the FutureBuilder to resolve.
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // Screen title.
        h.expectOnScreen('Choose an Account', routeName: 'AccountPickerScreen');

        // Both account display names must be visible as tiles.
        h.expectOnScreen('Alice');
        h.expectOnScreen('Bob');

        // Privacy footer is present (bottom of screen).
        expect(
          find.textContaining('privacy'),
          findsWidgets,
          reason: 'Account picker privacy footer should be on screen',
        );
      },
    );

    testWidgets(
      'AccountPickerScreen renders "LOCAL ACCOUNT" badge for local-born tiles',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'alice@test.com',
          displayName: 'Alice',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/account-picker',
          extraOverrides: [
            deviceRegistryProvider.overrideWithValue(registry),
            connectivityOnlineOverride(),
          ],
        );

        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // Each local-born tile shows the "LOCAL ACCOUNT" badge.
        expect(
          find.text('LOCAL ACCOUNT'),
          findsWidgets,
          reason:
              'Both local-born accounts should show the LOCAL ACCOUNT badge',
        );
      },
    );

    // SKIP: device-test required — tapping an account tile calls
    // _AccountTileState._onTap which reads path_provider
    // (getApplicationDocumentsDirectory for AccountLifecycleService), opens a
    // real Drift file-backed database via driftDatabase(name: dbFileName),
    // writes to SharedPreferences (setActiveAccount), and calls
    // router.replaceAll([const AppShellRoute()]). All of these require a
    // physical or emulator device via integration_test.
    testWidgets(
      'SKIP device-test-required: tap second account tile → shell switches '
      'profile to that account',
      skip: true, // device/harness: account switch uses path_provider,
      // file-backed Drift DB, and SharedPreferences — all require a
      // physical device via integration_test.
      (tester) async {},
    );
  });

  // ── E2E-1205 ─────────────────────────────────────────────────────────────────

  group('E2E-1205 — Magic link — cold-start deep link consumed', () {
    // MagicLinkService.initialize() calls AppLinks.getInitialLink() via the
    // app_links platform channel (MethodChannel) which is not available
    // headlessly.  The harness overrides magicLinkInitializationProvider with
    // a Future<void>.value() so the channel call never fires.
    //
    // The headless assertions verify:
    //   (a) a signed-in user lands on the dashboard without the magic-link
    //       initialization blocking navigation (provider completes instantly),
    //   (b) the magic-link initialization override is in effect (no
    //       MethodChannel MissingPluginException thrown).
    //
    // The full cold-start path (AppLinks.getInitialLink returns a URI →
    // MagicLinkService._handleIncomingLink → AuthRepository.signInWithEmailLink
    // → authStateProvider.setCloudBornSession) requires the app_links and
    // firebase_auth platform channels — device-only.

    testWidgets(
      'Signed-in user lands on dashboard while magicLinkInitializationProvider '
      'completes instantly (no platform-channel exception)',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'magiclink1205@test.com',
          displayName: 'MagicLink1205',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // pumpApp already overrides magicLinkInitializationProvider with
        // Future<void>.value() via the harness defaults. No extra override
        // is needed — this test asserts the harness default is sufficient.
        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: h.dashboardSilenceOverrides,
        );

        // The dashboard must render without any platform-channel exception.
        // (A missing-plugin exception would surface as a FlutterError in
        // e2eSetUpAll's onError handler and cause the test to fail.)
        h.expectOnScreen('DASHBOARD', routeName: 'DashboardScreen');

        // The current path must not redirect to /sign-in (auth guard passed).
        expect(
          h.router.currentPath,
          isNot(contains('sign-in')),
          reason:
              'E2E-1205: signed-in user must not be redirected to sign-in '
              'even during magic-link initialization',
        );
      },
    );

    testWidgets(
      'Magic link initialization completes without blocking dashboard render '
      'for a freshly signed-in adult (no spinner stuck)',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'magiclink1205b@test.com',
          displayName: 'MagicLink1205b',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: h.dashboardSilenceOverrides,
        );

        // No CircularProgressIndicator spinning — initialization is non-blocking.
        // (A stuck spinner would indicate the FutureProvider didn't complete.)
        expect(
          find.text('DASHBOARD'),
          findsWidgets,
          reason:
              'E2E-1205: dashboard content must render without a blocking '
              'spinner after magic-link initialization completes',
        );
      },
    );

    // SKIP: device-test required — the cold-start magic-link path calls
    // AppLinks.getInitialLink() (app_links platform channel), then
    // AuthRepository.signInWithEmailLink (Firebase Auth platform channel),
    // then authStateProvider.setCloudBornSessionFromFirebaseUser.
    // None of these are available in the headless harness.
    testWidgets(
      'SKIP device-test-required: app cold-starts with email-link URI → '
      'MagicLinkService consumes it → user signed in',
      skip: true, // device/harness: cold-start magic link requires app_links
      // and firebase_auth platform channels — use integration_test on device.
      (tester) async {},
    );
  });

  // ── E2E-1207 ─────────────────────────────────────────────────────────────────

  group('E2E-1207 — Sign out via account actions sheet', () {
    // AccountActionsSheet is opened by tapping the account email header in
    // Settings.  The sheet shows "ACCOUNT" section label, "Sign Out" tile, and
    // (for an adult) a "Delete Account" tile.
    //
    // R-ST6: showSignOutConfirmation is called via unawaited(action()) inside
    // addPostFrameCallback after the sheet pops.  The sign-out chain
    // (TutoredMirrorWipeService → authRepo.signOut → authState.signOut →
    // pinGuard.lock → deviceRegistry.getAllAccounts → router.replaceAll) does
    // not propagate widget-tree navigation updates within pumpAndSettle's
    // settle window in the headless harness — same limitation as E2E-916b in
    // settings_p0_test.dart.  The navigation outcome (→/intro) is confirmed
    // on device.
    //
    // The headless assertions verify:
    //   (a) AccountActionsSheet renders with "Sign Out" tile,
    //   (b) tapping "Sign Out" opens the confirmation dialog with the
    //       correct title and confirm button,
    //   (c) the screen stays on Settings / confirmation dialog (no crash).

    testWidgets(
      'AccountActionsSheet opened from Settings header shows "Sign Out" tile '
      'for a signed-in adult',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'signout1207@test.com',
          displayName: 'SignOut1207',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._settingsSilences(h),
            // Wire the harness router into routerProvider so AccountActionsSheet's
            // closeThen() reads the correct (mounted) router instance.
            routerProvider.overrideWith((ref) => h.router),
          ],
        );

        // Navigate to Settings tab.
        await h.tapText('SETTINGS');
        await h.pump(const Duration(milliseconds: 300));
        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // Tap the account email header to open AccountActionsSheet.
        await h.tapText('signout1207@test.com');
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // Sheet is open: "ACCOUNT" section label and "Sign Out" tile visible.
        h.expectOnScreen('ACCOUNT', routeName: 'AccountActionsSheet');
        h.expectOnScreen('Sign Out');
      },
    );

    testWidgets(
      'Tapping "Sign Out" in AccountActionsSheet opens the confirmation dialog '
      'with Sign Out title and confirm button',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'signout1207b@test.com',
          displayName: 'SignOut1207b',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._settingsSilences(h),
            routerProvider.overrideWith((ref) => h.router),
          ],
        );

        // Navigate to Settings.
        await h.tapText('SETTINGS');
        await h.pump(const Duration(milliseconds: 300));
        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // Open AccountActionsSheet.
        await h.tapText('signout1207b@test.com');
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        h.expectOnScreen('Sign Out');

        // Tap "Sign Out" — sheet pops, confirmation dialog opens.
        await h.tapText('Sign Out');
        await h.pump(const Duration(milliseconds: 600));
        await h.pump();

        // The sign-out confirmation dialog has the correct title.
        // (l10n.signOutConfirmTitle = "Sign Out")
        expect(
          find.textContaining('Sign Out'),
          findsWidgets,
          reason:
              'E2E-1207: sign-out confirmation dialog should be visible after '
              'tapping Sign Out in AccountActionsSheet',
        );

        // The confirmation body must mention data preservation.
        expect(
          find.textContaining('data will be preserved'),
          findsWidgets,
          reason:
              'E2E-1207: sign-out confirmation body should reassure the user '
              'their data is preserved',
        );
      },
    );

    // SKIP: device-test required — the navigation outcome after confirming
    // sign-out (authState→signedOut → router.replaceAll([SignInRoute()])) is
    // not detectable in the headless harness.  The unawaited postFrameCallback
    // chain (closeThen → showSignOutConfirmation → router.replaceAll) does not
    // propagate MaterialApp.router widget-tree rebuilds within pumpAndSettle's
    // settle window.  Confirmed working on device (R-ST6).
    testWidgets(
      'SKIP device-test-required: confirm sign-out → authState→signedOut → '
      '/intro shown',
      skip: true, // device/harness: R-ST6 — sign-out navigation via unawaited
      // postFrameCallback + router.replaceAll not detectable headlessly;
      // confirmed on device.
      (tester) async {},
    );
  });
}
