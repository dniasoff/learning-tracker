/// WS5.key-prefs — Unit tests verifying per-profile key namespacing.
///
/// Confirms that two different profileIds produce distinct SharedPreferences
/// keys and notification IDs so profiles cannot clobber each other's settings.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';

const _profileA = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _profileB = '01ARZ3NDEKTSV4RRFFQ69G5FB0';
const _profileC = '01ARZ3NDEKTSV4RRFFQ69G5FB1';
const _profileD = '01ARZ3NDEKTSV4RRFFQ69G5FB2';
const _profileE = '01ARZ3NDEKTSV4RRFFQ69G5FB3';
const _profileF = '01ARZ3NDEKTSV4RRFFQ69G5FB4';
const _profileG = '01ARZ3NDEKTSV4RRFFQ69G5FB6';
const _profileH = '01ARZ3NDEKTSV4RRFFQ69G5FC1';

void main() {
  group('WS5.key-prefs — NotificationPreferencesRepository key namespacing', () {
    test('two profileIds produce different reminderEnabled keys', () {
      final keyA = NotificationPreferencesRepository.reminderEnabledKey(_profileA);
      final keyB = NotificationPreferencesRepository.reminderEnabledKey(_profileB);
      expect(keyA, isNot(equals(keyB)));
      expect(keyA, contains(_profileA));
      expect(keyB, contains(_profileB));
    });

    test('two profileIds produce different reminderHour keys', () {
      final keyA = NotificationPreferencesRepository.reminderHourKey(_profileA);
      final keyB = NotificationPreferencesRepository.reminderHourKey(_profileC);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different reminderMinute keys', () {
      final keyA = NotificationPreferencesRepository.reminderMinuteKey(_profileD);
      final keyB = NotificationPreferencesRepository.reminderMinuteKey(_profileH);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different streakAlertEnabled keys', () {
      final keyA = NotificationPreferencesRepository.streakAlertEnabledKey(_profileA);
      final keyB = NotificationPreferencesRepository.streakAlertEnabledKey(_profileB);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different streakAlertHour keys', () {
      final keyA = NotificationPreferencesRepository.streakAlertHourKey(_profileE);
      final keyB = NotificationPreferencesRepository.streakAlertHourKey(_profileF);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different streakAlertMinute keys', () {
      final keyA = NotificationPreferencesRepository.streakAlertMinuteKey(_profileE);
      final keyB = NotificationPreferencesRepository.streakAlertMinuteKey(_profileF);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different rewardNotification keys', () {
      final keyA =
          NotificationPreferencesRepository.rewardNotificationEnabledKey(_profileA);
      final keyB =
          NotificationPreferencesRepository.rewardNotificationEnabledKey(_profileB);
      expect(keyA, isNot(equals(keyB)));
    });

    test('two profileIds produce different updatedAt keys', () {
      final keyA =
          NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
            _profileA,
          );
      final keyB =
          NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
            _profileB,
          );
      expect(keyA, isNot(equals(keyB)));
    });

    test('keyForProfile embeds the profileId in the key', () {
      expect(
        NotificationPreferencesRepository.keyForProfile('base_key', _profileG),
        equals('base_key_$_profileG'),
      );
      expect(
        NotificationPreferencesRepository.keyForProfile('base_key', _profileA),
        equals('base_key_$_profileA'),
      );
    });

    test('same profileId produces the same key (stability)', () {
      final key1 = NotificationPreferencesRepository.reminderEnabledKey(_profileH);
      final key2 = NotificationPreferencesRepository.reminderEnabledKey(_profileH);
      expect(key1, equals(key2));
    });
  });
}
