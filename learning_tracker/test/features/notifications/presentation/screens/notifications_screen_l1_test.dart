// L1 widget-behaviour test — NotificationsScreen
//
// Covers:
//   • Initial render: AppBar title, all three toggle groups, device toggle.
//   • Reminder toggle ON→OFF: state transitions, time-row disables, persists to SharedPrefs.
//   • Reminder toggle OFF→ON: requestPermission is called.
//   • Reminder time-row disabled when reminder toggle is off (onTap is null).
//   • Reminder time-row enabled when reminder toggle is on (tapping opens TimePicker).
//   • Streak alert toggle ON→OFF + time-row disables.
//   • Streak alert toggle OFF→ON: requestPermission is called.
//   • Streak alert time-row disabled when streak toggle is off.
//   • Reward toggle ON→OFF + requestPermission on re-enable.
//   • Device notification toggle shown; displays "allowed" subtitle when permitted.
//   • Device toggle: tapping off shows a SnackBar hint (cannot programmatically disable).
//   • Device toggle: requestPermission called when turned on; denied → "blocked" SnackBar.
//   • He-RTL smoke: renders under Hebrew locale without crash or overflow.
//
// HARNESS NOTES:
//   • The Notifier providers (ReminderEnabled, ReminderTime, etc.) are @riverpod
//     codegen providers whose state machines async-load from SharedPreferences.
//     We seed SharedPreferences via SharedPreferences.setMockInitialValues() so the
//     loaded value matches what the test needs.
//   • reminderSyncEffectProvider / streakAlertSyncEffectProvider are @Riverpod(keepAlive)
//     FutureProviders that try to schedule real OS notifications; we override them with
//     a no-op Future<void>.value(null) to isolate the UI tests.
//   • DeviceNotificationToggle calls notificationServiceProvider.hasPermission() on
//     initState.  We stub it on the mock.

@Tags(['notifications', 'notifications_screen_l1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockNotificationGateway extends Mock implements NotificationGateway {}

const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

// ── AUD-notifications-02: fixed-value AsyncNotifier overrides ──────────────
//
// The preference providers are now AsyncNotifiers (see notification_providers
// .dart), which have no `overrideWithValue` — only `overrideWith(() =>
// Notifier)`. `_pump` below flushes two extra pump()s after pumpWidget, so
// the microtask-async build() below settles to AsyncData before assertions
// run, matching the old overrideWithValue ergonomics.

class _FixedReminderEnabled extends ReminderEnabled {
  _FixedReminderEnabled(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}

class _FixedReminderTime extends ReminderTime {
  _FixedReminderTime(this._value);
  final TimeOfDay _value;
  @override
  Future<TimeOfDay> build() async => _value;
}

class _FixedStreakAlertEnabled extends StreakAlertEnabled {
  _FixedStreakAlertEnabled(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}

class _FixedStreakAlertTime extends StreakAlertTime {
  _FixedStreakAlertTime(this._value);
  final TimeOfDay _value;
  @override
  Future<TimeOfDay> build() async => _value;
}

class _FixedRewardNotificationEnabled extends RewardNotificationEnabled {
  _FixedRewardNotificationEnabled(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _buildApp({
  required _MockNotificationGateway gateway,
  bool reminderEnabled = true,
  bool streakEnabled = true,
  bool rewardEnabled = true,
  TimeOfDay reminderTime = const TimeOfDay(hour: 19, minute: 0),
  TimeOfDay streakTime = const TimeOfDay(hour: 21, minute: 0),
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    // Disable auto-retry so errored FutureProviders reach the error state in
    // tests (required by the L1 pattern for FutureProviders).
    overrides: [
      selectedProfileIdProvider.overrideWithValue(_profileId),
      notificationServiceProvider.overrideWithValue(gateway),
      reminderEnabledProvider.overrideWith(
        () => _FixedReminderEnabled(reminderEnabled),
      ),
      reminderTimeProvider.overrideWith(() => _FixedReminderTime(reminderTime)),
      streakAlertEnabledProvider.overrideWith(
        () => _FixedStreakAlertEnabled(streakEnabled),
      ),
      streakAlertTimeProvider.overrideWith(
        () => _FixedStreakAlertTime(streakTime),
      ),
      rewardNotificationEnabledProvider.overrideWith(
        () => _FixedRewardNotificationEnabled(rewardEnabled),
      ),
      // Suppress scheduling side-effects so tests stay isolated.
      reminderSyncEffectProvider.overrideWith((ref) async {}),
      streakAlertSyncEffectProvider.overrideWith((ref) async {}),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const NotificationsScreen(),
    ),
  );
}

/// Pump helper: does NOT use pumpAndSettle (would hang on live streams).
Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Per-test fixtures ─────────────────────────────────────────────────────────

late _MockNotificationGateway _gateway;

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _gateway = _MockNotificationGateway();
    // DeviceNotificationToggle calls hasPermission() on initState.
    when(() => _gateway.hasPermission()).thenAnswer((_) async => true);
    when(() => _gateway.requestPermission()).thenAnswer((_) async => true);
  });

  // ── Initial render ──────────────────────────────────────────────────────────

  group('NotificationsScreen — initial render (en)', () {
    testWidgets('shows AppBar with l10n title "Notifications"', (tester) async {
      await _pump(tester, _buildApp(gateway: _gateway));

      // l10n key: notifAppBarNotifications
      expect(find.text('Notifications'), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows device notification toggle card', (tester) async {
      await _pump(tester, _buildApp(gateway: _gateway));

      expect(
        find.byKey(const Key('device_notification_toggle')),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets('shows reminder toggle with correct key', (tester) async {
      await _pump(tester, _buildApp(gateway: _gateway));

      expect(find.byKey(const Key('reminder_toggle')), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows reminder time row', (tester) async {
      await _pump(tester, _buildApp(gateway: _gateway));

      // l10n key: notifReminderTime
      expect(find.text('Reminder Time'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows streak alert toggle with correct key', (tester) async {
      await _pump(tester, _buildApp(gateway: _gateway));

      expect(find.byKey(const Key('streak_alert_toggle')), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows streak alert time row', (tester) async {
      await _pump(tester, _buildApp(gateway: _gateway));

      // l10n key: notifStreakAlertTime
      expect(find.text('Streak Alert Time'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows reward notification toggle with correct key', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway));

      expect(
        find.byKey(const Key('reward_notification_toggle')),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets(
      'shows four Switch widgets (reminder, streak alert, reward, device toggle)',
      (tester) async {
        await _pump(tester, _buildApp(gateway: _gateway));

        // Three per-preference switches plus one in DeviceNotificationToggle.
        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(4));

        await _tearDown(tester);
      },
    );

    testWidgets('HOT STREAK badge visible when streak alert toggle is shown', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway));

      // l10n key: notifHotStreakBadge
      expect(find.text('HOT STREAK'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── Reminder toggle — initial enabled state ─────────────────────────────────

  group('NotificationsScreen — reminder toggle state (enabled)', () {
    testWidgets('reminder Switch value is true when provider is true', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, reminderEnabled: true));

      final reminderRow = find.byKey(const Key('reminder_toggle'));
      final sw = tester.widget<Switch>(
        find.descendant(of: reminderRow, matching: find.byType(Switch)),
      );
      expect(sw.value, isTrue);

      await _tearDown(tester);
    });

    testWidgets('reminder time row is enabled (onTap non-null) when on', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, reminderEnabled: true));

      final timeRow = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Reminder Time'),
      );
      expect(
        timeRow.onTap,
        isNotNull,
        reason: 'Reminder time row must be tappable when reminder is enabled',
      );

      await _tearDown(tester);
    });
  });

  // ── Reminder toggle — disabled state ────────────────────────────────────────

  group('NotificationsScreen — reminder toggle state (disabled)', () {
    testWidgets('reminder Switch value is false when provider is false', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, reminderEnabled: false));

      final reminderRow = find.byKey(const Key('reminder_toggle'));
      final sw = tester.widget<Switch>(
        find.descendant(of: reminderRow, matching: find.byType(Switch)),
      );
      expect(sw.value, isFalse);

      await _tearDown(tester);
    });

    testWidgets('reminder time row is disabled (onTap null) when off', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, reminderEnabled: false));

      final timeRow = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Reminder Time'),
      );
      expect(
        timeRow.onTap,
        isNull,
        reason: 'Reminder time row must NOT be tappable when reminder is off',
      );

      await _tearDown(tester);
    });
  });

  // ── Reminder toggle — toggling behaviour ────────────────────────────────────

  group('NotificationsScreen — reminder toggle interaction', () {
    testWidgets(
      'toggling reminder OFF (when on) does NOT call requestPermission',
      (tester) async {
        // Override with stateful notifier so the toggle can mutate state.
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderEnabledKey(_profileId): true,
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              selectedProfileIdProvider.overrideWithValue(_profileId),
              notificationServiceProvider.overrideWithValue(_gateway),
              reminderSyncEffectProvider.overrideWith((ref) async {}),
              streakAlertSyncEffectProvider.overrideWith((ref) async {}),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: NotificationsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap the reminder switch (which starts ON) to turn it OFF.
        final reminderRow = find.byKey(const Key('reminder_toggle'));
        await tester.tap(
          find.descendant(of: reminderRow, matching: find.byType(Switch)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verifyNever(() => _gateway.requestPermission());

        await _tearDown(tester);
      },
    );

    testWidgets('toggling reminder ON (from off) calls requestPermission', (
      tester,
    ) async {
        SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.reminderEnabledKey(_profileId): false,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedProfileIdProvider.overrideWithValue(_profileId),
            notificationServiceProvider.overrideWithValue(_gateway),
            reminderSyncEffectProvider.overrideWith((ref) async {}),
            streakAlertSyncEffectProvider.overrideWith((ref) async {}),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final reminderRow = find.byKey(const Key('reminder_toggle'));
      await tester.tap(
        find.descendant(of: reminderRow, matching: find.byType(Switch)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => _gateway.requestPermission()).called(1);

      await _tearDown(tester);
    });

    testWidgets(
      'toggling reminder persists enabled=false to SharedPreferences',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderEnabledKey(_profileId): true,
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              selectedProfileIdProvider.overrideWithValue(_profileId),
              notificationServiceProvider.overrideWithValue(_gateway),
              reminderSyncEffectProvider.overrideWith((ref) async {}),
              streakAlertSyncEffectProvider.overrideWith((ref) async {}),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: NotificationsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final reminderRow = find.byKey(const Key('reminder_toggle'));
        await tester.tap(
          find.descendant(of: reminderRow, matching: find.byType(Switch)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getBool(
          NotificationPreferencesRepository.reminderEnabledKey(_profileId),
        );
        expect(
          stored,
          isFalse,
          reason:
              'Toggling reminder off must persist false to SharedPreferences',
        );

        await _tearDown(tester);
      },
    );
  });

  // ── Reminder time row — time picker ─────────────────────────────────────────

  group('NotificationsScreen — reminder time picker', () {
    testWidgets('tapping time row when enabled opens TimePickerDialog', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, reminderEnabled: true));

      // Match the row by its title text rather than find.byKey — the key is
      // forwarded onto both the _SettingsTimeRow wrapper and its inner
      // ListTile, so byKey would match two elements (AUD-t-notifications-08).
      await tester.tap(find.widgetWithText(ListTile, 'Reminder Time'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(TimePickerDialog), findsOneWidget);

      // Dismiss without selecting.
      await tester.tapAt(Offset.zero);
      await tester.pump();

      await _tearDown(tester);
    });

    testWidgets('tapping time row when DISABLED does NOT open TimePickerDialog', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, reminderEnabled: false));

      // The ListTile has onTap=null when disabled; tapping it should be a no-op.
      await tester.tap(
        find.widgetWithText(ListTile, 'Reminder Time'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(find.byType(TimePickerDialog), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── Streak alert toggle ──────────────────────────────────────────────────────

  group('NotificationsScreen — streak alert toggle state', () {
    testWidgets('streak alert Switch is true when provider is true', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, streakEnabled: true));

      final row = find.byKey(const Key('streak_alert_toggle'));
      final sw = tester.widget<Switch>(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(sw.value, isTrue);

      await _tearDown(tester);
    });

    testWidgets('streak alert Switch is false when provider is false', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, streakEnabled: false));

      final row = find.byKey(const Key('streak_alert_toggle'));
      final sw = tester.widget<Switch>(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(sw.value, isFalse);

      await _tearDown(tester);
    });

    testWidgets('streak alert time row is disabled (onTap null) when off', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, streakEnabled: false));

      final timeRow = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Streak Alert Time'),
      );
      expect(
        timeRow.onTap,
        isNull,
        reason: 'Streak time row must NOT be tappable when streak alert is off',
      );

      await _tearDown(tester);
    });

    testWidgets('streak alert time row is enabled when on', (tester) async {
      await _pump(tester, _buildApp(gateway: _gateway, streakEnabled: true));

      final timeRow = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Streak Alert Time'),
      );
      expect(
        timeRow.onTap,
        isNotNull,
        reason: 'Streak time row must be tappable when streak alert is on',
      );

      await _tearDown(tester);
    });
  });

  group('NotificationsScreen — streak alert toggle interaction', () {
    testWidgets('toggling streak alert ON (from off) calls requestPermission', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.streakAlertEnabledKey(_profileId): false,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedProfileIdProvider.overrideWithValue(_profileId),
            notificationServiceProvider.overrideWithValue(_gateway),
            reminderSyncEffectProvider.overrideWith((ref) async {}),
            streakAlertSyncEffectProvider.overrideWith((ref) async {}),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final row = find.byKey(const Key('streak_alert_toggle'));
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => _gateway.requestPermission()).called(1);

      await _tearDown(tester);
    });

    testWidgets(
      'toggling streak alert persists enabled=false to SharedPreferences',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.streakAlertEnabledKey(_profileId): true,
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              selectedProfileIdProvider.overrideWithValue(_profileId),
              notificationServiceProvider.overrideWithValue(_gateway),
              reminderSyncEffectProvider.overrideWith((ref) async {}),
              streakAlertSyncEffectProvider.overrideWith((ref) async {}),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: NotificationsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final row = find.byKey(const Key('streak_alert_toggle'));
        await tester.tap(
          find.descendant(of: row, matching: find.byType(Switch)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getBool(
          NotificationPreferencesRepository.streakAlertEnabledKey(_profileId),
        );
        expect(stored, isFalse);

        await _tearDown(tester);
      },
    );
  });

  // ── Streak alert time picker ─────────────────────────────────────────────────

  group('NotificationsScreen — streak alert time picker', () {
    testWidgets('tapping streak time row when enabled opens TimePickerDialog', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, streakEnabled: true));

      // Match by title text — find.byKey would match both the
      // _SettingsTimeRow wrapper and its inner ListTile (AUD-t-notifications-08).
      await tester.tap(find.widgetWithText(ListTile, 'Streak Alert Time'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(TimePickerDialog), findsOneWidget);

      await tester.tapAt(Offset.zero);
      await tester.pump();

      await _tearDown(tester);
    });
  });

  // ── Reward notification toggle ───────────────────────────────────────────────

  group('NotificationsScreen — reward notification toggle', () {
    testWidgets('reward Switch is true when provider is true', (tester) async {
      await _pump(tester, _buildApp(gateway: _gateway, rewardEnabled: true));

      final row = find.byKey(const Key('reward_notification_toggle'));
      final sw = tester.widget<Switch>(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(sw.value, isTrue);

      await _tearDown(tester);
    });

    testWidgets('reward Switch is false when provider is false', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, rewardEnabled: false));

      final row = find.byKey(const Key('reward_notification_toggle'));
      final sw = tester.widget<Switch>(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(sw.value, isFalse);

      await _tearDown(tester);
    });

    testWidgets('toggling reward ON (from off) calls requestPermission', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.rewardNotificationEnabledKey(_profileId):
            false,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedProfileIdProvider.overrideWithValue(_profileId),
            notificationServiceProvider.overrideWithValue(_gateway),
            reminderSyncEffectProvider.overrideWith((ref) async {}),
            streakAlertSyncEffectProvider.overrideWith((ref) async {}),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final row = find.byKey(const Key('reward_notification_toggle'));
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => _gateway.requestPermission()).called(1);

      await _tearDown(tester);
    });

    testWidgets('toggling reward persists enabled=false to SharedPreferences', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.rewardNotificationEnabledKey(_profileId): true,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedProfileIdProvider.overrideWithValue(_profileId),
            notificationServiceProvider.overrideWithValue(_gateway),
            reminderSyncEffectProvider.overrideWith((ref) async {}),
            streakAlertSyncEffectProvider.overrideWith((ref) async {}),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final row = find.byKey(const Key('reward_notification_toggle'));
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(
        NotificationPreferencesRepository.rewardNotificationEnabledKey(_profileId),
      );
      expect(stored, isFalse);

      await _tearDown(tester);
    });
  });

  // ── Device notification toggle ───────────────────────────────────────────────

  group('NotificationsScreen — device notification toggle', () {
    testWidgets(
      'shows "Notifications allowed" subtitle when hasPermission is true',
      (tester) async {
        when(() => _gateway.hasPermission()).thenAnswer((_) async => true);

        await _pump(tester, _buildApp(gateway: _gateway));

        // Allow the async hasPermission check to settle.
        await tester.pump(const Duration(milliseconds: 100));

        // l10n key: deviceNotificationsAllowed
        expect(
          find.text('Notifications allowed on this device'),
          findsOneWidget,
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      'shows "Notifications blocked" subtitle when hasPermission is false',
      (tester) async {
        when(() => _gateway.hasPermission()).thenAnswer((_) async => false);

        await _pump(tester, _buildApp(gateway: _gateway));
        await tester.pump(const Duration(milliseconds: 100));

        // l10n key: deviceNotificationsBlocked
        expect(
          find.text('Notifications blocked — tap to open Settings'),
          findsOneWidget,
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping device toggle OFF shows SnackBar hint (cannot disable)',
      (tester) async {
        when(() => _gateway.hasPermission()).thenAnswer((_) async => true);

        await _pump(tester, _buildApp(gateway: _gateway));
        await tester.pump(const Duration(milliseconds: 100));

        // The device toggle SwitchListTile is inside the Card with key.
        final deviceCard = find.byKey(const Key('device_notification_toggle'));
        final deviceSwitch = find.descendant(
          of: deviceCard,
          matching: find.byType(Switch),
        );

        // Switch is ON (permitted=true). Tapping it triggers the "cannot
        // programmatically disable" path.
        await tester.tap(deviceSwitch);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // l10n key: deviceNotificationsDisableHint
        expect(
          find.text(
            'To disable notifications, go to Settings > Apps > Learning Tracker.',
          ),
          findsOneWidget,
        );

        await _tearDown(tester);
      },
    );

    testWidgets('tapping device toggle ON calls requestPermission', (
      tester,
    ) async {
      // Start with permission denied so the toggle is shown as OFF.
      when(() => _gateway.hasPermission()).thenAnswer((_) async => false);
      when(() => _gateway.requestPermission()).thenAnswer((_) async => true);

      await _pump(tester, _buildApp(gateway: _gateway));
      await tester.pump(const Duration(milliseconds: 100));

      final deviceCard = find.byKey(const Key('device_notification_toggle'));
      final deviceSwitch = find.descendant(
        of: deviceCard,
        matching: find.byType(Switch),
      );

      await tester.tap(deviceSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => _gateway.requestPermission()).called(1);

      await _tearDown(tester);
    });

    testWidgets('when requestPermission denied, shows blocked SnackBar hint', (
      tester,
    ) async {
      when(() => _gateway.hasPermission()).thenAnswer((_) async => false);
      when(() => _gateway.requestPermission()).thenAnswer((_) async => false);

      await _pump(tester, _buildApp(gateway: _gateway));
      await tester.pump(const Duration(milliseconds: 100));

      final deviceCard = find.byKey(const Key('device_notification_toggle'));
      final deviceSwitch = find.descendant(
        of: deviceCard,
        matching: find.byType(Switch),
      );

      await tester.tap(deviceSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // l10n key: deviceNotificationsBlockedHint
      expect(
        find.text(
          'Notifications blocked. Enable them in Settings > Apps > Learning Tracker > Notifications.',
        ),
        findsOneWidget,
      );

      await _tearDown(tester);
    });
  });

  // ── he-RTL smoke ─────────────────────────────────────────────────────────────

  group('NotificationsScreen — he-RTL smoke', () {
    testWidgets('renders under Hebrew locale without exception', (
      tester,
    ) async {
      when(() => _gateway.hasPermission()).thenAnswer((_) async => true);

      await _pump(
        tester,
        _buildApp(gateway: _gateway, locale: const Locale('he')),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byKey(const Key('reminder_toggle')), findsOneWidget);
      expect(find.byKey(const Key('streak_alert_toggle')), findsOneWidget);
      expect(
        find.byKey(const Key('reward_notification_toggle')),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets('Hebrew locale applies RTL text direction', (tester) async {
      await _pump(
        tester,
        _buildApp(gateway: _gateway, locale: const Locale('he')),
      );

      final dirFinders = find.byType(Directionality);
      expect(dirFinders, findsWidgets);
      final outerDir = tester.widget<Directionality>(dirFinders.first);
      expect(outerDir.textDirection, TextDirection.rtl);

      await _tearDown(tester);
    });

    testWidgets('no RenderFlex overflow under Hebrew locale', (tester) async {
      // Run with a narrow viewport to catch any hard-coded LTR overflow.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = <FlutterErrorDetails>[];
      final savedOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('overflowed')) {
          errors.add(details);
        } else {
          savedOnError?.call(details);
        }
      };

      await _pump(
        tester,
        _buildApp(gateway: _gateway, locale: const Locale('he')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      FlutterError.onError = savedOnError;

      expect(
        errors,
        isEmpty,
        reason: 'No RenderFlex overflows under Hebrew locale',
      );

      await _tearDown(tester);
    });

    // ── R8 RTL regression: time-row chevron auto-mirrors via matchTextDirection ─
    //
    // Icons.chevron_right_rounded sets IconData.matchTextDirection: true, so the
    // Icon widget flips the glyph to point left under RTL. The pre-R8 code
    // manually swapped to chevron_left_rounded in RTL, but that glyph also
    // auto-mirrors — a double-flip that pointed the chevron right again on the
    // left edge (device-audit run-8, device 5564). The chevron must be
    // chevron_right_rounded in both locales; chevron_left_rounded must never
    // appear.

    testWidgets(
      'RTL: time-row trailing chevron stays chevron_right_rounded and '
      'auto-mirrors (no manual chevron_left swap)',
      (tester) async {
        await _pump(
          tester,
          _buildApp(
            gateway: _gateway,
            locale: const Locale('he'),
            reminderEnabled: true,
          ),
        );

        // The _SettingsTimeRow disclosure chevron is the auto-mirroring glyph,
        // which the Icon widget flips to point left under RTL.
        expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
        expect(Icons.chevron_right_rounded.matchTextDirection, isTrue);
        // A manual chevron_left_rounded swap would double-flip and point right
        // again — it must never appear.
        expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets('LTR: time-row trailing chevron is chevron_right_rounded', (
      tester,
    ) async {
      await _pump(tester, _buildApp(gateway: _gateway, reminderEnabled: true));

      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);

      await _tearDown(tester);
    });
  });
}
