import 'package:learning_tracker/features/notifications/domain/models/reminder_preferences.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed implementation of [NotificationPreferencesRepository].
///
/// All key strings and default values are centralised here rather than
/// being scattered across multiple Riverpod notifiers.
class SharedPrefsNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  const SharedPrefsNotificationPreferencesRepository();

  @override
  Future<ReminderPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderPreferences(
      reminderEnabled:
          prefs.getBool(NotificationPreferencesRepository.reminderEnabledKey) ??
          true,
      reminderHour:
          prefs.getInt(NotificationPreferencesRepository.reminderHourKey) ??
          ReminderPreferences.defaultReminderHour,
      reminderMinute:
          prefs.getInt(NotificationPreferencesRepository.reminderMinuteKey) ??
          ReminderPreferences.defaultReminderMinute,
      streakAlertEnabled:
          prefs.getBool(
            NotificationPreferencesRepository.streakAlertEnabledKey,
          ) ??
          true,
      streakAlertHour:
          prefs.getInt(NotificationPreferencesRepository.streakAlertHourKey) ??
          ReminderPreferences.defaultStreakAlertHour,
      streakAlertMinute:
          prefs.getInt(
            NotificationPreferencesRepository.streakAlertMinuteKey,
          ) ??
          ReminderPreferences.defaultStreakAlertMinute,
      rewardNotificationEnabled:
          prefs.getBool(
            NotificationPreferencesRepository.rewardNotificationEnabledKey,
          ) ??
          true,
    );
  }

  @override
  Future<void> save(ReminderPreferences prefs) async {
    final storage = await SharedPreferences.getInstance();
    await Future.wait([
      storage.setBool(
        NotificationPreferencesRepository.reminderEnabledKey,
        prefs.reminderEnabled,
      ),
      storage.setInt(
        NotificationPreferencesRepository.reminderHourKey,
        prefs.reminderHour,
      ),
      storage.setInt(
        NotificationPreferencesRepository.reminderMinuteKey,
        prefs.reminderMinute,
      ),
      storage.setBool(
        NotificationPreferencesRepository.streakAlertEnabledKey,
        prefs.streakAlertEnabled,
      ),
      storage.setInt(
        NotificationPreferencesRepository.streakAlertHourKey,
        prefs.streakAlertHour,
      ),
      storage.setInt(
        NotificationPreferencesRepository.streakAlertMinuteKey,
        prefs.streakAlertMinute,
      ),
      storage.setBool(
        NotificationPreferencesRepository.rewardNotificationEnabledKey,
        prefs.rewardNotificationEnabled,
      ),
    ]);
  }
}
