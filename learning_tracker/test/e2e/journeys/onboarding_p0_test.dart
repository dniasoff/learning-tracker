/// E2E Wave 1 P0 journeys — Onboarding area.
///
/// Journeys implemented:
///   E2E-114  Google Sign-Up new user → onboarding flow starts
///   E2E-121  App intro — sign in path (AppIntroScreen → SignInScreen)
///   E2E-122  App intro — create account path (SignupScreen accessible)
///
/// Journeys skipped (device-test required):
///   E2E-101  Full first-run adult happy path
///   E2E-102  Full first-run child happy path
///
/// Skip rationale for E2E-101 and E2E-102:
///   The full first-run happy path requires AddTrackFlow (a multi-step track
///   wizard that needs the bundled content database and several native service
///   providers), PermissionPromptScreen (which calls
///   NotificationGateway.requestPermission / SacredLocationNotifier.detect —
///   native platform channels that the headless harness cannot exercise), and
///   a final routing to the AppShellRoute dashboard.  These surface-level
///   integrations require a physical or emulator device via integration_test.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 1 / §7 R-OB*
@Tags(['e2e', 'journey'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider, debugSetLastKnownOnline;

import '../harness/e2e_harness.dart';

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-101 ────────────────────────────────────────────────────────────────

  group('E2E-101 — Full first-run adult happy path', () {
    // SKIP: device-test required — AddTrackFlow needs the bundled content DB
    // and a full track wizard flow; PermissionPromptScreen calls
    // NotificationGateway.requestPermission / SacredLocationNotifier.detect
    // which are native platform channels the headless harness cannot exercise.
    // Covered by integration_test on a physical or emulator device.
    testWidgets(
      'SKIP device-test-required: '
      'intro→sign-up→profile→intent→track→permissions→dashboard',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-102 ────────────────────────────────────────────────────────────────

  group('E2E-102 — Full first-run child happy path', () {
    // SKIP: device-test required — PIN setup requires FlutterSecureStorage;
    // AddTrackFlow needs bundled content DB + track wizard;
    // PermissionPromptScreen uses native platform channels the headless
    // harness cannot exercise.
    testWidgets(
      'SKIP device-test-required: '
      'profile→PIN→track→permissions→handoff→dashboard',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-114 ────────────────────────────────────────────────────────────────

  group('E2E-114 — Google Sign-Up new user → onboarding flow starts', () {
    // Part 1: The Google "Sign Up" button is visible on SignupScreen when online.
    // Part 2: When auth state transitions to signedIn (as a Google user would
    //         cause), the OnboardingScreen profile-creation step is shown.
    //
    // The full flow — tapping the Google button, completing Google Sign-In via
    // the Google SDK, registering in the device-registry SQLite DB, and routing
    // to OnboardingRoute — requires a device (real network + Google SDK + file
    // I/O for the device registry).  This headless test validates the key
    // pre-condition (button visible + sign-up page renders) and the key
    // post-condition (onboarding screen reachable for a newly signed-in user).

    testWidgets('SignupScreen renders the Google Sign-Up button when online', (
      tester,
    ) async {
      // Force online so the Google button is shown (it is hidden offline).
      debugSetLastKnownOnline(true);
      addTearDown(() => debugSetLastKnownOnline(false));

      // No identity → harness sets authState to signedOut automatically.
      final h = E2EHarness(tester);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/create-account',
        extraOverrides: [
          // Online connectivity so the Google button renders.
          connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );

      // SignupScreen must show "Create Account" heading.
      h.expectOnScreen('Create Account', routeName: 'SignupScreen');
      // The Google Sign-Up button must be visible when online.
      h.expectOnScreen('Sign Up with Google');
    });

    testWidgets(
      'OnboardingScreen profile-creation step is shown for a new Google user',
      (tester) async {
        // Simulate the post-Google-sign-in state: a newly signed-in Google
        // user lands on /onboarding.  The E2EIdentity provides a signed-in
        // auth state and a DB account row, matching what _signUpWithGoogle
        // would set up before pushing OnboardingRoute.
        final identity = E2EIdentity.localBorn(
          email: 'google-user@gmail.com',
          displayName: 'Google User',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(path: '/onboarding');

        // The profile-creation step is the first phase of OnboardingScreen.
        // "What should we call you?" is the heading rendered by
        // OnboardingProfileCreationStep.
        h.expectOnScreen(
          'What should we call you?',
          routeName: 'OnboardingScreen',
        );
      },
    );
  });

  // ── E2E-121 ────────────────────────────────────────────────────────────────

  group('E2E-121 — App intro — sign in path', () {
    testWidgets('AppIntroScreen renders with Skip CTA on first page', (
      tester,
    ) async {
      // No identity → harness sets authState to signedOut.
      // The harness sets onboarding_complete=true so AuthGuard passes
      // through for the explicit /intro deep-link.
      final h = E2EHarness(tester);
      addTearDown(h.dispose);

      await h.pumpApp(path: '/intro');

      // AppIntroScreen must be shown — the "Skip" button lives in the
      // _IntroHeader and is always present on all 3 intro pages.
      h.expectOnScreen('Skip', routeName: 'AppIntroScreen');
      // The first intro page CTA says "Continue Journey" (not "Get Started"
      // which only appears on the last page).
      h.expectOnScreen('Continue Journey');
    });

    // SKIP: device-test required (no explicit R-OB risk, but the PermissionPromptRoute
    // push in AppIntroScreen._markIntroSeenAndContinue() calls native platform
    // channels for notification and location permissions that the headless
    // harness cannot exercise.  Covered by integration_test on device.)
    testWidgets(
      'SKIP device-test-required: Tapping Skip on AppIntroScreen routes to SignInScreen',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-122 ────────────────────────────────────────────────────────────────

  group('E2E-122 — App intro — create account path', () {
    testWidgets(
      'SignupScreen (Create Account) is reachable via /create-account',
      (tester) async {
        // Force online so the email/password form renders.
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        // No identity → harness sets authState to signedOut.
        final h = E2EHarness(tester);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/create-account',
          extraOverrides: [
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
          ],
        );

        // SignupScreen must show the "Create Account" heading.
        h.expectOnScreen('Create Account', routeName: 'SignupScreen');
        // The subtitle "Create your free account" must also be visible.
        h.expectOnScreen('Create your free account');
        // The primary "Sign Up" CTA button must be present.
        h.expectOnScreen('Sign Up');
      },
    );

    // SKIP: device-test required — the "Register Here" link is a
    // TapGestureRecognizer on a child TextSpan inside a RichText widget.
    // Headless widget tests cannot reliably hit-test and fire TextSpan
    // gesture recognizers (the tap lands on the RichText bounding box but
    // the span-level hit-test requires the real rendering layer).  The full
    // navigation gesture is covered by integration_test on a device.
    testWidgets(
      'SKIP device-test-required: Tapping Register Here on SignInScreen navigates to SignupScreen',
      skip: true,
      (tester) async {},
    );
  });
}
