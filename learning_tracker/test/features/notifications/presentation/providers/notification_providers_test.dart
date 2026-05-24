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
    test('defaults to 7:00 PM', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final time = container.read(reminderTimeProvider);
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

      // Listen so we detect state changes
      final values = <TimeOfDay>[];
      container.listen(reminderTimeProvider, (_, next) {
        values.add(next);
      });

      // Trigger build
      container.read(reminderTimeProvider);

      // Pump microtask queue
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // The last emitted value should be the loaded one
      expect(values.last.hour, 8);
      expect(values.last.minute, 30);
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
    test('defaults to true', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(reminderEnabledProvider), isTrue);
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(reminderEnabledProvider.notifier).toggle();

      expect(container.read(reminderEnabledProvider), isFalse);

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
    test('defaults to true', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(streakAlertEnabledProvider), isTrue);
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(streakAlertEnabledProvider.notifier).toggle();

      expect(container.read(streakAlertEnabledProvider), isFalse);

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
    test('defaults to 9:00 PM', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final time = container.read(streakAlertTimeProvider);
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
    test('defaults to true', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(rewardNotificationEnabledProvider), isTrue);
    });

    test('toggle switches state and persists to per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(rewardNotificationEnabledProvider.notifier).toggle();

      expect(container.read(rewardNotificationEnabledProvider), isFalse);

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
