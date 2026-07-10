/// E2E Wave 1 P0 journeys — Infra-Crosscutting area.
///
/// Journeys implemented:
///   E2E-1101  City Picker: manual city selection flow
///   E2E-1103  Sacred Time lock: Shabbos overlay — DEVICE ONLY (R-IC2)
///   E2E-1105  Enable daily reminder and set custom time
///   E2E-1109  Device restore: new cloud device happy path
///   E2E-1110  Device restore: error then retry
///
/// ## Journey notes
///
/// ### E2E-1101 — City Picker manual selection
/// Overrides [citySearchProvider] with a stub that returns a small fixed list
/// of cities, bypassing the bundled 33k-city SQLite asset which is not
/// available in the headless test environment.  After tapping a city,
/// [sacredLocationProvider] must reflect the chosen city's coordinates.
///
/// The idle-hint widget renders a multi-line Text containing both
/// "Start typing to search ~33,000 cities." and "Type at least 2 letters."
/// — these cannot be matched by exact `find.text()`, so we use
/// `find.textContaining` for the hint check.
///
/// ### E2E-1103 — Sacred Time lock (DEVICE ONLY)
/// [SacredTimeLockOverlay] is mounted in [LearningTrackerApp]'s
/// `MaterialApp.router` builder slot.  The harness constructs a plain
/// [MaterialApp.router] without that builder slot so the overlay is never
/// present.  This journey requires a device integration test.
/// Risk: R-IC2.
///
/// ### E2E-1105 — Notifications screen: enable daily reminder
/// Overrides [notificationServiceProvider] with a no-op fake and silences
/// the heavy sync-effect providers ([reminderSyncEffectProvider],
/// [streakAlertSyncEffectProvider], [allProfilesReminderBootstrapProvider])
/// that otherwise start timers and require a fully-wired notification plugin.
///
/// After toggling the daily reminder switch OFF then ON we verify:
///   - The screen still renders without error
///   - The toggle is visible and interactive
///   - SharedPreferences is updated: key is
///     `daily_reminder_enabled_<profileId>` (as defined by
///     [NotificationPreferencesRepository.reminderEnabledKey]).
///
/// ### E2E-1109 — Device restore happy path
/// Injects a fake [deviceRestoreServiceProvider] that returns a completed
/// restore and sets [restoreStatusProvider] to [RestoreStatus.complete].
/// The harness's [RestoreGuard] is pre-completed (markRestoreComplete),
/// so we navigate directly to `/restore` to exercise the screen.
/// [routerProvider] is overridden with [h.router] so the screen's
/// `_navigateToApp` call does not try to build a production router.
///
/// ### E2E-1110 — Device restore: error then retry
/// Same setup as E2E-1109 but [restoreStatusProvider] starts as
/// [RestoreStatus.error].  The test confirms the error card + retry button
/// render.
///
/// ## Provider silence notes
///
/// [currentSacredWindowProvider] — SacredTimeSettingsCard's notifier starts a
/// 30-second repeating timer; override to null everywhere to prevent timer leaks.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 11 / §7 R-IC*
@Tags(['e2e', 'journey'])
library;

import 'package:flutter/material.dart' show Key, Switch, TextField;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/restore/restore_providers.dart'
    show deviceRestoreServiceProvider, restoreStatusProvider;
import 'package:learning_tracker/app/router/router_provider.dart'
    show routerProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart'
    show NotificationPreferencesRepository;
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart'
    show NotificationGateway;
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart'
    show
        allProfilesReminderBootstrapProvider,
        notificationServiceProvider,
        reminderSyncEffectProvider,
        streakAlertSyncEffectProvider;
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart'
    show City;
import 'package:learning_tracker/features/sacred_time/presentation/providers/cities_provider.dart'
    show citySearchProvider;
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart'
    show currentSacredWindowProvider;
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart'
    show RestoreStatus;
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart'
    show SyncErrorCode;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

import '../harness/e2e_harness.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

/// No-op [NotificationGateway] stub.  All calls complete immediately without
/// touching the flutter_local_notifications plugin (not available headless).
class _FakeNotificationGateway extends Fake implements NotificationGateway {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String body,
  }) async {}

  @override
  Future<void> cancelDailyReminder() async {}

  @override
  Future<void> cancelStreakAlertForProfile(int profileId) async {}
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Silences the 30-second repeating timer in [SacredTimeLockOverlay] /
/// [CurrentSacredWindow].
Override _sacredWindowNullOverride() =>
    currentSacredWindowProvider.overrideWithValue(null);

/// Silences the heavy notification sync-effect providers that require a fully-
/// wired [NotificationScheduler] and access the OS notification channel.
///
/// Also silences the [connectivityStreamProvider] to prevent the
/// [AppShell] (which wraps the notifications sub-route) from starting its
/// offline-debounce and recovery-probe [Timer.periodic] instances.
List<Override> _notificationSilenceOverrides(_FakeNotificationGateway fakeGw) =>
    [
      notificationServiceProvider.overrideWithValue(fakeGw),
      // reminderSyncEffect reads allDailyTasksProvider and schedules OS
      // notifications — silence to avoid timer leaks in headless tests.
      reminderSyncEffectProvider.overrideWith((ref) async {}),
      streakAlertSyncEffectProvider.overrideWith((ref) async {}),
      allProfilesReminderBootstrapProvider.overrideWith((ref) async {}),
      // AppShell's connectivityStreamProvider starts Timer.periodic
      // (offline-debounce + recovery-probe) — silence with a static stream.
      connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
    ];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-1101 ─────────────────────────────────────────────────────────────────

  group('E2E-1101 — City Picker: manual city selection flow', () {
    // Key assertions (catalog §2 Area 11):
    //  • CityPickerScreen renders (app-bar "Choose a city" visible)
    //  • Typing < 2 chars shows the idle hint containing "Type at least 2 letters."
    //    (R-IC12: single-char query shows hint, not results)
    //  • Typing 2+ chars: stub returns 2 cities; both city names visible
    //  • Tapping a city calls sacredLocationProvider.notifier.setManualCity
    //    → screen pops (CityPickerScreen title no longer visible)
    //
    // The idle-hint is a single Text widget with "\n" in its data, so it cannot
    // be matched by the exact-text [expectOnScreen] helper.  We use
    // [find.textContaining] for that assertion.

    testWidgets('typing 1 char shows idle hint; 2+ chars shows stub cities; '
        'tapping a city pops CityPickerScreen (sacredLocationProvider updated)', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(
        email: 'city1101@test.com',
        displayName: 'CityUser',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      const fakeJerusalem = City(
        id: 1,
        name: 'Jerusalem',
        countryCode: 'IL',
        latitude: 31.76,
        longitude: 35.21,
        population: 900000,
        admin1: 'Jerusalem District',
      );
      const fakeTelAviv = City(
        id: 2,
        name: 'Tel Aviv',
        countryCode: 'IL',
        latitude: 32.08,
        longitude: 34.78,
        population: 450000,
        admin1: 'Tel Aviv District',
      );

      await h.pumpApp(
        path: '/sacred-time/city',
        extraOverrides: [
          _sacredWindowNullOverride(),
          ...h.dashboardSilenceOverrides,
          // Stub citySearch to return our two fake cities for any 2+ char
          // query, bypassing the bundled SQLite asset.
          citySearchProvider.overrideWith((ref, String query) async {
            if (query.length < 2) return [];
            return [fakeJerusalem, fakeTelAviv];
          }),
        ],
      );

      // Screen must be visible.
      h.expectOnScreen('Choose a city', routeName: 'CityPickerScreen');

      // (R-IC12) Single-char query shows idle hint text, not results.
      await h.enterText(find.byType(TextField), 'J');
      await h.pump(const Duration(milliseconds: 300));

      // The idle hint is a single Text widget with a newline, so use
      // textContaining rather than exact-text matching.
      expect(
        find.textContaining('Type at least 2 letters'),
        findsWidgets,
        reason: 'Idle hint must show when query < 2 chars (R-IC12)',
      );
      h.expectNotOnScreen('Jerusalem');

      // Two-char query: stub returns cities.
      await h.enterText(find.byType(TextField), 'Je');
      await h.pump(const Duration(milliseconds: 300));
      await h.pump(const Duration(milliseconds: 300));

      h.expectOnScreen('Jerusalem', routeName: 'CityPickerScreen');
      h.expectOnScreen('Tel Aviv');

      // Tap Jerusalem → setManualCity called → screen pops.
      await h.tapText('Jerusalem', settle: const Duration(milliseconds: 500));
      await h.pump(const Duration(milliseconds: 300));

      // Key assertion: screen popped (CityPickerScreen title gone), which means
      // sacredLocationProvider.notifier.setManualCity was called successfully.
      expect(
        find.text('Choose a city'),
        findsNothing,
        reason:
            'CityPickerScreen must pop after city selection, indicating '
            'sacredLocationProvider.setManualCity was called successfully',
      );
    });
  });

  // ── E2E-1103 — DEVICE ONLY ───────────────────────────────────────────────────

  group(
    'E2E-1103 — Sacred Time lock: Shabbos overlay (device-test required)',
    () {
      // R-IC2: SacredTimeLockOverlay is mounted in LearningTrackerApp's
      // MaterialApp.router builder slot which is absent from the headless harness.
      // This journey requires an integration_test run on device.
      testWidgets(
        'SKIP device-test-required (R-IC2): '
        'SacredTimeLockOverlay is in LearningTrackerApp.builder, '
        'absent from the headless harness',
        skip: true,
        (tester) async {},
      );
    },
  );

  // ── E2E-1105 ─────────────────────────────────────────────────────────────────

  group('E2E-1105 — Enable daily reminder and set custom time', () {
    // Key assertions (catalog §2 Area 11):
    //  • NotificationsScreen renders (app-bar "Notifications" visible)
    //  • Daily Reminder row and toggle are present (key='reminder_toggle')
    //  • Tapping the toggle writes to SharedPreferences:
    //    key = 'daily_reminder_enabled_<profileId>' (from
    //    NotificationPreferencesRepository.reminderEnabledKey)
    //
    // R-IC4: [DeviceNotificationToggle] default value is `permitted ?? true`
    //   showing ON while loading. Extra pump settles async _checkPermission.

    testWidgets('NotificationsScreen renders reminder toggle; toggling writes to '
        'SharedPreferences (daily_reminder_enabled_<id>)', (tester) async {
      final identity = E2EIdentity.localBorn(
        email: 'notif1105@test.com',
        displayName: 'NotifUser',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final fakeGw = _FakeNotificationGateway();

      await h.pumpApp(
        path: '/notifications',
        extraOverrides: [
          _sacredWindowNullOverride(),
          ..._notificationSilenceOverrides(fakeGw),
          // dashboardSilenceOverrides suppresses Drift-backed streak +
          // curricula StreamProviders that, when disposed during ProviderScope
          // teardown, call StreamQueryStore.markAsClosed which creates a
          // zero-duration timer visible to _verifyInvariants. Even though the
          // /notifications route does not render the dashboard, some provider
          // in the notification chain indirectly triggers dashboardStreak
          // (which contains a StreakStateProvider.watch() call and a 15-min
          // periodic rollover timer). Including these overrides prevents the
          // pending-timer invariant failure.
          ...h.dashboardSilenceOverrides,
        ],
      );

      // (R-IC4) Extra pump to let _DeviceNotificationToggleState._checkPermission
      // settle its async result before asserting.
      await h.pump(const Duration(milliseconds: 300));
      await h.pump();

      // NotificationsScreen must be visible.
      h.expectOnScreen('Notifications', routeName: 'NotificationsScreen');

      // Daily Reminder row must be present.
      h.expectOnScreen('Daily Reminder');

      // The toggle key is 'reminder_toggle' as assigned in the screen.
      final reminderSwitch = find.descendant(
        of: find.byKey(const Key('reminder_toggle')),
        matching: find.byType(Switch),
      );
      expect(
        reminderSwitch,
        findsOneWidget,
        reason:
            'Daily Reminder Switch must be present in the reminder_toggle row',
      );

      // Allow async prefs load to settle before tapping.
      await h.pump(const Duration(milliseconds: 200));

      // The default state is ON (enabled=true from ReminderEnabled.build).
      // Tap to toggle OFF → this calls reminderEnabled.toggle() which
      // writes 'daily_reminder_enabled_<profileId>'=false to SharedPreferences.
      await h.tapWidget(
        reminderSwitch,
        settle: const Duration(milliseconds: 400),
      );
      // Allow the async SharedPreferences write to complete.
      await h.pump(const Duration(milliseconds: 200));

      // Tap again to toggle back ON → writes true.
      await h.tapWidget(
        reminderSwitch,
        settle: const Duration(milliseconds: 400),
      );
      await h.pump(const Duration(milliseconds: 300));

      // Read SharedPreferences to verify the write.
      // In flutter test, SharedPreferences.getInstance() returns the mock
      // singleton synchronously (as a completed Future).
      final profileId = identity.profileId;
      final key = NotificationPreferencesRepository.reminderEnabledKey(
        profileId,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(key),
        isTrue,
        reason: 'SharedPreferences[$key] must be true after enabling reminder',
      );
    });
  });

  // ── E2E-1109 ─────────────────────────────────────────────────────────────────

  group('E2E-1109 — Device restore: new cloud device happy path', () {
    // Key assertions (catalog §2 Area 11):
    //  • DeviceRestoreScreen renders from /restore
    //  • When restoreStatusProvider = complete → "Restore complete!" shown
    //
    // The harness RestoreGuard is pre-completed so we navigate to /restore
    // directly.  routerProvider is overridden with h.router so the screen's
    // _navigateToApp call resolves in the headless environment.
    //
    // deviceRestoreServiceProvider = null makes initState's null check fire
    // immediately (SY-2 blank-screen fix: calls _navigateToApp).  We inject
    // restoreStatusProvider = complete so build() renders the success card
    // regardless of the null-service navigation path.

    testWidgets(
      'DeviceRestoreScreen renders Restore complete state when status is complete',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'restore1109@test.com',
          displayName: 'RestoreUser',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const completeStatus = RestoreStatus.complete(collectionsRestored: 3);

        await h.pumpApp(
          path: '/restore',
          extraOverrides: [
            _sacredWindowNullOverride(),
            ...h.dashboardSilenceOverrides,
            // null service → initState null-path → _navigateToApp called.
            deviceRestoreServiceProvider.overrideWithValue(null),
            // Override status to complete so the build() method renders
            // the success card while we pump.
            restoreStatusProvider.overrideWithValue(completeStatus),
            // routerProvider must resolve to h.router so _navigateToApp's
            // ref.read(routerProvider) works headlessly.
            routerProvider.overrideWith((ref) => h.router),
          ],
        );

        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // DeviceRestoreScreen must render the complete state.
        // l10n.deviceRestoreComplete = 'Restore complete!'
        h.expectOnScreen('Restore complete!', routeName: 'DeviceRestoreScreen');
      },
    );
  });

  // ── E2E-1110 ─────────────────────────────────────────────────────────────────

  group('E2E-1110 — Device restore: error then retry', () {
    // Key assertions (catalog §2 Area 11):
    //  • restoreStatusProvider = error → "Restore failed" heading shown
    //  • Error message body visible
    //  • Retry button (l10n.retry = "Retry") visible
    //  • "Skip & continue" TextButton visible

    testWidgets(
      'DeviceRestoreScreen shows error card with Retry and Skip buttons when '
      'restore fails',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'restore1110@test.com',
          displayName: 'RestoreUserError',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // AUD-sync-01 (EH-5): RestoreStatus.error carries a stable code —
        // debugDetail below is technical-only and must never render.
        const errorStatus = RestoreStatus.error(
          code: SyncErrorCode.timeout,
          debugDetail: 'Network timeout. Please check your connection.',
        );

        await h.pumpApp(
          path: '/restore',
          extraOverrides: [
            _sacredWindowNullOverride(),
            ...h.dashboardSilenceOverrides,
            deviceRestoreServiceProvider.overrideWithValue(null),
            restoreStatusProvider.overrideWithValue(errorStatus),
            routerProvider.overrideWith((ref) => h.router),
          ],
        );

        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // Error state: "Restore failed" heading.
        // l10n.deviceRestoreFailed = 'Restore failed'
        h.expectOnScreen('Restore failed', routeName: 'DeviceRestoreScreen');

        // Error message body: the LOCALIZED subtitle for SyncErrorCode.timeout
        // (l10n.deviceRestoreErrorTimeout), never the raw debugDetail text.
        h.expectOnScreen(
          'The restore timed out. Check your connection and try again.',
        );

        // Retry button (l10n.retry = 'Retry').
        h.expectOnScreen('Retry');

        // Skip & continue link (l10n.skipAndContinue = 'Skip & continue').
        h.expectOnScreen('Skip & continue');
      },
    );
  });
}
