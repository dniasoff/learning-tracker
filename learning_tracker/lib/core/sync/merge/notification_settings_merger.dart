import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LWW merger for the `notification_settings/preferences` Firestore document
/// (W2.27 / closes M1).
///
/// Notification settings are stored as a single Firestore document and written
/// to [SharedPreferences]. The row passed to [merge] is a synthetic single-
/// element list wrapping the document map (see [PullPipeline.pullDocument]).
///
/// Firestore shape (from SyncEngine._mergeNotificationSettings):
///   updated_at, daily_reminder.{enabled, hour, minute},
///   streak_alert.{enabled, hour, minute},
///   reward_notifications.{enabled}.
///
/// SharedPreferences keys match the SyncEngine constants so both old and new
/// sync paths share the same persisted values.
class NotificationSettingsMerger implements EntityMerger {
  const NotificationSettingsMerger();

  // SharedPreferences keys — must match SyncEngine constants.
  static const _updatedAtMsKey = 'notification_settings_updated_at_ms';
  static const _reminderEnabledKey = 'daily_reminder_enabled';
  static const _reminderHourKey = 'daily_reminder_hour';
  static const _reminderMinuteKey = 'daily_reminder_minute';
  static const _streakAlertEnabledKey = 'streak_alert_enabled';
  static const _streakAlertHourKey = 'streak_alert_hour';
  static const _streakAlertMinuteKey = 'streak_alert_minute';
  static const _rewardNotificationEnabledKey = 'reward_notification_enabled';

  @override
  String get kind => EntityKind.notificationSettings;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return;
    final remote = rows.first;
    if (remote.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final remoteUpdatedAt = _parseTimestamp(remote['updated_at']);
    final localMs = prefs.getInt(_updatedAtMsKey);
    final localUpdatedAt = localMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(localMs, isUtc: true);

    if (!remoteIsNewer(
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
    )) {
      return;
    }

    final dailyReminder =
        remote['daily_reminder'] as Map<String, dynamic>? ?? const {};
    final streakAlert =
        remote['streak_alert'] as Map<String, dynamic>? ?? const {};
    final rewardNotifications =
        remote['reward_notifications'] as Map<String, dynamic>? ?? const {};

    await prefs.setBool(
      _reminderEnabledKey,
      dailyReminder['enabled'] as bool? ?? true,
    );
    await prefs.setInt(_reminderHourKey, dailyReminder['hour'] as int? ?? 19);
    await prefs.setInt(
      _reminderMinuteKey,
      dailyReminder['minute'] as int? ?? 0,
    );

    await prefs.setBool(
      _streakAlertEnabledKey,
      streakAlert['enabled'] as bool? ?? true,
    );
    await prefs.setInt(_streakAlertHourKey, streakAlert['hour'] as int? ?? 21);
    await prefs.setInt(
      _streakAlertMinuteKey,
      streakAlert['minute'] as int? ?? 0,
    );

    await prefs.setBool(
      _rewardNotificationEnabledKey,
      rewardNotifications['enabled'] as bool? ?? true,
    );

    final stamp =
        remoteUpdatedAt?.millisecondsSinceEpoch ??
        DateTime.now().toUtc().millisecondsSinceEpoch;
    await prefs.setInt(_updatedAtMsKey, stamp);
  }

  DateTime? _parseTimestamp(Object? raw) => FirestoreCodec.parseDateTime(raw);
}
