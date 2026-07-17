/// E2E Wave 2 P1 journeys — Infra-Crosscutting area.
///
/// Journeys implemented:
///   E2E-1102  City Picker: detect GPS location
///   E2E-1104  In-Israel toggle updates Yom Tov window computation
///   E2E-1106  Streak alert toggle shows/hides HOT STREAK badge
///   E2E-1107  Device notification toggle: OS blocked path
///   E2E-1108  Per-profile notification prefs isolated on profile switch
///   E2E-1111  Device restore: local-born account skips restore
///   E2E-1112  Sync status indicator: online/offline/degraded transitions
///   E2E-1113  Identity mismatch banner: degraded sync with wrong Firebase account
///
/// ## Journey notes
///
/// ### E2E-1102 — City Picker: detect GPS location
/// The "Detect" button lives in [SacredTimeSettingsCard._LocationActions] on
/// SettingsScreen (not in CityPickerScreen itself). Stubbing
/// [locationServiceProvider] with a fake that returns [LocationFetchSuccess]
/// causes [SacredLocationNotifier.detect] to update state. The resulting
/// snackbar text (l10n.sacredTimeLocationUpdated = "Location updated.") confirms
/// the call path completed successfully without a real GPS fix.
/// R-IC13: sequential override ensures no auto-set race between detect() and
/// setInIsrael().
///
/// ### E2E-1104 — In-Israel toggle
/// The In-Israel toggle is rendered by [SacredTimeSettingsCard._InIsraelRow].
/// Override [inIsraelProvider] to a fixed-false notifier, navigate to
/// SettingsScreen, scroll down to expose the SacredTimeSettingsCard, toggle
/// the switch, and verify [InIsraelNotifier.setInIsrael] wrote 'in_israel'=true
/// to SharedPreferences.
/// Note: Wave-3 implementation-plan §3 also lists this journey (R-IC13). Per §2
/// and the Wave-2 P1 catalog (line 417) it is a P1 journey.
///
/// ### E2E-1106 — Streak alert toggle shows/hides HOT STREAK badge
/// The streak row has key='streak_alert_toggle'. The HOT STREAK badge
/// (l10n.notifHotStreakBadge = "HOT STREAK") appears when
/// [streakAlertEnabledProvider]=true and is hidden when false.
/// Toggle OFF and confirm the badge disappears.
///
/// ### E2E-1107 — Device notification toggle: OS blocked
/// [DeviceNotificationToggle] reads from [notificationServiceProvider].
/// When [NotificationGateway.hasPermission] returns false, the toggle renders
/// a blocked state. We stub [notificationServiceProvider] with hasPermission=false
/// and assert the blocked subtitle text appears. R-IC4: extra pumps to settle.
///
/// ### E2E-1108 — Per-profile notification prefs isolated on profile switch
/// Mounts /notifications for Profile A and reads the reminder toggle's
/// rendered state through the widget tree (default = true). Persists
/// Profile B's pref as explicitly disabled, then switches the live
/// `activeProfileIdProvider` A → B mid-test by mutating the harness's
/// installed notifier's `.state` directly (the harness already overrides
/// `activeProfileIdProvider` once per test; a second `extraOverrides` entry
/// would trip Riverpod's "provider overridden twice" assertion). The real
/// [ReminderEnabled] notifier watches that provider and rebuilds under B's
/// per-profile key; the Switch must re-render B's independently-loaded
/// value, not A's cached state. AUD-t-cross-74: replaces the prior version,
/// which only round-tripped two SharedPreferences keys directly and never
/// built the real notifier or switched the live provider. R-IC5: extra pump
/// after the switch.
///
/// ### E2E-1111 — Device restore: local-born account skips restore
/// The harness RestoreGuard is built with hasCloudAccount=false (harness default),
/// so RestoreGuard never redirects to /restore for a local-born account.
/// Navigate to '/' and verify the app lands on the dashboard — DeviceRestoreScreen
/// is never shown.
///
/// ### E2E-1112 — Sync status indicator: online/offline/degraded transitions
/// Navigates to SettingsScreen and overrides [syncStatusProvider] to each
/// variant in a separate sub-test (separate pumpApp calls) to verify the
/// BackupSyncSection card subtitle updates:
///   synced → no "LOCAL ONLY" text; offline → "Offline"; degraded → "Sync paused"
///
/// ### E2E-1113 — Identity mismatch banner
/// When [syncIdentityStatusProvider] returns mismatched and [syncStatusProvider]
/// is degraded, BackupSyncSection renders the identity-mismatch card with
/// l10n.backupSyncSignInToBackUp = "Sign in to back up" action button.
/// R-IC11 (AUD-settings-01): localised action label is asserted; no raw
/// engineering string leaks — fixed by building the subtitle entirely from
/// AppLocalizations in BackupSyncSection._buildDegradedCard's isMismatch
/// branch.
///
/// ## Provider silence notes
///
/// [currentSacredWindowProvider] — SacredTimeSettingsCard's notifier starts a
/// repeating timer; override to null everywhere to prevent timer leaks.
///
/// [connectivityStreamProvider] — AppShell starts Timer.periodic; override
/// with Stream.value(true). Note: [_notificationSilenceOverrides] does NOT
/// include this override — always pair with [_infraSilences] (which includes it)
/// to avoid "provider overridden twice" errors.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 11 / §7 R-IC*
@Tags(['e2e', 'journey'])
library;

import 'package:flutter/material.dart'
    show Key, ListView, Row, Scrollable, Switch;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart'
    show syncIdentityStatusProvider;
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart'
    show syncStatusProvider;
import 'package:learning_tracker/core/sync/sync_identity_status.dart'
    show SyncIdentityStatus;
import 'package:learning_tracker/core/utils/date_utils.dart'
    show DateTimeFactory;
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
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart'
    show activeProfileIdProvider;
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart'
    show LocationService;
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart'
    show LocationFetchSuccess;
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart'
    show SacredLocation, SacredLocationSource;
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart'
    show InIsraelNotifier, inIsraelProvider, locationServiceProvider;
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart'
    show SyncStatus;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

/// [NotificationGateway] stub — hasPermission is configurable.
class _FakeNotificationGateway extends Fake implements NotificationGateway {
  _FakeNotificationGateway({this.permissionGranted = true});

  final bool permissionGranted;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> cancelStreakAlertForProfile(int profileId) async {}
}

/// [LocationService] stub that returns a fixed GPS success result without
/// touching the native Geolocator plugin.
class _FakeLocationService extends Fake implements LocationService {
  _FakeLocationService({required this.result});

  final LocationFetchSuccess result;

  @override
  Future<LocationFetchSuccess> detectCurrent() async => result;
}

/// [InIsraelNotifier] stub that starts at a known state without the async
/// prefs load (R-IC13: prevents auto-set race in tests).
class _FixedInIsraelNotifier extends InIsraelNotifier {
  _FixedInIsraelNotifier({required bool initial}) : _initial = initial;
  final bool _initial;

  @override
  bool build() => _initial; // returns directly; _load() is not called.
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Silences the heavy notification sync-effect providers.
///
/// IMPORTANT: does NOT include [connectivityStreamProvider] — that override is
/// in [_infraSilences]. Including it here would cause "provider overridden
/// twice" when both lists are combined.
List<Override> _notificationSilenceOverrides(NotificationGateway fakeGw) => [
  notificationServiceProvider.overrideWithValue(fakeGw),
  reminderSyncEffectProvider.overrideWith((ref) async {}),
  streakAlertSyncEffectProvider.overrideWith((ref) async {}),
  allProfilesReminderBootstrapProvider.overrideWith((ref) async {}),
];

/// Standard silence overrides shared across all infra P1 tests.
///
/// Includes dashboard stream silences, sacred-window timer, connectivity, and
/// the two tutor-invite providers that _PendingInvitesSection watches
/// (needed whenever SettingsScreen is navigated to).
List<Override> _infraSilences(E2EHarness h) => [
  ...h.dashboardSilenceOverrides,
  sacredWindowNullOverride(),
  connectivityOnlineOverride(),
  // _PendingInvitesSection in SettingsScreen watches these two providers.
  // Override to empty so they don't try to hit Firestore in headless tests.
  incomingGrantsEmptyOverride(),
  pendingInvitesEmptyOverride(),
];

// ── Scroll helper for Settings ─────────────────────────────────────────────

/// Scroll the Settings screen until [targetText] is visible, then settle.
///
/// First attempts [scrollUntilVisible] using the ListView's inner Scrollable.
/// Falls back to a double-drag if the finder throws (target already visible or
/// not in tree yet).
Future<void> _scrollSettingsTo(
  WidgetTester tester,
  String targetText, {
  double delta = -400,
  int maxScrolls = 8,
}) async {
  final listFinder = find.byType(ListView);
  if (listFinder.evaluate().isEmpty) return;

  // Prefer scrollUntilVisible for precise exposure.
  try {
    await tester.scrollUntilVisible(
      find.text(targetText, skipOffstage: false),
      delta,
      scrollable: find.descendant(
        of: listFinder.first,
        matching: find.byType(Scrollable),
      ),
      maxScrolls: maxScrolls,
    );
    await tester.pump(const Duration(milliseconds: 200));
  } catch (_) {
    // Fallback: two fixed drags to reach bottom-of-screen tiles.
    await tester.drag(listFinder.first, const Offset(0, -1200));
    await tester.pump();
    await tester.drag(listFinder.first, const Offset(0, -1200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }
}

/// Navigate from dashboard to SettingsScreen by tapping the SETTINGS tab.
Future<void> _goToSettings(E2EHarness h) async {
  await h.tapText('SETTINGS', settle: const Duration(milliseconds: 400));
  await h.pump(const Duration(milliseconds: 300));
  await h.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-1102 ─────────────────────────────────────────────────────────────────

  group('E2E-1102 — City Picker: detect GPS location', () {
    // Key assertions (catalog §2 Area 11):
    //  • Settings → SacredTimeSettingsCard renders "Detect" button
    //  • Tapping Detect calls sacredLocationProvider.notifier.detect()
    //  • locationServiceProvider stub returns LocationFetchSuccess
    //  • Snackbar "Location updated." confirms the call path completed
    //
    // R-IC13: detect() is called first; no race with setInIsrael().

    testWidgets(
      'Tapping Detect on SacredTimeSettingsCard with a GPS stub shows '
      '"Location updated." snackbar confirming detect() completed',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'detect1102@test.com',
          displayName: 'DetectUser',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Jerusalem GPS fix — no real location plugin needed.
        final fakeLocation = SacredLocation(
          latitude: 31.76,
          longitude: 35.21,
          source: SacredLocationSource.detected,
          fixedAt: DateTime.utc(2026, 6, 1),
          countryCode: 'IL',
        );
        final fakeLocationService = _FakeLocationService(
          result: LocationFetchSuccess(fakeLocation),
        );
        final fakeGw = _FakeNotificationGateway();

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._infraSilences(h),
            ..._notificationSilenceOverrides(fakeGw),
            locationServiceProvider.overrideWithValue(fakeLocationService),
          ],
        );

        await _goToSettings(h);

        // Scroll to expose SacredTimeSettingsCard "Detect" button in DEVICE section.
        await _scrollSettingsTo(tester, 'Detect');

        // "Detect" button must be visible.
        h.expectOnScreen('Detect', routeName: 'SacredTimeSettingsCard');

        // Tap "Detect" → calls sacredLocationProvider.notifier.detect()
        // → fakeLocationService.detectCurrent() → LocationFetchSuccess.
        await h.tapText('Detect', settle: const Duration(milliseconds: 800));
        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // After success, the snackbar "Location updated." should appear.
        // l10n.sacredTimeLocationUpdated = 'Location updated.'
        expect(
          find.textContaining('Location updated'),
          findsWidgets,
          reason:
              'Snackbar "Location updated." must appear after LocationFetchSuccess '
              '(confirms detect() call path completed via fake LocationService)',
        );
      },
    );
  });

  // ── E2E-1104 ─────────────────────────────────────────────────────────────────

  group('E2E-1104 — In-Israel toggle updates Yom Tov window computation', () {
    // Key assertions (catalog §2 Area 11):
    //  • SacredTimeSettingsCard renders "I am in Israel" toggle
    //  • Toggle starts OFF; tapping writes 'in_israel'=true to SharedPreferences
    //
    // R-IC13: [_FixedInIsraelNotifier] bypasses async _load() entirely so
    // there is no race between detect() / setInIsrael() in this test.
    //
    // Note: Wave-3 plan §3 also lists this journey. Per §2 and the Wave-2
    // catalog (line 417) it is P1.

    testWidgets('In-Israel switch in SacredTimeSettingsCard is toggleable; '
        'toggling ON writes in_israel=true to SharedPreferences', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(
        email: 'israel1104@test.com',
        displayName: 'IsraelUser',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final fakeGw = _FakeNotificationGateway();

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._infraSilences(h),
          ..._notificationSilenceOverrides(fakeGw),
          // R-IC13: fix inIsrael to false so async _load() cannot race.
          inIsraelProvider.overrideWith(
            () => _FixedInIsraelNotifier(initial: false),
          ),
        ],
      );

      await _goToSettings(h);

      // Scroll to expose SacredTimeSettingsCard "I am in Israel" toggle.
      await _scrollSettingsTo(tester, 'I am in Israel');

      // "I am in Israel" row must be visible.
      h.expectOnScreen('I am in Israel', routeName: 'SacredTimeSettingsCard');

      // The In-Israel Switch lives inside the row labelled "I am in Israel".
      // Use a descendant finder anchored to the label text Row so we don't
      // accidentally tap a different Switch that scrolled into view.
      final israelRow = find.ancestor(
        of: find.text('I am in Israel'),
        matching: find.byType(Row),
      );
      final israelSwitch = find.descendant(
        of: israelRow.first,
        matching: find.byType(Switch),
      );
      expect(
        israelSwitch,
        findsWidgets,
        reason: 'In-Israel Switch must be present in SacredTimeSettingsCard',
      );

      // Tap to toggle ON → calls InIsraelNotifier.setInIsrael(true).
      // Use the first match (innermost Row wraps the Switch directly).
      await tester.tap(israelSwitch.first, warnIfMissed: false);
      await tester.pump();
      // Drain microtasks for the async SharedPreferences write inside setInIsrael.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Key assertion: SharedPreferences 'sacred_time_in_israel' written as
      // true. SacredTimePreferences._inIsraelKey = 'sacred_time_in_israel'.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('sacred_time_in_israel'),
        isTrue,
        reason:
            "SharedPreferences['sacred_time_in_israel'] must be true after "
            'toggling On',
      );
    });
  });

  // ── E2E-1106 ─────────────────────────────────────────────────────────────────

  group('E2E-1106 — Streak alert toggle shows/hides HOT STREAK badge', () {
    // Key assertions (catalog §2 Area 11):
    //  • NotificationsScreen renders streak alert row (key='streak_alert_toggle')
    //  • When streakAlertEnabled=true (default): "HOT STREAK" badge visible
    //  • Toggling OFF removes "HOT STREAK" badge
    //  • SharedPreferences key streakAlertEnabledKey(profileId) = false

    testWidgets('HOT STREAK badge visible when streak alert ON; '
        'disappears after toggling OFF; SharedPreferences updated', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(
        email: 'streak1106@test.com',
        displayName: 'StreakUser',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final fakeGw = _FakeNotificationGateway();

      await h.pumpApp(
        path: '/notifications',
        extraOverrides: [
          ..._infraSilences(h),
          ..._notificationSilenceOverrides(fakeGw),
        ],
      );

      // Allow async _checkPermission + prefs loads to settle (R-IC4).
      await h.pump(const Duration(milliseconds: 400));
      await h.pump();

      h.expectOnScreen('Notifications', routeName: 'NotificationsScreen');
      h.expectOnScreen('Streak Alert');

      // HOT STREAK badge must be visible while enabled (default = true).
      expect(
        find.text('HOT STREAK'),
        findsWidgets,
        reason: 'HOT STREAK badge must appear when streak alert is ON',
      );

      // Toggle the streak alert OFF via the Switch inside the streak row.
      final streakRow = find.byKey(const Key('streak_alert_toggle'));
      expect(
        streakRow,
        findsOneWidget,
        reason: 'streak_alert_toggle row must be present',
      );

      final streakSwitch = find.descendant(
        of: streakRow,
        matching: find.byType(Switch),
      );
      expect(
        streakSwitch,
        findsOneWidget,
        reason:
            'Streak Alert Switch must be inside the streak_alert_toggle row',
      );

      // Tap to toggle OFF.
      await h.tapWidget(
        streakSwitch,
        settle: const Duration(milliseconds: 500),
      );
      await h.pump(const Duration(milliseconds: 300));
      await h.pump();

      // HOT STREAK badge must now be hidden.
      expect(
        find.text('HOT STREAK'),
        findsNothing,
        reason: 'HOT STREAK badge must disappear when streak alert is OFF',
      );

      // Verify SharedPreferences wrote the correct key.
      final profileId = identity.profileId;
      final key = NotificationPreferencesRepository.streakAlertEnabledKey(
        profileId,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(key),
        isFalse,
        reason:
            'SharedPreferences[$key] must be false after disabling streak alert',
      );
    });
  });

  // ── E2E-1107 ─────────────────────────────────────────────────────────────────

  group('E2E-1107 — Device notification toggle: OS permission blocked', () {
    // Key assertions (catalog §2 Area 11):
    //  • notificationServiceProvider stub returns hasPermission=false
    //  • DeviceNotificationToggle renders in blocked state showing blocked text
    //
    // R-IC4: extra pumps to settle DeviceNotificationToggle._checkPermission.

    testWidgets(
      'DeviceNotificationToggle shows blocked state when OS permission denied',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'blocked1107@test.com',
          displayName: 'BlockedUser',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Stub: hasPermission = false (OS denied).
        final fakeGw = _FakeNotificationGateway(permissionGranted: false);

        await h.pumpApp(
          path: '/notifications',
          extraOverrides: [
            ..._infraSilences(h),
            ..._notificationSilenceOverrides(fakeGw),
          ],
        );

        // (R-IC4) Extra pumps to settle async _checkPermission.
        await h.pump(const Duration(milliseconds: 300));
        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        h.expectOnScreen('Notifications', routeName: 'NotificationsScreen');

        // When OS permissions are blocked, DeviceNotificationToggle shows a
        // subtitle containing "blocked".
        // l10n.notifDeviceBlockedSubtitle contains "blocked" (headlessly verified
        // by matching the substring rather than the full localised string).
        expect(
          find.textContaining('blocked'),
          findsWidgets,
          reason:
              'DeviceNotificationToggle must show a "blocked" subtitle when '
              'OS notification permission is denied (R-IC4)',
        );
      },
    );
  });

  // ── E2E-1108 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-1108 — Per-profile notification prefs isolated on profile switch',
    () {
      // Key assertions (catalog §2 Area 11):
      //  • Profile A (profileId=N): reminder enabled=true (default) — read
      //    through the live widget tree (the Switch inside the
      //    'reminder_toggle' row), not a direct SharedPreferences read.
      //  • Profile B (profileId=N+1): reminder explicitly disabled in prefs.
      //  • Switching the active profile mid-session rebuilds the real
      //    ReminderEnabled AsyncNotifier (it watches activeProfileIdProvider,
      //    R-IC5) and the widget re-renders B's independently-loaded value —
      //    not A's cached state.
      //
      // AUD-t-cross-74: the prior version of this test only round-tripped two
      // SharedPreferences keys directly (never building ReminderEnabled or
      // switching the live activeProfileIdProvider), so it could not catch a
      // regression where build() stopped watching activeProfileIdProvider or
      // started reading a single shared key for every profile. This version
      // drives the real notifier by mutating the harness's installed
      // activeProfileIdProvider notifier's `.state` and reads the toggle's
      // rendered state via the widget tree.
      // weaken-ok: AUD-t-cross-74 — the direct-SharedPreferences assertions
      // this replaces only proved the mock stores what it's told (SDK
      // behavior, not app logic); the assertions below exercise the real
      // ReminderEnabled notifier and widget tree instead, which is strictly
      // more rigorous for the "per-profile isolation" contract this journey
      // names.

      testWidgets(
        "Profile A's reminder toggle reads its default (true) through the "
        'widget tree; switching to Profile B (persisted false) re-renders '
        "B's independently-loaded value via the same widget",
        (tester) async {
          final identity = E2EIdentity.localBorn(
            email: 'profswitch1108@test.com',
            displayName: 'ProfileSwitchUser',
          );
          final h = E2EHarness(tester, identity: identity);
          addTearDown(h.dispose);

          final fakeGw = _FakeNotificationGateway();

          await h.pumpApp(
            path: '/notifications',
            extraOverrides: [
              ..._infraSilences(h),
              ..._notificationSilenceOverrides(fakeGw),
            ],
          );
          await h.pump(const Duration(milliseconds: 300));
          await h.pump();

          h.expectOnScreen('Notifications', routeName: 'NotificationsScreen');

          final profileAId = identity.profileId;
          final profileBId = profileAId + 1;

          Switch reminderSwitch() => tester.widget<Switch>(
            find.descendant(
              of: find.byKey(const Key('reminder_toggle')),
              matching: find.byType(Switch),
            ),
          );

          // Profile A has no stored pref -> ReminderEnabled.build() must
          // resolve the default (true), rendered by the real Switch widget.
          expect(
            reminderSwitch().value,
            isTrue,
            reason:
                "Profile A's reminder toggle must render the default (true) "
                'through the widget tree',
          );

          // Persist Profile B's reminder pref as explicitly disabled — this
          // simulates B having configured it in an earlier session, before
          // this test switches into it.
          final keyB = NotificationPreferencesRepository.reminderEnabledKey(
            profileBId,
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(keyB, false);

          // Swap the active profile A -> B by mutating the harness's own
          // activeProfileIdProvider notifier directly (the harness already
          // installs one override per profile-scoped provider — see
          // E2EHarness._buildOverrides — so a *second* extraOverrides entry
          // for activeProfileIdProvider would trip Riverpod's "provider
          // overridden twice" assertion; mutating the installed notifier's
          // `.state` from the container is the established pattern for
          // driving a live profile switch — see
          // sync_providers_test.dart's `container.read(activeProfileIdProvider
          // .notifier).state = ...`). ReminderEnabled.build() watches
          // activeProfileIdProvider (R-IC5), so this must rebuild the real
          // notifier under B's key and the Switch must re-render B's value.
          final container = ProviderScope.containerOf(
            tester.element(find.byKey(const Key('reminder_toggle'))),
          );
          container.read(activeProfileIdProvider.notifier).state = profileBId;
          await h.pump(const Duration(milliseconds: 300));
          await h.pump();

          expect(
            reminderSwitch().value,
            isFalse,
            reason:
                "Profile B's reminder toggle must render its own persisted "
                'value (false) through the widget tree after the profile '
                'switch — if ReminderEnabled.build() ignored '
                'activeProfileIdProvider (e.g. reading a single shared key '
                "instead of the per-profile key), this would still show A's "
                'cached default (true) and this assertion would fail.',
          );
        },
      );
    },
  );

  // ── E2E-1111 ─────────────────────────────────────────────────────────────────

  group('E2E-1111 — Device restore: local-born account skips restore', () {
    // Key assertions (catalog §2 Area 11):
    //  • hasCloudAccount=false in RestoreGuard (harness default: line 529)
    //  • Navigating from "/" routes to dashboard, NOT to /restore
    //  • DeviceRestoreScreen is never shown
    //
    // The "skip restore" behaviour lives in the RestoreGuard, not the screen.
    // Since the harness always sets hasCloudAccount=false and markRestoreComplete(),
    // this test confirms the guard never redirects to /restore for local-born.

    testWidgets(
      'Local-born account (hasCloudAccount=false): navigating from "/" '
      'routes to dashboard; DeviceRestoreScreen is never shown',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'localborn1111@test.com',
          displayName: 'LocalBornUser',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(path: '/', extraOverrides: [..._infraSilences(h)]);

        // Allow guards to resolve fully.
        await h.pump(const Duration(milliseconds: 500));
        await h.pump(const Duration(milliseconds: 300));
        await h.pump();

        // DeviceRestoreScreen must NOT be shown.
        // 'Restore complete!' is the success heading; 'Restore failed' is the
        // error heading. Neither should appear for a local-born account.
        expect(
          find.textContaining('Restore complete'),
          findsNothing,
          reason:
              'DeviceRestoreScreen must NOT be shown for a local-born account',
        );
        expect(
          find.textContaining('Restore failed'),
          findsNothing,
          reason:
              'DeviceRestoreScreen error state must NOT be shown for local-born',
        );

        // Dashboard bottom-nav tabs (LEARN) must be visible, confirming the
        // router resolved to dashboard rather than /restore.
        expect(
          find.text('LEARN'),
          findsWidgets,
          reason:
              'Dashboard LEARN tab must be visible, confirming app routed to '
              'dashboard (not /restore) for a local-born account',
        );
      },
    );
  });

  // ── E2E-1112 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-1112 — Sync status indicator: online/offline/degraded transitions',
    () {
      // Key assertions (catalog §2 Area 11):
      //  • BackupSyncSection card title always "Backup & Sync"
      //  • synced → no "LOCAL ONLY" text
      //  • offline → "Offline" subtitle
      //  • degraded → "Sync paused" subtitle (backupSyncPausedNoCount)
      //
      // Each variant is a separate testWidgets call with its own pumpApp to
      // avoid "provider overridden twice" errors.

      testWidgets('synced status: BackupSyncSection shows "Backup & Sync" card '
          'with no "LOCAL ONLY" text', (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'synced1112@test.com',
          displayName: 'SyncedUser',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final fakeGw = _FakeNotificationGateway();

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._infraSilences(h),
            ..._notificationSilenceOverrides(fakeGw),
            syncStatusProvider.overrideWithValue(
              SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowUtc()),
            ),
          ],
        );

        await _goToSettings(h);
        await _scrollSettingsTo(tester, 'Backup & Sync');
        await h.pump(const Duration(milliseconds: 300));

        h.expectOnScreen('Backup & Sync', routeName: 'BackupSyncSection');

        expect(
          find.textContaining('LOCAL ONLY'),
          findsNothing,
          reason: 'BackupSyncSection must NOT show LOCAL ONLY card when synced',
        );
      });

      testWidgets(
        'offline status: BackupSyncSection shows "Offline" subtitle',
        (tester) async {
          final identity = E2EIdentity.localBorn(
            email: 'offline1112@test.com',
            displayName: 'OfflineUser',
          );
          final h = E2EHarness(tester, identity: identity);
          addTearDown(h.dispose);

          final fakeGw = _FakeNotificationGateway();

          await h.pumpApp(
            path: '/dashboard',
            extraOverrides: [
              ..._infraSilences(h),
              ..._notificationSilenceOverrides(fakeGw),
              syncStatusProvider.overrideWithValue(
                const SyncStatus.offline(pendingChanges: 0),
              ),
            ],
          );

          await _goToSettings(h);
          await _scrollSettingsTo(tester, 'Backup & Sync');
          await h.pump(const Duration(milliseconds: 300));

          // l10n.backupOffline = 'Offline'
          h.expectOnScreen('Offline', routeName: 'BackupSyncSection');
        },
      );

      testWidgets(
        'degraded status: BackupSyncSection shows "Sync paused" subtitle',
        (tester) async {
          final identity = E2EIdentity.localBorn(
            email: 'degraded1112@test.com',
            displayName: 'DegradedUser',
          );
          final h = E2EHarness(tester, identity: identity);
          addTearDown(h.dispose);

          final fakeGw = _FakeNotificationGateway();

          await h.pumpApp(
            path: '/dashboard',
            extraOverrides: [
              ..._infraSilences(h),
              ..._notificationSilenceOverrides(fakeGw),
              syncStatusProvider.overrideWithValue(
                const SyncStatus.degraded(
                  pendingChanges: 0,
                  reason: 'quota exhausted',
                ),
              ),
              // syncIdentityStatusProvider → matched so we get the generic
              // degraded card (not the identity-mismatch card of E2E-1113).
              syncIdentityStatusProvider.overrideWithValue(
                const SyncIdentityStatus.matched(),
              ),
            ],
          );

          await _goToSettings(h);
          await _scrollSettingsTo(tester, 'Backup & Sync');
          await h.pump(const Duration(milliseconds: 300));

          // l10n.backupSyncPausedNoCount(reason) = 'Sync paused. $reason'
          expect(
            find.textContaining('Sync paused'),
            findsWidgets,
            reason:
                'BackupSyncSection must show "Sync paused" subtitle for degraded status',
          );
        },
      );
    },
  );

  // ── E2E-1113 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-1113 — Identity mismatch banner: degraded sync with wrong Firebase account',
    () {
      // Key assertions (catalog §2 Area 11):
      //  • syncStatusProvider = degraded + syncIdentityStatusProvider = mismatched
      //  • BackupSyncSection renders identity-mismatch card with action button
      //  • l10n.backupSyncSignInToBackUp = "Sign in to back up" is visible
      //
      // R-IC11: localised action label is asserted; raw engineering string must
      // not leak to user-facing UI.

      testWidgets('R-IC11 (AUD-settings-01): identity-mismatch card with '
          'pendingChanges>0 never leaks the raw SyncStatusDegraded engineering '
          'reason string — subtitle is built entirely from AppLocalizations; '
          '"Sign in to back up" action button is present', (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'mismatch1113@test.com',
          displayName: 'MismatchUser',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final fakeGw = _FakeNotificationGateway();

        const mismatchStatus = SyncIdentityStatus.mismatched(
          activeAccountEmail: 'active@test.com',
          signedInEmail: 'wrong@test.com',
        );

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._infraSilences(h),
            ..._notificationSilenceOverrides(fakeGw),
            syncStatusProvider.overrideWithValue(
              const SyncStatus.degraded(
                pendingChanges: 3,
                reason: 'permission-denied threshold reached',
              ),
            ),
            syncIdentityStatusProvider.overrideWithValue(mismatchStatus),
          ],
        );

        await _goToSettings(h);
        await _scrollSettingsTo(tester, 'Backup & Sync');
        await h.pump(const Duration(milliseconds: 300));

        // Card title present.
        h.expectOnScreen('Backup & Sync', routeName: 'BackupSyncSection');

        // Identity mismatch path: action button "Sign in to back up".
        // l10n.backupSyncSignInToBackUp = 'Sign in to back up'
        h.expectOnScreen(
          'Sign in to back up',
          routeName: 'BackupSyncSection identity mismatch',
        );

        // (R-IC11) Raw engineering reason must not be visible to the user.
        // The mismatch card uses actionLabel-only layout; the raw reason
        // is suppressed. We confirm the card rendered the action label,
        // not raw exception text.
        expect(
          find.textContaining('permission-denied threshold'),
          findsNothing,
          reason:
              'Raw engineering reason string must not leak to user-facing UI '
              '(R-IC11)',
        );
      });
    },
  );
}
