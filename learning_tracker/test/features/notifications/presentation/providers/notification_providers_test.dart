@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderTime', () {
    test('defaults to 7:00 PM', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final time = container.read(reminderTimeProvider);
      expect(time.hour, 19);
      expect(time.minute, 0);
    });

    test('loads saved time from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'daily_reminder_hour': 8,
        'daily_reminder_minute': 30,
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

    test('setTime persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(reminderTimeProvider.notifier)
          .setTime(const TimeOfDay(hour: 6, minute: 15));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('daily_reminder_hour'), 6);
      expect(prefs.getInt('daily_reminder_minute'), 15);
    });
  });

  group('ReminderEnabled', () {
    test('defaults to true', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(reminderEnabledProvider), isTrue);
    });

    test('toggle switches state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(reminderEnabledProvider.notifier).toggle();

      expect(container.read(reminderEnabledProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('daily_reminder_enabled'), isFalse);
    });
  });

  group('StreakAlertEnabled', () {
    test('defaults to true', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(streakAlertEnabledProvider), isTrue);
    });

    test('toggle switches state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(streakAlertEnabledProvider.notifier).toggle();

      expect(container.read(streakAlertEnabledProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('streak_alert_enabled'), isFalse);
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

    test('setTime persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(streakAlertTimeProvider.notifier)
          .setTime(const TimeOfDay(hour: 22, minute: 30));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streak_alert_hour'), 22);
      expect(prefs.getInt('streak_alert_minute'), 30);
    });
  });

  group('RewardNotificationEnabled', () {
    test('defaults to true', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(rewardNotificationEnabledProvider), isTrue);
    });

    test('toggle switches state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(rewardNotificationEnabledProvider.notifier).toggle();

      expect(container.read(rewardNotificationEnabledProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('reward_notification_enabled'), isFalse);
    });
  });

}
