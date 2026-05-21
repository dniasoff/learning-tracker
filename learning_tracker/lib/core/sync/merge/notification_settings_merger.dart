import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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
///
/// Phase 3: the merger consults [MergeStore.remoteIsNewer] (which knows
/// about clock-skew arbitration), and after a successful apply calls
/// [MergeStore.persistUpdatedAt] so the persisted LWW timestamp survives
/// SharedPreferences resets. The SharedPreferences key is kept up to date
/// in parallel because the rest of the app uses it directly.
class NotificationSettingsMerger implements EntityMerger {
  const NotificationSettingsMerger({required MergeStore store})
    : _store = store;

  final MergeStore _store;

  // SharedPreferences keys — must match SyncEngine constants.
  static const _updatedAtMsKey = 'notification_settings_updated_at_ms';
  static const _reminderEnabledKey = 'daily_reminder_enabled';
  static const _reminderHourKey = 'daily_reminder_hour';
  static const _reminderMinuteKey = 'daily_reminder_minute';
  static const _streakAlertEnabledKey = 'streak_alert_enabled';
  static const _streakAlertHourKey = 'streak_alert_hour';
  static const _streakAlertMinuteKey = 'streak_alert_minute';
  static const _rewardNotificationEnabledKey = 'reward_notification_enabled';

  /// Single natural key — notification settings are a per-account singleton.
  static const _naturalKey = 'preferences';

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
    final remoteSyncedAt = _parseTimestamp(remote['synced_at']);
    // Local timestamp comes from the SyncKv table (authoritative) with a
    // SharedPreferences fallback to handle pre-Phase-3 installs.
    var localUpdatedAt = await _store.currentUpdatedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
    );
    if (localUpdatedAt == null) {
      final localMs = prefs.getInt(_updatedAtMsKey);
      if (localMs != null) {
        localUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
          localMs,
          isUtc: true,
        );
      }
    }
    final localSyncedAt = await _store.currentSyncedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
    );

    if (!_store.remoteIsNewer(
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
      localSyncedAt: localSyncedAt,
      remoteSyncedAt: remoteSyncedAt,
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

    final stamp = remoteUpdatedAt ?? DateTimeFactory.nowUtc();
    await prefs.setInt(_updatedAtMsKey, stamp.millisecondsSinceEpoch);
    await _store.persistUpdatedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
      updatedAt: stamp,
      syncedAt: remoteSyncedAt,
    );
  }

  DateTime? _parseTimestamp(Object? raw) => FirestoreCodec.parseDateTime(raw);
}
