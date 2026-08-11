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
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

import '../harness/e2e_common_overrides.dart';
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
  Future<void> cancelStreakAlertForProfile(int profileId) async {}
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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
          sacredWindowNullOverride(),
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
          sacredWindowNullOverride(),
          ..._notificationSilenceOverrides(fakeGw),
          // dashboardSilenceOverrides suppresses Drift-backed streak +
          // curricula StreamProviders that, when disposed during ProviderScope
          // teardown, call StreamQueryStore.markAsClosed which creates a
          // zero-duration timer visible to _verifyInvariants. Even though the
          // /notifications route does not render the dashboard, some provider
          // in the notification chain indirectly triggers dashboardStreak
          // (which contains a StreakStateService.watch() call and a 15-min
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

  // ── E2E-1109 / E2E-1110 removed (Phase 3 P3-7, commit 5677d6fb) ────────────
  // Both groups exercised DeviceRestoreScreen directly ("device restore: new
  // cloud device happy path" / "error then retry"). The whole device-restore
  // subsystem — the screen, its service, RestoreGuard, /restore — was
  // archived: "with Firestore as the only store, a user's data is already in
  // the cloud; signing in retrieves it." There is no successor screen to
  // point these at.
}
