import 'package:learning_tracker/features/notifications/domain/models/reminder_preferences.dart';

/// Repository interface for reading and writing [ReminderPreferences].
///
/// All key constants and defaults are encapsulated here (previously scattered
/// as private constants at the top of `notification_providers.dart`).
abstract class NotificationPreferencesRepository {
  /// Base SharedPreferences key fragments — never used directly as keys.
  /// Always call [keyForProfile] to get the per-profile namespaced key.
  static const String _reminderEnabledBase = 'daily_reminder_enabled';
  static const String _reminderHourBase = 'daily_reminder_hour';
  static const String _reminderMinuteBase = 'daily_reminder_minute';

  static const String _streakAlertEnabledBase = 'streak_alert_enabled';
  static const String _streakAlertHourBase = 'streak_alert_hour';
  static const String _streakAlertMinuteBase = 'streak_alert_minute';

  static const String _rewardNotificationEnabledBase =
      'reward_notification_enabled';

  static const String _notificationSettingsUpdatedAtMsBase =
      'notification_settings_updated_at_ms';

  // ---------------------------------------------------------------------------
  // Per-profile key namespacing (WS5.key-prefs)
  //
  // All SharedPreferences keys are suffixed with _<profileId> so that
  // different profiles on the same device store their notification prefs
  // independently. The plain (un-suffixed) key constants below exist only
  // as the base fragments; callers always use [keyForProfile].
  // ---------------------------------------------------------------------------

  /// Returns the per-profile namespaced SharedPreferences key for [baseKey].
  ///
  /// Example: `keyForProfile('daily_reminder_enabled', 42)` → `'daily_reminder_enabled_42'`.
  static String keyForProfile(String baseKey, int profileId) =>
      '${baseKey}_$profileId';

  // Per-profile key helpers — use these everywhere instead of the raw constants.

  static String reminderEnabledKey(int profileId) =>
      keyForProfile(_reminderEnabledBase, profileId);
  static String reminderHourKey(int profileId) =>
      keyForProfile(_reminderHourBase, profileId);
  static String reminderMinuteKey(int profileId) =>
      keyForProfile(_reminderMinuteBase, profileId);

  static String streakAlertEnabledKey(int profileId) =>
      keyForProfile(_streakAlertEnabledBase, profileId);
  static String streakAlertHourKey(int profileId) =>
      keyForProfile(_streakAlertHourBase, profileId);
  static String streakAlertMinuteKey(int profileId) =>
      keyForProfile(_streakAlertMinuteBase, profileId);

  static String rewardNotificationEnabledKey(int profileId) =>
      keyForProfile(_rewardNotificationEnabledBase, profileId);

  static String notificationSettingsUpdatedAtMsKey(int profileId) =>
      keyForProfile(_notificationSettingsUpdatedAtMsBase, profileId);

  /// Loads the current preferences from persistent storage.
  ///
  /// Returns [ReminderPreferences.defaults] when nothing has been stored yet.
  Future<ReminderPreferences> load();

  /// Persists [prefs] to storage.
  Future<void> save(ReminderPreferences prefs);
}
