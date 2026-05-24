import 'package:learning_tracker/features/notifications/domain/models/reminder_preferences.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed implementation of [NotificationPreferencesRepository].
///
/// All key strings are namespaced by [profileId] (WS5.key-prefs) so that
/// each profile on the device stores its reminder prefs independently.
///
/// All key strings and default values are centralised here rather than
/// being scattered across multiple Riverpod notifiers.
class SharedPrefsNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  const SharedPrefsNotificationPreferencesRepository({required this.profileId});

  final int profileId;

  @override
  Future<ReminderPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderPreferences(
      reminderEnabled:
          prefs.getBool(
            NotificationPreferencesRepository.reminderEnabledKey(profileId),
          ) ??
          true,
      reminderHour:
          prefs.getInt(
            NotificationPreferencesRepository.reminderHourKey(profileId),
          ) ??
          ReminderPreferences.defaultReminderHour,
      reminderMinute:
          prefs.getInt(
            NotificationPreferencesRepository.reminderMinuteKey(profileId),
          ) ??
          ReminderPreferences.defaultReminderMinute,
      streakAlertEnabled:
          prefs.getBool(
            NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
          ) ??
          true,
      streakAlertHour:
          prefs.getInt(
            NotificationPreferencesRepository.streakAlertHourKey(profileId),
          ) ??
          ReminderPreferences.defaultStreakAlertHour,
      streakAlertMinute:
          prefs.getInt(
            NotificationPreferencesRepository.streakAlertMinuteKey(profileId),
          ) ??
          ReminderPreferences.defaultStreakAlertMinute,
      rewardNotificationEnabled:
          prefs.getBool(
            NotificationPreferencesRepository.rewardNotificationEnabledKey(
              profileId,
            ),
          ) ??
          true,
    );
  }

  @override
  Future<void> save(ReminderPreferences prefs) async {
    final storage = await SharedPreferences.getInstance();
    await Future.wait([
      storage.setBool(
        NotificationPreferencesRepository.reminderEnabledKey(profileId),
        prefs.reminderEnabled,
      ),
      storage.setInt(
        NotificationPreferencesRepository.reminderHourKey(profileId),
        prefs.reminderHour,
      ),
      storage.setInt(
        NotificationPreferencesRepository.reminderMinuteKey(profileId),
        prefs.reminderMinute,
      ),
      storage.setBool(
        NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
        prefs.streakAlertEnabled,
      ),
      storage.setInt(
        NotificationPreferencesRepository.streakAlertHourKey(profileId),
        prefs.streakAlertHour,
      ),
      storage.setInt(
        NotificationPreferencesRepository.streakAlertMinuteKey(profileId),
        prefs.streakAlertMinute,
      ),
      storage.setBool(
        NotificationPreferencesRepository.rewardNotificationEnabledKey(
          profileId,
        ),
        prefs.rewardNotificationEnabled,
      ),
    ]);
  }
}
