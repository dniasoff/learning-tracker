import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
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
/// (WS5.clobber) SharedPreferences keys are per-profile namespaced via
/// [NotificationPreferencesRepository.keyForProfile], preventing cross-profile
/// clobber when multiple profiles sync on the same device.
///
/// Phase 3: the merger consults [MergeStore.remoteIsNewer] (which knows
/// about clock-skew arbitration), and after a successful apply calls
/// [MergeStore.persistUpdatedAt] so the persisted LWW timestamp survives
/// SharedPreferences resets. The SharedPreferences key is kept up to date
/// in parallel because the rest of the app uses it directly.
class NotificationSettingsMerger implements EntityMerger {
  const NotificationSettingsMerger({
    required MergeStore store,
    AppLogger? logger,
  }) : _store = store,
       _logger = logger;

  final MergeStore _store;
  // AUD-core-sync-15: optional logger so a merge failure is observable
  // instead of silently swallowed.
  final AppLogger? _logger;

  /// Single natural key — notification settings are a per-profile singleton.
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

    // AUD-core-sync-15: isolate this document's merge — a malformed/throwing
    // payload must not abort the whole sync pull step for other kinds.
    try {
      final prefs = await SharedPreferences.getInstance();
      final remoteUpdatedAt = _parseTimestamp(remote['updated_at']);
      final remoteSyncedAt = _parseTimestamp(remote['synced_at']);

      // (WS5.clobber) Local timestamp is read from the per-profile-namespaced
      // SyncKv table first, with a per-profile SharedPreferences fallback.
      var localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: _naturalKey,
      );
      if (localUpdatedAt == null) {
        final localMs = prefs.getInt(
          NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
            profileId,
          ),
        );
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

      // (WS5.clobber) Write to per-profile-namespaced keys so each profile's
      // notification settings are independently stored.
      await prefs.setBool(
        NotificationPreferencesRepository.reminderEnabledKey(profileId),
        dailyReminder['enabled'] as bool? ?? true,
      );
      await prefs.setInt(
        NotificationPreferencesRepository.reminderHourKey(profileId),
        dailyReminder['hour'] as int? ?? 19,
      );
      await prefs.setInt(
        NotificationPreferencesRepository.reminderMinuteKey(profileId),
        dailyReminder['minute'] as int? ?? 0,
      );

      await prefs.setBool(
        NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
        streakAlert['enabled'] as bool? ?? true,
      );
      await prefs.setInt(
        NotificationPreferencesRepository.streakAlertHourKey(profileId),
        streakAlert['hour'] as int? ?? 21,
      );
      await prefs.setInt(
        NotificationPreferencesRepository.streakAlertMinuteKey(profileId),
        streakAlert['minute'] as int? ?? 0,
      );

      await prefs.setBool(
        NotificationPreferencesRepository.rewardNotificationEnabledKey(
          profileId,
        ),
        rewardNotifications['enabled'] as bool? ?? true,
      );

      final stamp = remoteUpdatedAt ?? DateTimeFactory.nowUtc();
      await prefs.setInt(
        NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
          profileId,
        ),
        stamp.millisecondsSinceEpoch,
      );
      await _store.persistUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: _naturalKey,
        updatedAt: stamp,
        syncedAt: remoteSyncedAt,
      );
    } on Exception catch (e, stackTrace) {
      _logger?.warning(
        event: 'sync_notification_settings_merge_row_failed',
        fields: {'profile_id': profileId},
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  DateTime? _parseTimestamp(Object? raw) => FirestoreCodec.parseDateTime(raw);
}
