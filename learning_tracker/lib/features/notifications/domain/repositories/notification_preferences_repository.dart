import 'package:learning_tracker/features/notifications/domain/models/reminder_preferences.dart';

/// Repository interface for reading and writing [ReminderPreferences].
///
/// All key constants and defaults are encapsulated here (previously scattered
/// as private constants at the top of `notification_providers.dart`).
abstract class NotificationPreferencesRepository {
  /// SharedPreferences key constants — exposed so the cloud-sync function can
  /// build the Firestore snapshot without re-reading from storage.
  static const String reminderEnabledKey = 'daily_reminder_enabled';
  static const String reminderHourKey = 'daily_reminder_hour';
  static const String reminderMinuteKey = 'daily_reminder_minute';

  static const String streakAlertEnabledKey = 'streak_alert_enabled';
  static const String streakAlertHourKey = 'streak_alert_hour';
  static const String streakAlertMinuteKey = 'streak_alert_minute';

  static const String rewardNotificationEnabledKey =
      'reward_notification_enabled';

  static const String notificationSettingsUpdatedAtMsKey =
      'notification_settings_updated_at_ms';

  /// Loads the current preferences from persistent storage.
  ///
  /// Returns [ReminderPreferences.defaults] when nothing has been stored yet.
  Future<ReminderPreferences> load();

  /// Persists [prefs] to storage.
  Future<void> save(ReminderPreferences prefs);
}
