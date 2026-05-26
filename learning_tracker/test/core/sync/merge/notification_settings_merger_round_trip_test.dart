/// WS5.clobber — Merger round-trip test for per-profile notification settings.
///
/// This is the **sync-crisis guard** for WS5 (2026-05-17 regression surface).
///
/// Test contract (write→push→pull→merge):
///   1. Two profiles with different notification settings.
///   2. Push profile A's settings via the merger.
///   3. Push profile B's settings via the merger (to same SharedPrefs).
///   4. Assert profile A's SharedPrefs keys still hold profile A's values.
///   5. Assert profile B's SharedPrefs keys hold profile B's values.
///
/// Passes iff there is zero cross-profile clobber:
///   merging profile B must NOT overwrite profile A's per-profile keys.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/notification_settings_merger.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Fake MergeStore (mirrors mergers_test.dart) ───────────────────────────────

class _FakeMergeStore implements MergeStore {
  final _timestamps = <String, Map<int, Map<String, DateTime?>>>{};
  final _syncedAt = <String, Map<int, Map<String, DateTime?>>>{};

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => _timestamps[kind]?[profileId]?[naturalKey];

  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => _syncedAt[kind]?[profileId]?[naturalKey];

  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) async {
    _timestamps
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        updatedAt;
    _syncedAt
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        syncedAt;
  }

  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) {
    if (remoteUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;
    return remoteUpdatedAt.isAfter(localUpdatedAt);
  }

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {}

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _buildRemoteRow({
  required bool reminderEnabled,
  required int hour,
  required int minute,
  required bool streakEnabled,
  required int streakHour,
  required int streakMinute,
  required bool rewardEnabled,
  required DateTime updatedAt,
}) {
  return {
    'updated_at': updatedAt.toIso8601String(),
    'daily_reminder': {
      'enabled': reminderEnabled,
      'hour': hour,
      'minute': minute,
    },
    'streak_alert': {
      'enabled': streakEnabled,
      'hour': streakHour,
      'minute': streakMinute,
    },
    'reward_notifications': {'enabled': rewardEnabled},
  };
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'WS5.clobber — NotificationSettingsMerger round-trip (2026-05-17 sync surface)',
    () {
      late _FakeMergeStore store;
      late NotificationSettingsMerger merger;

      setUp(() {
        SharedPreferences.setMockInitialValues({});
        store = _FakeMergeStore();
        merger = NotificationSettingsMerger(store: store);
      });

      test(
        'merge profile A then profile B — profile A keys are NOT overwritten',
        () async {
          const profileA = 1;
          const profileB = 2;

          final timeA = DateTime.utc(2026, 5, 24, 10);
          final timeB = DateTime.utc(2026, 5, 24, 11); // B is newer

          // Profile A: reminder at 8:30, streak disabled, reward on.
          final rowA = _buildRemoteRow(
            reminderEnabled: true,
            hour: 8,
            minute: 30,
            streakEnabled: false,
            streakHour: 20,
            streakMinute: 0,
            rewardEnabled: true,
            updatedAt: timeA,
          );

          // Profile B: reminder at 21:00, streak on, reward off — all different.
          final rowB = _buildRemoteRow(
            reminderEnabled: false,
            hour: 21,
            minute: 0,
            streakEnabled: true,
            streakHour: 22,
            streakMinute: 30,
            rewardEnabled: false,
            updatedAt: timeB,
          );

          // ── Push profile A ──────────────────────────────────────────────────
          await merger.merge(profileId: profileA, rows: [rowA]);

          // ── Push profile B ──────────────────────────────────────────────────
          await merger.merge(profileId: profileB, rows: [rowB]);

          final prefs = await SharedPreferences.getInstance();

          // ── Assert profile A's per-profile keys hold A's values ─────────────
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.reminderEnabledKey(profileA),
            ),
            isTrue,
            reason: 'Profile A reminderEnabled must remain true after B merged',
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.reminderHourKey(profileA),
            ),
            8,
            reason: 'Profile A reminderHour must remain 8 after B merged',
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.reminderMinuteKey(profileA),
            ),
            30,
            reason: 'Profile A reminderMinute must remain 30 after B merged',
          );
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.streakAlertEnabledKey(profileA),
            ),
            isFalse,
            reason: 'Profile A streakEnabled must remain false after B merged',
          );
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.rewardNotificationEnabledKey(
                profileA,
              ),
            ),
            isTrue,
            reason: 'Profile A rewardEnabled must remain true after B merged',
          );

          // ── Assert profile B's per-profile keys hold B's values ─────────────
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.reminderEnabledKey(profileB),
            ),
            isFalse,
            reason: 'Profile B reminderEnabled must be false',
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.reminderHourKey(profileB),
            ),
            21,
            reason: 'Profile B reminderHour must be 21',
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.reminderMinuteKey(profileB),
            ),
            0,
            reason: 'Profile B reminderMinute must be 0',
          );
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.streakAlertEnabledKey(profileB),
            ),
            isTrue,
            reason: 'Profile B streakEnabled must be true',
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.streakAlertHourKey(profileB),
            ),
            22,
            reason: 'Profile B streakHour must be 22',
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.streakAlertMinuteKey(profileB),
            ),
            30,
            reason: 'Profile B streakMinute must be 30',
          );
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.rewardNotificationEnabledKey(
                profileB,
              ),
            ),
            isFalse,
            reason: 'Profile B rewardEnabled must be false',
          );
        },
      );

      test(
        'merge profile B then profile A — profile B keys are NOT overwritten',
        () async {
          const profileA = 3;
          const profileB = 4;

          final timeB = DateTime.utc(2026, 5, 24, 9);
          final timeA = DateTime.utc(2026, 5, 24, 12); // A is newer

          final rowA = _buildRemoteRow(
            reminderEnabled: true,
            hour: 7,
            minute: 0,
            streakEnabled: true,
            streakHour: 21,
            streakMinute: 0,
            rewardEnabled: true,
            updatedAt: timeA,
          );
          final rowB = _buildRemoteRow(
            reminderEnabled: false,
            hour: 18,
            minute: 45,
            streakEnabled: false,
            streakHour: 19,
            streakMinute: 30,
            rewardEnabled: false,
            updatedAt: timeB,
          );

          // Merge in reverse order (B first, then A).
          await merger.merge(profileId: profileB, rows: [rowB]);
          await merger.merge(profileId: profileA, rows: [rowA]);

          final prefs = await SharedPreferences.getInstance();

          // Profile B must still hold B's values.
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.reminderEnabledKey(profileB),
            ),
            isFalse,
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.reminderHourKey(profileB),
            ),
            18,
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.reminderMinuteKey(profileB),
            ),
            45,
          );

          // Profile A must still hold A's values.
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.reminderEnabledKey(profileA),
            ),
            isTrue,
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.reminderHourKey(profileA),
            ),
            7,
          );
        },
      );

      test(
        'LWW: newer remote row for same profile wins over older local',
        () async {
          const profileId = 10;

          final oldTime = DateTime.utc(2026, 5, 24, 8);
          final newTime = DateTime.utc(2026, 5, 24, 14);

          // First merge (old settings).
          await merger.merge(
            profileId: profileId,
            rows: [
              _buildRemoteRow(
                reminderEnabled: true,
                hour: 8,
                minute: 0,
                streakEnabled: false,
                streakHour: 20,
                streakMinute: 0,
                rewardEnabled: false,
                updatedAt: oldTime,
              ),
            ],
          );

          // Second merge (newer settings — should win).
          await merger.merge(
            profileId: profileId,
            rows: [
              _buildRemoteRow(
                reminderEnabled: false,
                hour: 22,
                minute: 30,
                streakEnabled: true,
                streakHour: 21,
                streakMinute: 0,
                rewardEnabled: true,
                updatedAt: newTime,
              ),
            ],
          );

          final prefs = await SharedPreferences.getInstance();
          expect(
            prefs.getBool(
              NotificationPreferencesRepository.reminderEnabledKey(profileId),
            ),
            isFalse,
            reason: 'Newer remote row must win',
          );
          expect(
            prefs.getInt(
              NotificationPreferencesRepository.reminderHourKey(profileId),
            ),
            22,
          );
        },
      );

      test('LWW: older remote row does NOT overwrite newer local', () async {
        const profileId = 11;

        final newerLocalTime = DateTime.utc(2026, 5, 24, 16);
        final olderRemoteTime = DateTime.utc(2026, 5, 24, 9);

        // Simulate a local write by pre-seeding the MergeStore timestamp.
        store._timestamps
                .putIfAbsent('notification_settings', () => {})
                .putIfAbsent(profileId, () => {})['preferences'] =
            newerLocalTime;

        // Also seed the SharedPrefs with the "local" value.
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderEnabledKey(profileId): true,
          NotificationPreferencesRepository.reminderHourKey(profileId): 9,
          NotificationPreferencesRepository.reminderMinuteKey(profileId): 0,
        });

        // Try to merge an older remote row — must not overwrite.
        await merger.merge(
          profileId: profileId,
          rows: [
            _buildRemoteRow(
              reminderEnabled: false,
              hour: 6,
              minute: 0,
              streakEnabled: false,
              streakHour: 20,
              streakMinute: 0,
              rewardEnabled: false,
              updatedAt: olderRemoteTime,
            ),
          ],
        );

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(
            NotificationPreferencesRepository.reminderEnabledKey(profileId),
          ),
          isTrue,
          reason: 'Older remote must NOT overwrite newer local',
        );
        expect(
          prefs.getInt(
            NotificationPreferencesRepository.reminderHourKey(profileId),
          ),
          9,
          reason: 'Hour must remain at local value',
        );
      });
    },
  );
}
