@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The default activeProfileId is 0 (from activeProfileIdProvider.build → selectedProfileId null → 0).
  // All per-profile keys are therefore suffixed with '_0' in unit-test containers
  // unless activeProfileIdProvider is overridden.
  const testProfileId = 0;

  group('ReminderTime', () {
    test('defaults to 7:00 PM', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // AUD-notifications-02: reminderTimeProvider is an AsyncNotifier that
      // genuinely awaits SharedPreferences — await `.future` for the settled
      // value instead of reading the (removed) hardcoded synchronous default.
      final time = await container.read(reminderTimeProvider.future);
      expect(time.hour, 19);
      expect(time.minute, 0);
    });

    test('loads saved time from SharedPreferences (per-profile key)', () async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.reminderHourKey(testProfileId): 8,
        NotificationPreferencesRepository.reminderMinuteKey(testProfileId): 30,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final time = await container.read(reminderTimeProvider.future);
      expect(time.hour, 8);
      expect(time.minute, 30);
    });

    test('setTime persists to per-profile SharedPreferences key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(reminderTimeProvider.notifier)
          .setTime(const TimeOfDay(hour: 6, minute: 15));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          NotificationPreferencesRepository.reminderHourKey(testProfileId),
        ),
        6,
      );
      expect(
        prefs.getInt(
          NotificationPreferencesRepository.reminderMinuteKey(testProfileId),
        ),
        15,
      );
    });
  });

  group('ReminderEnabled', () {
    test('defaults to true', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(reminderEnabledProvider.future), isTrue);
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Await the settled default before toggling (toggle() flips whatever
      // `state.value` currently holds — awaiting avoids racing the in-flight
      // AsyncNotifier build()).
      await container.read(reminderEnabledProvider.future);
      await container.read(reminderEnabledProvider.notifier).toggle();

      expect(container.read(reminderEnabledProvider).value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.reminderEnabledKey(testProfileId),
        ),
        isFalse,
      );
    });
  });

  group('StreakAlertEnabled', () {
    test('defaults to true', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(streakAlertEnabledProvider.future), isTrue);
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(streakAlertEnabledProvider.future);
      await container.read(streakAlertEnabledProvider.notifier).toggle();

      expect(container.read(streakAlertEnabledProvider).value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.streakAlertEnabledKey(
            testProfileId,
          ),
        ),
        isFalse,
      );
    });
  });

  group('StreakAlertTime', () {
    test('defaults to 9:00 PM', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final time = await container.read(streakAlertTimeProvider.future);
      expect(time.hour, 21);
      expect(time.minute, 0);
    });

    test('setTime persists to per-profile SharedPreferences key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(streakAlertTimeProvider.notifier)
          .setTime(const TimeOfDay(hour: 22, minute: 30));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          NotificationPreferencesRepository.streakAlertHourKey(testProfileId),
        ),
        22,
      );
      expect(
        prefs.getInt(
          NotificationPreferencesRepository.streakAlertMinuteKey(testProfileId),
        ),
        30,
      );
    });
  });

  group('RewardNotificationEnabled', () {
    test('defaults to true', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(rewardNotificationEnabledProvider.future),
        isTrue,
      );
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(rewardNotificationEnabledProvider.future);
      await container.read(rewardNotificationEnabledProvider.notifier).toggle();

      expect(container.read(rewardNotificationEnabledProvider).value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.rewardNotificationEnabledKey(
            testProfileId,
          ),
        ),
        isFalse,
      );
    });
  });
}
