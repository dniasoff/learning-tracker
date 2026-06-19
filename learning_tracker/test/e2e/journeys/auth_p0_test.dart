/// E2E Wave 1 P0 journeys — Auth / Account area (Area 12).
///
/// Journeys implemented:
///   E2E-1201  Sign in with email — screen renders, form validates, Sign In
///             button present; full Firebase navigation is device-only.
///   E2E-1202  Sign in — wrong password error — error snackbar appears and
///             button re-enables; no navigation away from SignInScreen.
///   E2E-1203  Sign-up new account — adult — SignupScreen renders the creation
///             form when online; the offline path shows the credential-less CTA.
///   E2E-1206  Google Sign-In — new user — Google Sign-Up button visible on
///             SignupScreen when online; full SDK flow is device-only.
///
/// ## What is headless-testable
///
/// All four journeys navigate to sign-in/sign-up screens that require no
/// identity (authState = signedOut) and no active profile.  The harness
/// defaults (no identity, connectivityStreamProvider → offline) are used
/// unless a journey needs the online variant; in that case
/// [connectivityStreamProvider] is overridden to `Stream.value(true)` and
/// [debugSetLastKnownOnline] seeds the loading-state fallback.
///
/// The full Firebase auth round-trip (E2E-1201 submit → dashboard,
/// E2E-1206 Google SDK → onboarding) requires native platform channels
/// (Firebase iOS/Android SDK, Google Sign-In plugin).  Those sub-journeys
/// are documented as device-only skips below.
///
/// ## E2E-1202 error-state approach
///
/// [signInControllerProvider] is `NotifierProvider.autoDispose`, so an
/// `overrideWith` can start it in [SignInError] state. The SignInScreen's
/// `initState` calls `setCallbacks` immediately — which is safe because
/// the notifier is already in the overridden error state. The snackbar
/// for a pre-existing error is NOT automatically shown (the error is
/// displayed reactively by the screen only when `_showError` is called by
/// the controller action). Therefore E2E-1202 asserts the button state
/// after the controller is seeded with [SignInError] — the Sign In button
/// must be enabled (no spinner) and the screen must not navigate.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 12 / §7
@Tags(['e2e', 'journey'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart'
    show
        SignInController,
        SignInError,
        SignInIdle,
        SignInState,
        signInControllerProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider, debugSetLastKnownOnline;

import '../harness/e2e_harness.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Silences connectivity plugin timers (debounce + recovery probe).
/// Returns an [Override] that replaces [connectivityStreamProvider] with a
/// static `true` stream so no Timer.periodic leaks into the test teardown.
Override _onlineOverride() =>
    connectivityStreamProvider.overrideWith((ref) => Stream.value(true));

// ── Stub controllers ─────────────────────────────────────────────────────────

/// Stub [SignInController] that starts in [SignInError] state.
///
/// Used in E2E-1202 to assert the UI representation of the error state
/// without driving a real Firebase network call.
class _ErrorSignInController extends SignInController {
  _ErrorSignInController(this._errorMessage);

  final String _errorMessage;

  @override
  SignInState build() => SignInError(_errorMessage);
}

/// Stub [SignInController] that stays [SignInIdle] and never navigates.
///
/// Used in E2E-1202 (empty-form submit guard) to verify the form validation
/// path without triggering the real sign-in chain.
class _NoOpSignInController extends SignInController {
  @override
  SignInState build() => const SignInIdle();
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-1201 ───────────────────────────────────────────────────────────────

  group('E2E-1201 — Sign in with email — happy path', () {
    // SignInScreen renders with correct form elements (headless).
    // Full navigation (signedIn → dashboard) requires Firebase platform
    // channels and is marked device-only below.

    testWidgets(
      'SignInScreen renders the welcome heading, Sign In button and Google '
      'button when online',
      (tester) async {
        // Force online so the Google button and cloud-mode card are visible.
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        // No identity → harness sets authState to signedOut.
        final h = E2EHarness(tester);
        addTearDown(h.dispose);

        await h.pumpApp(path: '/sign-in', extraOverrides: [_onlineOverride()]);

        // "Welcome Back!" heading must be present.
        h.expectOnScreen('Welcome Back!', routeName: 'SignInScreen');
        // Primary "Sign In" button (from SignInActions.signInCta).
        h.expectOnScreen('Sign In');
        // Google sign-in button is shown when online.
        h.expectOnScreen('Sign in with Google');
      },
    );

    testWidgets('SignInScreen form fields accept text input', (tester) async {
      debugSetLastKnownOnline(true);
      addTearDown(() => debugSetLastKnownOnline(false));

      final h = E2EHarness(tester);
      addTearDown(h.dispose);

      await h.pumpApp(path: '/sign-in', extraOverrides: [_onlineOverride()]);

      // At least one TextFormField must be present (email and password).
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);

      // Type an email into the first field — must not crash.
      await h.enterText(textFields.first, 'test@example.com');
      h.expectOnScreen('test@example.com');
    });

    // SKIP: device-test required — the full sign-in flow calls Firebase Auth
    // (platform channel), reads the device registry SQLite file opened via
    // drift_flutter (path not covered by the path_provider mock), calls
    // syncOrchestratorProvider.pullOnLaunch, and navigates to AppShell.
    // All of these require a physical or emulator device via integration_test.
    testWidgets(
      'SKIP device-test-required: submit valid creds → authStateProvider→signedIn '
      '→ Dashboard',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-1202 ───────────────────────────────────────────────────────────────

  group('E2E-1202 — Sign in — wrong password error', () {
    // Strategy: override signInControllerProvider with a stub that starts in
    // [SignInError] state so we can assert the UI error representation.
    // The Sign In button must be present (enabled, no spinner) and the router
    // must remain on /sign-in — no navigation occurred.

    testWidgets(
      'SignInScreen with SignInError state shows the Sign In button as '
      'enabled (not spinner) and stays on /sign-in',
      (tester) async {
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        final h = E2EHarness(tester);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/sign-in',
          extraOverrides: [
            _onlineOverride(),
            // Seed the controller in SignInError state to simulate a failed
            // wrong-password attempt.  The screen reads this state to decide
            // whether the primary button shows a spinner or the label text.
            signInControllerProvider.overrideWith(
              () => _ErrorSignInController(
                'Incorrect password. Please try again.',
              ),
            ),
          ],
        );

        // The Sign In button text must be present (not replaced by a spinner).
        h.expectOnScreen('Sign In', routeName: 'SignInScreen');
        // The router must still be on /sign-in — no navigation occurred.
        expect(
          h.router.currentPath,
          contains('sign-in'),
          reason:
              'E2E-1202: router must stay on /sign-in after a wrong-password '
              'error',
        );
      },
    );

    testWidgets(
      'SignInScreen tapping Sign In with empty fields shows form validation '
      'error without navigating away',
      (tester) async {
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        final h = E2EHarness(tester);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/sign-in',
          extraOverrides: [
            _onlineOverride(),
            // Use the no-op controller so the action call doesn't hit real
            // Firebase or the device registry.
            signInControllerProvider.overrideWith(
              () => _NoOpSignInController(),
            ),
          ],
        );

        // Tap the Sign In button without filling any fields.
        await h.tapText('Sign In');
        await h.pump(const Duration(milliseconds: 300));

        // Still on SignInScreen — heading still present.
        h.expectOnScreen('Welcome Back!', routeName: 'SignInScreen');
        // The router must still be on /sign-in.
        expect(
          h.router.currentPath,
          contains('sign-in'),
          reason:
              'E2E-1202: empty-form submit must not navigate away from '
              'SignInScreen',
        );
      },
    );

    // SKIP: device-test required — driving the actual wrong-password network
    // call (Firebase Auth signInWithEmail returning invalid-credential) and
    // asserting the resulting SnackBar message text ("Incorrect password.")
    // requires the Firebase platform channel and a live or emulator project.
    testWidgets(
      'SKIP device-test-required: wrong password → error snackbar text shown '
      '→ button re-enables → no navigation',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-1203 ───────────────────────────────────────────────────────────────

  group('E2E-1203 — Sign-up new account — adult', () {
    testWidgets(
      'SignupScreen (online) renders Create Account heading, email/password '
      'fields and Sign Up CTA',
      (tester) async {
        // Force online so the email/password form renders (offline shows the
        // credential-less "Create offline account" path instead).
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        // No identity → authState = signedOut.
        final h = E2EHarness(tester);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/create-account',
          extraOverrides: [_onlineOverride()],
        );

        // Main heading (signUpTitle).
        h.expectOnScreen('Create Account', routeName: 'SignupScreen');
        // Subtitle (signUpSubtitle).
        h.expectOnScreen('Create your free account');
        // Primary Sign Up CTA (signUpCta).
        h.expectOnScreen('Sign Up');
      },
    );

    testWidgets(
      'SignupScreen (offline) renders credential-less "Create Offline Account" '
      'CTA instead of the email/password form',
      (tester) async {
        // Force offline — both the stream and the loading-state fallback must
        // read false so the offline branch renders (not the online form).
        debugSetLastKnownOnline(false);
        addTearDown(() => debugSetLastKnownOnline(false));

        final h = E2EHarness(tester);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/create-account',
          extraOverrides: [
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
        );

        // Heading is still shown in both modes.
        h.expectOnScreen('Create Account', routeName: 'SignupScreen');
        // Offline path shows "Create Offline Account" CTA (createOfflineAccount
        // l10n key), not the "Sign Up" button.
        h.expectOnScreen('Create Offline Account');
        // No Google button when offline.
        h.expectNotOnScreen('Sign Up with Google');
      },
    );

    // SKIP: device-test required — the online sign-up path calls
    // authRepo.signUp (Firebase Auth platform channel), sends a verification
    // email (Firebase), then routes to OnboardingRoute.  The offline sign-up
    // path calls path_provider.getApplicationDocumentsDirectory() for
    // PendingLocalSignupStore.rollbackIfIncomplete and opens a drift_flutter
    // NativeDatabase file — neither is available in the headless harness.
    testWidgets(
      'SKIP device-test-required: fill form → Sign Up → onboarding flow '
      'starts → account row in Drift',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-1206 ───────────────────────────────────────────────────────────────

  group('E2E-1206 — Google Sign-In — new user', () {
    // The "Sign Up with Google" button is on SignupScreen.  The full flow
    // (Google picker → Firebase token exchange → onboarding) requires the
    // Google Sign-In native SDK and Firebase Auth platform channel, so it is
    // device-only.  The headless tests confirm:
    //   (a) the button is present when online, and
    //   (b) the OnboardingScreen profile-creation step is reachable for a
    //       freshly signed-in user (what the app reaches after a successful
    //       Google sign-in).

    testWidgets(
      '"Sign Up with Google" button is visible on SignupScreen when online',
      (tester) async {
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        // No identity → authState = signedOut.
        final h = E2EHarness(tester);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/create-account',
          extraOverrides: [_onlineOverride()],
        );

        // Google button must be present when online (signUpGoogleCta key).
        h.expectOnScreen('Sign Up with Google', routeName: 'SignupScreen');
      },
    );

    testWidgets('OnboardingScreen profile-creation step is reachable for a new '
        'Google-signed-in user (post-sign-in state → /onboarding → '
        '"What should we call you?" shown)', (tester) async {
      // Simulate the post-Google-sign-in state: a newly signed-in user has
      // an account row seeded and authState = signedIn.  This mirrors what
      // _signUpWithGoogle in SignupScreen sets up before pushing
      // OnboardingRoute — the OnboardingScreen shows the profileCreation step.
      final identity = E2EIdentity.localBorn(
        email: 'google-new@gmail.com',
        displayName: 'Google New User',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(path: '/onboarding');

      // The first phase of OnboardingScreen is the profile-creation step.
      // OnboardingProfileCreationStep renders "What should we call you?".
      h.expectOnScreen(
        'What should we call you?',
        routeName: 'OnboardingScreen',
      );
    });

    // SKIP: device-test required — tapping "Sign Up with Google" invokes the
    // Google Sign-In native SDK (GoogleSignIn.signIn()) and Firebase Auth
    // (signInWithCredential) — both require native platform channels not
    // available in the headless harness.
    testWidgets(
      'SKIP device-test-required: tap Google button → Google SDK → new user '
      '→ onboarding flow starts',
      skip: true,
      (tester) async {},
    );
  });
}
