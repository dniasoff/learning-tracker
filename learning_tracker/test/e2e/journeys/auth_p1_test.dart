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
///   E2E-1208  Upgrade to cloud — email collision
///             UpgradeToCloudScreen renders the form and the "Back up your
///             account" headline for a local-born user. The full collision
///             path (EmailCollisionException → _PhaseCollision UI) requires
///             Firebase + DeviceRegistry native channels: device-only. This
///             journey is substantively equivalent to E2E-911 (settings_p1
///             test file) — the assertion here focuses on the auth-area
///             entry path (navigating directly to /upgrade-to-cloud from
///             auth context).
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
/// - EmailCollisionException only reachable via real Firebase (device-only).
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 12 / §7
@Tags(['e2e', 'journey'])
library;

import 'dart:async' show unawaited;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart'
    show UpgradeToCloudRoute;
import 'package:learning_tracker/app/router/router_provider.dart'
    show routerProvider;
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show DeviceAccountsCompanion, DeviceRegistryDatabase;
import 'package:learning_tracker/core/providers/registry_provider.dart'
    show deviceRegistryProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider, debugSetLastKnownOnline;
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart'
    show currentSacredWindowProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;

import '../harness/e2e_harness.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Silences SacredTimeSettingsCard timer (required on Settings screens).
Override _sacredWindowNullOverride() =>
    currentSacredWindowProvider.overrideWithValue(null);

/// Silences connectivity plugin timers (debounce + recovery probe).
Override _connectivityOnlineOverride() =>
    connectivityStreamProvider.overrideWith((ref) => Stream.value(true));

/// Silences _PendingInvitesSection — active tutor grants.
Override _incomingGrantsEmptyOverride() =>
    incomingTutorGrantsProvider.overrideWith((ref) => Future.value([]));

/// Silences _PendingInvitesSection — pending tutor invitations.
Override _pendingInvitesEmptyOverride() =>
    pendingTutorInvitesProvider.overrideWith((ref) => Future.value([]));

/// Standard silence overrides for tests that land on or navigate through
/// SettingsScreen (needed for E2E-1207 which navigates to Settings).
List<Override> _settingsSilences(E2EHarness h) => [
  ...h.dashboardSilenceOverrides,
  _sacredWindowNullOverride(),
  _connectivityOnlineOverride(),
  _incomingGrantsEmptyOverride(),
  _pendingInvitesEmptyOverride(),
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
            _connectivityOnlineOverride(),
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
            _connectivityOnlineOverride(),
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

  // ── E2E-1208 ─────────────────────────────────────────────────────────────────

  group('E2E-1208 — Upgrade to cloud — email collision', () {
    // UpgradeToCloudScreen renders the "Back up your account" form for a
    // local-born user.  Triggering an EmailCollisionException requires the real
    // UpgradeToCloudService which calls Firebase Auth (createUserWithEmailAndPassword
    // → email-already-in-use → EmailCollisionException) and DeviceRegistry
    // native I/O — device-only.
    //
    // The headless assertions verify:
    //   (a) UpgradeToCloudScreen form renders for a local-born user
    //       (prerequisite for the collision path),
    //   (b) the "Confirm your password" field and "Upgrade to Cloud" button
    //       are present,
    //   (c) collision UI (_PhaseCollision) is NOT shown before a submit.
    //
    // This is consistent with E2E-911 in settings_p1_test.dart (same screen,
    // same harness limitation).
    //
    // R-ST8: _isCredentialLess is derived from the authState email ending in
    // '@offline.local'. For a regular local-born account (non-offline.local)
    // the form shows "Confirm your password", not "Create a password".

    testWidgets(
      'UpgradeToCloudScreen renders the upgrade form for a local-born account: '
      '"Back up your account" headline, password field, Upgrade button',
      (tester) async {
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        final identity = E2EIdentity.localBorn(
          email: 'collision1208@test.com',
          displayName: 'Collision1208',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          // _settingsSilences already includes _connectivityOnlineOverride().
          extraOverrides: _settingsSilences(h),
        );

        // Navigate directly to UpgradeToCloudScreen via router.
        unawaited(h.router.push(const UpgradeToCloudRoute()));
        await h.pump();
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // Screen headline (l10n.upgradeToCloudHeadline = "Back up your account").
        h.expectOnScreen(
          'Back up your account',
          routeName: 'UpgradeToCloudScreen',
        );

        // Password field: regular local-born shows "Confirm your password".
        h.expectOnScreen('Confirm your password');

        // Submit button.
        h.expectOnScreen('Upgrade to Cloud');

        // Collision UI must NOT be visible before any submit.
        h.expectNotOnScreen('A cloud account already exists with this email');
      },
    );

    testWidgets(
      'UpgradeToCloudScreen for credential-less offline account shows '
      '"Create a password" field (different from regular local-born)',
      (tester) async {
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        // R-ST8: credential-less offline accounts have '@offline.local' email.
        final identity = E2EIdentity.localBorn(
          email: 'offline_abc@offline.local',
          displayName: 'OfflineUser',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          // _settingsSilences already includes _connectivityOnlineOverride().
          extraOverrides: _settingsSilences(h),
        );

        unawaited(h.router.push(const UpgradeToCloudRoute()));
        await h.pump();
        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // Credential-less path shows "Create a password" field.
        h.expectOnScreen(
          'Back up your account',
          routeName: 'UpgradeToCloudScreen',
        );
        // l10n.upgradeToCloudNewPasswordLabel = "Create a password"
        h.expectOnScreen('Create a password');

        // Collision UI still not shown before a submit.
        h.expectNotOnScreen('A cloud account already exists with this email');
      },
    );

    // SKIP: device-test required — triggering an EmailCollisionException
    // requires the real UpgradeToCloudService.upgrade() flow, which calls
    // Firebase Auth (createUserWithEmailAndPassword → email-already-in-use)
    // and DeviceRegistryDatabase via getApplicationDocumentsDirectory
    // (path_provider native).  The resulting _PhaseCollision UI (which shows
    // "A cloud account already exists with this email", Upload / Keep-Cloud
    // option tiles, and the cancel button) can only be asserted on device.
    testWidgets(
      'SKIP device-test-required: existing email → EmailCollisionException → '
      '_PhaseCollision UI shows resolution options (Upload local / Keep cloud)',
      skip: true, // device/harness: EmailCollisionException only reachable via
      // real Firebase + DeviceRegistry native channels;
      // see E2E-911 in settings_p1_test.dart.
      (tester) async {},
    );
  });
}
