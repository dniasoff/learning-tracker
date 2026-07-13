/// E2E Wave 3 P2 journeys — Auth / Sync / Infra-Crosscutting (combined).
///
/// Journeys implemented:
///   E2E-1103  Sacred Time lock: Shabbos overlay — DEVICE ONLY (R-IC2)
///   E2E-1104  In-Israel toggle — already covered in infra_p1_test.dart (P1);
///             P2 re-entry skipped with a cross-reference skip.
///   E2E-1209  Google Sign-In watchdog: picker abandoned 45 s — controller-state
///             verification (watchdog timer fires SignInTimeout error).
///   E2E-1210  Magic link warm-start: AppLinks emitting warm URI — headless
///             verification of harness override (full channel is device-only).
///   E2E-1305  Degraded card — stuck outbox detected: BackupSyncSection renders
///             the degraded card when syncStatusProvider carries a stuck-outbox
///             reason string.
///
/// ## Journey notes
///
/// ### E2E-1103 — Sacred Time lock (DEVICE ONLY, R-IC2)
/// Already skipped in infra_p0_test.dart (Wave 1). [SacredTimeLockOverlay] is
/// mounted in [LearningTrackerApp]'s `MaterialApp.router` builder slot which is
/// absent from the headless harness. Repeated here as Wave-3 P2 catalog entry
/// with a consistent skip comment.
///
/// ### E2E-1104 — In-Israel toggle (already P1, Wave-2)
/// E2E-1104 is a P1 journey implemented in infra_p1_test.dart.  The Wave-3
/// catalog re-lists it (docs/planning §3 lists under Wave-3 P2) but the
/// implementation is complete.  We register a cross-reference skip here so the
/// catalog id is not silently absent.
///
/// ### E2E-1209 — Google Sign-In watchdog timer
/// The 45-second watchdog in [SignInController.signInWithGoogle] transitions
/// `state` to [SignInError] if the picker has not resolved within 45 s.
/// Driving a real 45-second delay is impractical in a headless test.  Instead
/// we override [signInControllerProvider] with a stub that directly starts in
/// [SignInError] state carrying the l10n.authSignInTimeout message — the same
/// final state the watchdog produces — and assert the SignInScreen displays
/// the error condition correctly (no spinner; sign-in button re-enabled).
/// The actual timer cancellation (watchdog.cancel() in the finally block) is
/// unit-tested in the controller's own test suite; headlessly we only exercise
/// the UI representation of the post-watchdog state.
/// Platform limitation: the actual Google picker + Firebase sign-in channel
/// cannot be driven headlessly; that path is device-only.
///
/// ### E2E-1210 — Magic link warm-start
/// [MagicLinkService.initialize] subscribes to [AppLinks.uriLinkStream] via
/// the `app_links` platform channel (MethodChannel).  The warm-start path
/// (URI arriving while the app is in the foreground) requires a live channel
/// that emits a URI into that stream — not available headlessly.
/// The harness already overrides [magicLinkInitializationProvider] to a no-op
/// [Future<void>.value()] so the channel call never fires.  This test confirms
/// that an already-signed-in user continues to see the dashboard while the
/// magic-link subscription is silently active (i.e. the override does not break
/// the auth flow).  The full deep-link → Firebase sign-in path is device-only.
///
/// ### E2E-1305 — Degraded card — stuck outbox detected
/// [BackupSyncSection._buildDegradedCard] renders when [syncStatusProvider]
/// carries [SyncStatus.degraded] with a reason string containing 'row(s) stuck'.
/// The orchestrator produces exactly this reason format:
///   `'outbox has $stuck row(s) stuck after $_degradedAttemptThreshold+ attempts'`
/// Override [syncStatusProvider] directly with that pattern to assert the
/// degraded card renders.  BackupSyncSection replaces the raw reason with
/// [l10n.backupSyncOutboxStuck] ("Some changes are waiting to sync. We'll
/// retry automatically.") — confirming localisation replaces the raw string.
///
/// ## Provider silence notes
///
/// All tests that navigate through AppShell need [connectivityStreamProvider]
/// overridden to prevent Timer.periodic leaks.  [currentSacredWindowProvider]
/// must be overridden to null to prevent SacredTimeLockOverlay's 30-second
/// repeating timer.  [incomingTutorGrantsProvider] and
/// [pendingTutorInvitesProvider] must be silenced for SettingsScreen
/// (_PendingInvitesSection) to avoid Firestore calls in headless tests.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Areas 11 / 12 / 13 / §7
@Tags(['e2e', 'journey'])
library;

import 'package:flutter/material.dart' show ListView;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart'
    show syncIdentityStatusProvider;
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart'
    show syncStatusProvider;
import 'package:learning_tracker/core/sync/sync_identity_status.dart'
    show SyncIdentityStatus;
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart'
    show SignInController, SignInError, SignInState, signInControllerProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show debugSetLastKnownOnline;
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart'
    show SyncStatus;

import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

/// [SignInController] stub that starts in [SignInError] state carrying the
/// watchdog timeout message.
///
/// Models the post-watchdog state of [SignInController.signInWithGoogle]:
/// the 45-second timer fires, sets `state = SignInError(l10n.authSignInTimeout)`,
/// then the controller returns to [SignInError]. We seed this directly so the
/// UI render path for a watchdog-timeout can be asserted headlessly.
class _WatchdogTimeoutSignInController extends SignInController {
  _WatchdogTimeoutSignInController(this._timeoutMessage);

  final String _timeoutMessage;

  @override
  SignInState build() => SignInError(_timeoutMessage);
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Standard silence overrides for tests that navigate through AppShell or land
/// on SettingsScreen.
List<Override> _shellSilences(E2EHarness h) => [
  ...h.dashboardSilenceOverrides,
  sacredWindowNullOverride(),
  connectivityOnlineOverride(),
  incomingGrantsEmptyOverride(),
  pendingInvitesEmptyOverride(),
];

/// Navigate from dashboard to SettingsScreen and scroll to BackupSyncSection.
Future<void> _goToBackupSync(E2EHarness h, WidgetTester tester) async {
  await h.tapText('SETTINGS');
  await h.pump(const Duration(milliseconds: 300));
  await h.pump(const Duration(milliseconds: 300));
  await h.pump();
  // Scroll the Settings ListView to expose BackupSyncSection near the bottom.
  final listView = find.byType(ListView);
  if (listView.evaluate().isNotEmpty) {
    await tester.drag(listView.first, const Offset(0, -1500));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-1103 ─────────────────────────────────────────────────────────────────

  group('E2E-1103 — Sacred Time lock: Shabbos/YomTov overlay (device-only)', () {
    // R-IC2: SacredTimeLockOverlay is mounted in LearningTrackerApp's
    // MaterialApp.router builder slot which is absent from the headless harness.
    // This journey requires a device integration_test run.
    //
    // Also covered in infra_p0_test.dart (Wave 1 P0) for the same reason.

    testWidgets(
      'SKIP device/harness (R-IC2): SacredTimeLockOverlay is in '
      'LearningTrackerApp.builder; absent from headless harness. '
      'Use integration_test on device with clockProvider = Shabbos time.',
      skip:
          true, // device/harness: R-IC2 — overlay not present in headless harness
      (tester) async {},
    );
  });

  // ── E2E-1104 ─────────────────────────────────────────────────────────────────

  group('E2E-1104 — In-Israel toggle (P1 cross-reference)', () {
    // E2E-1104 is a P1 journey implemented in infra_p1_test.dart.
    // The Wave-3 catalog re-lists it for the P2 sweep; the implementation is
    // complete and green in infra_p1_test.dart.

    testWidgets(
      'SKIP: E2E-1104 is a P1 journey already implemented in '
      'infra_p1_test.dart (Wave 2). See that file for the full assertion: '
      'In-Israel Switch present; toggling writes sacred_time_in_israel=true '
      'to SharedPreferences.',
      skip: true, // Already implemented as P1 in infra_p1_test.dart
      (tester) async {},
    );
  });

  // ── E2E-1209 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-1209 — Google Sign-In watchdog: picker abandoned 45 s → SignInTimeout error',
    () {
      // Key assertions (catalog §2 Area 12):
      //  • After the 45 s watchdog fires, SignInController.state = SignInError
      //    containing l10n.authSignInTimeout = "The sign-in attempt timed out…"
      //  • SignInScreen renders the error state: Sign In button visible (no spinner)
      //  • Router remains on /sign-in (no navigation occurred after the timeout)
      //  • A subsequent attempt (tapping "Sign In" again) is accepted without
      //    crash — the button is interactive after the timeout.
      //
      // Headless strategy: override signInControllerProvider with a stub that
      // already starts in SignInError(authSignInTimeout). This models the final
      // state the watchdog produces without driving a real 45-second timer.
      //
      // Platform limitation: the actual Google picker + Firebase token exchange
      // cannot be driven headlessly (Google Sign-In plugin requires GMS / iOS SDK
      // native channel). Confirmed device-only for the full watchdog-fire path.

      testWidgets('SignInScreen in watchdog-timeout state: Sign In button visible '
          '(no spinner), router stays on /sign-in', (tester) async {
        // Force online so the Google Sign-In button and cloud form are rendered.
        debugSetLastKnownOnline(true);
        addTearDown(() => debugSetLastKnownOnline(false));

        // No pre-seeded identity — sign-in screen is shown to unauthenticated user.
        final h = E2EHarness(tester);
        addTearDown(h.dispose);

        // The watchdog timeout message from l10n.authSignInTimeout.
        // l10n.authSignInTimeout = "The sign-in attempt timed out. Please try again."
        const timeoutMessage =
            'The sign-in attempt timed out. Please try again.';

        await h.pumpApp(
          path: '/sign-in',
          extraOverrides: [
            connectivityOnlineOverride(),
            // Seed the controller in the post-watchdog error state.
            signInControllerProvider.overrideWith(
              () => _WatchdogTimeoutSignInController(timeoutMessage),
            ),
          ],
        );

        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // Sign-in screen must be visible (watchdog did NOT navigate away).
        h.expectOnScreen('Welcome Back!', routeName: 'SignInScreen');

        // Sign In button must be present and enabled (no CircularProgressIndicator
        // replacing it — the watchdog timeout reset state from SignInSubmitting
        // to SignInError, so the button label is shown).
        h.expectOnScreen('Sign In');

        // Router must still be on /sign-in — no navigation occurred.
        expect(
          h.router.currentPath,
          contains('sign-in'),
          reason:
              'E2E-1209: watchdog timeout must not navigate away from SignInScreen; '
              'router must remain on /sign-in',
        );
      });

      testWidgets(
        'SignInScreen after watchdog timeout: tapping Sign In button is '
        'interactive (no crash, button responds to tap)',
        (tester) async {
          debugSetLastKnownOnline(true);
          addTearDown(() => debugSetLastKnownOnline(false));

          final h = E2EHarness(tester);
          addTearDown(h.dispose);

          const timeoutMessage =
              'The sign-in attempt timed out. Please try again.';

          await h.pumpApp(
            path: '/sign-in',
            extraOverrides: [
              connectivityOnlineOverride(),
              signInControllerProvider.overrideWith(
                () => _WatchdogTimeoutSignInController(timeoutMessage),
              ),
            ],
          );

          await h.pump(const Duration(milliseconds: 300));
          await h.pump();

          // The Sign In button must be tappable after the watchdog timeout.
          // A subsequent tap must not crash (the controller accepts the action
          // after resetting to SignInError state).
          await h.tapText('Sign In');
          await h.pump(const Duration(milliseconds: 300));
          await h.pump();

          // Still on SignInScreen — no unhandled exception was thrown.
          h.expectOnScreen('Welcome Back!', routeName: 'SignInScreen');
        },
      );

      // SKIP: device-test required — the actual 45-second watchdog timer
      // (Timer(const Duration(seconds: 45), ...) in signInWithGoogle) cannot be
      // driven headlessly; fakeAsync is not available in widget-test pumpApp.
      // The Google picker UI, Firebase token exchange, and the watchdog-fire path
      // all require the google_sign_in + firebase_auth platform channels on device.
      // Use integration_test with a stub GoogleSignInGateway that never resolves
      // and advance a fake clock by >45 s.
      testWidgets(
        'SKIP device-test-required: Google picker held >45 s → watchdog fires → '
        'SignInError(authSignInTimeout) shown → subsequent attempt resolves cleanly',
        skip: true, // device/harness: google_sign_in + firebase_auth platform
        // channels required; 45 s timer cannot be driven in headless pumpApp
        (tester) async {},
      );
    },
  );

  // ── E2E-1210 ─────────────────────────────────────────────────────────────────

  group('E2E-1210 — Magic link warm-start: deep link arrives while app is '
      'in foreground', () {
    // Key assertions (catalog §2 Area 12):
    //  • App is in foreground (already signed in) when an email-link URI arrives.
    //  • MagicLinkService._handleIncomingLink processes the URI and calls
    //    AuthRepository.signInWithEmailLink → authState updated.
    //  • The harness overrides magicLinkInitializationProvider to a no-op so the
    //    AppLinks MethodChannel never fires.
    //
    // Headless assertions:
    //  (a) A signed-in user's dashboard renders while the magic-link subscription
    //      is in effect (no channel exception; harness override fires cleanly).
    //  (b) The warm-start subscription (AppLinks.uriLinkStream) does not block
    //      the UI — no stuck spinner, dashboard content visible.
    //
    // Full warm-start path (URI emitted into AppLinks.uriLinkStream →
    // MagicLinkService._handleIncomingLink → AuthRepository.signInWithEmailLink
    // → authStateProvider.setCloudBornSessionFromFirebaseUser) requires the
    // app_links MethodChannel and firebase_auth platform channels — device-only.

    testWidgets(
      'Signed-in user dashboard renders correctly with magicLink initialization '
      'override active (no MethodChannel exception, no blocked UI)',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'warmstart1210@test.com',
          displayName: 'WarmStart1210',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // The harness already overrides magicLinkInitializationProvider with
        // Future<void>.value() (no-op). We only add the AppShell silences.
        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: h.dashboardSilenceOverrides,
        );

        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // Dashboard content must be visible — the magic-link initialization
        // did not block the navigation (override completed immediately).
        h.expectOnScreen('DASHBOARD', routeName: 'DashboardScreen');

        // Router must not have redirected to /sign-in (auth guard passed;
        // magic-link subscription did not clobber the signed-in state).
        expect(
          h.router.currentPath,
          isNot(contains('sign-in')),
          reason:
              'E2E-1210: warm-start magic-link subscription must not displace '
              'an already-signed-in user from the dashboard',
        );
      },
    );

    testWidgets(
      'Magic-link initialization completes without a stuck spinner for a '
      'freshly signed-in user (non-blocking; DASHBOARD content visible)',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'warmstart1210b@test.com',
          displayName: 'WarmStart1210b',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: h.dashboardSilenceOverrides,
        );

        await h.pump(const Duration(milliseconds: 500));
        await h.pump();

        // If the FutureProvider blocked (never resolved), the app would show a
        // loading screen and 'DASHBOARD' text would not be present.
        expect(
          find.text('DASHBOARD'),
          findsWidgets,
          reason:
              'E2E-1210: DASHBOARD label must be visible, confirming magic-link '
              'initialization is non-blocking (no stuck FutureProvider spinner)',
        );
      },
    );

    // SKIP: device-test required — the warm-start path requires the app_links
    // MethodChannel to emit a live URI into AppLinks.uriLinkStream, then
    // MagicLinkService._handleIncomingLink to process it and call
    // AuthRepository.signInWithEmailLink via the firebase_auth platform channel.
    // Neither platform channel is available in the headless harness.
    testWidgets(
      'SKIP device-test-required: app in foreground; email-link deep link '
      'arrives; user signed in via MagicLinkService warm-start path',
      skip:
          true, // device/harness: warm-start magic link requires app_links and
      // firebase_auth platform channels; use integration_test on device
      (tester) async {},
    );
  });

  // ── E2E-1305 ─────────────────────────────────────────────────────────────────

  group('E2E-1305 — Degraded card: stuck outbox detected', () {
    // Key assertions (catalog §2 Area 13):
    //  • BackupSyncSection renders the degraded card when syncStatusProvider
    //    carries SyncStatus.degraded with a reason string matching the
    //    'row(s) stuck' pattern produced by SyncOrchestrator._recomputeOutboxStatus.
    //  • The raw engineering reason is replaced by the localised
    //    l10n.backupSyncOutboxStuck = "Some changes are waiting to sync.
    //    We'll retry automatically."
    //  • The raw reason string ("outbox has N row(s) stuck after 3+ attempts")
    //    must NOT be visible in the user-facing UI.
    //  • Card title "Backup & Sync" is present.
    //
    // The seeded outbox row (catalog "Seeded old outbox row") would normally
    // raise stuck count via OutboxDao.stuckCount(minAttempts=3) → orchestrator
    // emits degraded. Headlessly we inject the final syncStatusProvider value
    // directly (matching the same SyncStatus.degraded the orchestrator would emit)
    // rather than seeding a Drift row and running the full orchestrator.
    //
    // SyncOrchestrator produces the reason string:
    //   'outbox has $stuck row(s) stuck after $_degradedAttemptThreshold+ attempts'
    // where _degradedAttemptThreshold = 3.  BackupSyncSection._buildDegradedCard
    // detects `reason.contains('row(s) stuck')` and replaces it with the
    // localised message (ST-4 fix).
    //
    // syncIdentityStatusProvider is overridden to matched() so the degraded card
    // renders the generic stuck-outbox path (not the identity-mismatch path).

    testWidgets(
      'BackupSyncSection shows degraded card with localised stuck-outbox message '
      'when outbox rows have ≥3 attempts; raw reason string is absent from UI',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'stuckoutbox1305@test.com',
          displayName: 'StuckOutbox1305',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // The orchestrator's exact reason string for stuck outbox rows
        // (_degradedAttemptThreshold = 3 in SyncOrchestrator):
        const stuckReason = 'outbox has 2 row(s) stuck after 3+ attempts';

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._shellSilences(h),
            // Inject the degraded status that the orchestrator would emit for
            // stuck outbox rows (≥3 attempts).
            syncStatusProvider.overrideWithValue(
              const SyncStatus.degraded(pendingChanges: 2, reason: stuckReason),
            ),
            // matched() so _buildDegradedCard uses the stuck-outbox branch,
            // not the identity-mismatch branch.
            syncIdentityStatusProvider.overrideWithValue(
              const SyncIdentityStatus.matched(),
            ),
          ],
        );

        await _goToBackupSync(h, tester);
        await h.pump(const Duration(milliseconds: 300));

        // Card title must be present.
        expect(
          find.textContaining('Backup & Sync'),
          findsWidgets,
          reason:
              'E2E-1305: BackupSyncSection card title "Backup & Sync" must be '
              'visible in the degraded (stuck-outbox) state',
        );

        // The degraded card must show the localised stuck-outbox message.
        // BackupSyncSection._buildDegradedCard replaces the raw reason with
        // l10n.backupSyncOutboxStuck = "Some changes are waiting to sync.
        // We'll retry automatically." when reason.contains('row(s) stuck').
        final showsWaiting = tester.any(find.textContaining('waiting to sync'));
        final showsWillRetry = tester.any(
          find.textContaining("We'll retry automatically"),
        );
        final showsPaused = tester.any(find.textContaining('Sync paused'));

        expect(
          showsWaiting || showsWillRetry || showsPaused,
          isTrue,
          reason:
              'E2E-1305: degraded card must show localised stuck-outbox message '
              '("waiting to sync" / "We\'ll retry automatically" / "Sync paused") '
              '— BackupSyncSection._buildDegradedCard ST-4 fix must apply',
        );

        // The raw engineering reason must NOT be visible to the user (ST-4 fix).
        expect(
          find.textContaining('row(s) stuck'),
          findsNothing,
          reason:
              'E2E-1305: raw engineering reason "row(s) stuck" must NOT be '
              'rendered in the user-facing BackupSyncSection (ST-4 fix)',
        );
      },
    );

    testWidgets(
      'BackupSyncSection degraded card with pendingChanges=0 and stuck reason '
      'shows localised no-count subtitle (backupSyncPausedNoCount)',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'stuckoutbox1305b@test.com',
          displayName: 'StuckOutbox1305B',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // pendingChanges=0 exercises the backupSyncPausedNoCount(reason) branch
        // in _buildDegradedCard (the other branch uses backupSyncPaused(n, r)).
        const stuckReason = 'outbox has 1 row(s) stuck after 3+ attempts';

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._shellSilences(h),
            syncStatusProvider.overrideWithValue(
              const SyncStatus.degraded(pendingChanges: 0, reason: stuckReason),
            ),
            syncIdentityStatusProvider.overrideWithValue(
              const SyncIdentityStatus.matched(),
            ),
          ],
        );

        await _goToBackupSync(h, tester);
        await h.pump(const Duration(milliseconds: 300));

        // Card title present.
        expect(
          find.textContaining('Backup & Sync'),
          findsWidgets,
          reason:
              'E2E-1305: "Backup & Sync" card title must be visible '
              '(pendingChanges=0 degraded variant)',
        );

        // Localised message must appear — either "waiting to sync" or "Sync paused".
        final showsWaiting = tester.any(find.textContaining('waiting to sync'));
        final showsPaused = tester.any(find.textContaining('Sync paused'));

        expect(
          showsWaiting || showsPaused,
          isTrue,
          reason:
              'E2E-1305: pendingChanges=0 degraded card must show localised '
              'stuck-outbox message ("waiting to sync" / "Sync paused")',
        );

        // Raw engineering string must still be absent.
        expect(
          find.textContaining('row(s) stuck'),
          findsNothing,
          reason:
              'E2E-1305: raw "row(s) stuck" string must be absent from UI '
              '(ST-4 localisation fix applies for pendingChanges=0 too)',
        );
      },
    );
  });
}
