/// WS5.key-prefs — Unit tests verifying per-profile key namespacing.
///
/// Confirms that two different profileIds produce distinct SharedPreferences
/// keys and notification IDs so profiles cannot clobber each other's settings.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';

void main() {
  group('WS5.key-prefs — NotificationPreferencesRepository key namespacing', () {
    test('two profileIds produce different reminderEnabled keys', () {
      final keyA = NotificationPreferencesRepository.reminderEnabledKey(1);
      final keyB = NotificationPreferencesRepository.reminderEnabledKey(2);
      expect(keyA, isNot(equals(keyB)));
      expect(keyA, contains('1'));
      expect(keyB, contains('2'));
    });

    test('two profileIds produce different reminderHour keys', () {
      final keyA = NotificationPreferencesRepository.reminderHourKey(10);
      final keyB = NotificationPreferencesRepository.reminderHourKey(11);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different reminderMinute keys', () {
      final keyA = NotificationPreferencesRepository.reminderMinuteKey(42);
      final keyB = NotificationPreferencesRepository.reminderMinuteKey(99);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different streakAlertEnabled keys', () {
      final keyA = NotificationPreferencesRepository.streakAlertEnabledKey(1);
      final keyB = NotificationPreferencesRepository.streakAlertEnabledKey(2);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different streakAlertHour keys', () {
      final keyA = NotificationPreferencesRepository.streakAlertHourKey(5);
      final keyB = NotificationPreferencesRepository.streakAlertHourKey(6);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different streakAlertMinute keys', () {
      final keyA = NotificationPreferencesRepository.streakAlertMinuteKey(5);
      final keyB = NotificationPreferencesRepository.streakAlertMinuteKey(6);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different rewardNotification keys', () {
      final keyA =
          NotificationPreferencesRepository.rewardNotificationEnabledKey(1);
      final keyB =
          NotificationPreferencesRepository.rewardNotificationEnabledKey(2);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different updatedAt keys', () {
      final keyA =
          NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
            1,
          );
      final keyB =
          NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
            2,
          );
      expect(keyA, isNot(equals(keyB)));
    });

    test('keyForProfile embeds the profileId in the key', () {
      expect(
        NotificationPreferencesRepository.keyForProfile('base_key', 7),
        equals('base_key_7'),
      );
      expect(
        NotificationPreferencesRepository.keyForProfile('base_key', 0),
        equals('base_key_0'),
      );
    });

    test('same profileId produces the same key (stability)', () {
      final key1 = NotificationPreferencesRepository.reminderEnabledKey(42);
      final key2 = NotificationPreferencesRepository.reminderEnabledKey(42);
      expect(key1, equals(key2));
    });
  });
}
