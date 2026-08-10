/// Unit tests for [NotificationSettingsMerger]: WS5.clobber cross-profile
/// round-trip regression (fake store), plus Phase-3 LWW symmetry and
/// persistUpdatedAt against a real [DriftMergeStore].
///
/// AG-5 (AUD-app-05): renamed/consolidated from
/// test/core/sync/merge/notification_settings_merger_round_trip_test.dart
/// (era-2 fake-store suite, kept as-is) plus
/// test/sync/merge/lww_symmetric_test.dart's NotificationSettingsMerger
/// group and test/sync/merge/persist_updated_at_test.dart's
/// NotificationSettingsMerger case, into the single file mirroring
/// lib/core/sync/merge/notification_settings_merger.dart.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/notification_settings_merger.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/firestore_fake.dart';
import '../../../helpers/test_database.dart';
import '../../../mocks/mock_repositories.dart';

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

  @override
  Future<T> runInTransaction<T>(Future<T> Function() body) => body();
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

// ── Phase 3 LWW-symmetry / persistUpdatedAt fixtures ────────────────────────
final _local = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteNewer = DateTime.utc(2026, 5, 21, 13, 0, 0);
final _remoteOlder = DateTime.utc(2026, 5, 21, 11, 0, 0);
const _profileId = 1;
final _ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _syncedAt = DateTime.utc(2026, 5, 21, 12, 0, 30);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── WS5.clobber fake-store round-trip (era-2) ────────────────────────────

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

  group(
    'NotificationSettingsMerger — LWW symmetry + persistence (real DriftMergeStore)',
    () {
      late UserDatabase db;
      late DriftMergeStore store;
      const profileId = 1;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        db = UserDatabase(NativeDatabase.memory());
        await seedProfile(db);
        store = DriftMergeStore(db);
      });

      tearDown(() async {
        await db.close();
      });

      group('NotificationSettingsMerger', () {
        late NotificationSettingsMerger merger;

        setUp(() {
          merger = NotificationSettingsMerger(store: store);
        });

        Map<String, dynamic> row({
          required DateTime updatedAt,
          DateTime? syncedAt,
        }) => {
          'updated_at': updatedAt.toIso8601String(),
          if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
          'daily_reminder': {'enabled': true, 'hour': 7, 'minute': 30},
        };

        test('remote newer than local → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.notificationSettings,
            profileId: profileId,
            naturalKey: 'preferences',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.notificationSettings,
            profileId: profileId,
            naturalKey: 'preferences',
          );
          expect(after, _remoteNewer);
        });

        test('local newer than remote → does NOT apply', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.notificationSettings,
            profileId: profileId,
            naturalKey: 'preferences',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.notificationSettings,
            profileId: profileId,
            naturalKey: 'preferences',
          );
          expect(after, _local);
        });
      });

      test('NotificationSettingsMerger', () async {
        await NotificationSettingsMerger(store: store).merge(
          profileId: _profileId,
          rows: [
            {
              'updated_at': _ts.toIso8601String(),
              'synced_at': _syncedAt.toIso8601String(),
              'daily_reminder': {'enabled': true, 'hour': 7, 'minute': 30},
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.notificationSettings,
          profileId: _profileId,
          naturalKey: 'preferences',
        );
        expect(updatedAt, _ts);
      });
    },
  );

  // ── AUD-notifications-07 — clock-skew push→merge integration ────────────
  //
  // Full push (FirestoreGatewayImpl) → pull (NotificationSettingsMerger)
  // round trip proving the genuinely-later settings write wins over a push
  // from a device whose local clock lied about being in the future, exactly
  // the scenario the finding describes: "the device with the faster/wrong
  // clock can push a stale settings change that looks 'newer' and wins over
  // a genuinely newer change made on a correctly-clocked device, silently
  // reverting the user's real edit".
  group('FB-2 (AUD-notifications-07) — a fast/skewed-clock push does not '
      'clobber a genuinely later local edit', () {
    const uid = 'uid_clock_skew_test';
    const profileId = 99;

    test(
      'stale push claiming a far-future updated_at loses to a genuinely '
      'later local edit once pushNotificationSettings server-stamps it',
      () async {
        SharedPreferences.setMockInitialValues({});

        final auth = MockAuthRepository();
        when(() => auth.currentUser).thenReturn(
          const AppUser(
            uid: uid,
            email: 'skew@example.com',
            displayName: 'Skew',
            emailVerified: true,
            providers: ['password'],
          ),
        );
        final fs = createFakeFirestore(authenticatedUid: uid);
        final gateway = FirestoreGatewayImpl(
          firestore: fs,
          authRepository: auth,
        );

        // 1. A device with a badly fast/skewed clock pushes a STALE
        //    settings change, claiming (via its own client clock) that it
        //    happened in the year 2099.
        await gateway.pushNotificationSettings(
          profileId: profileId,
          data: {
            'updated_at': DateTime.utc(2099).toIso8601String(),
            'daily_reminder': {'enabled': false, 'hour': 6, 'minute': 0},
            'streak_alert': {'enabled': false, 'hour': 20, 'minute': 0},
            'reward_notifications': {'enabled': false},
          },
        );

        // Read the pushed document back exactly as the sync pull pipeline
        // does (fetchDocument normalises any Firestore Timestamp to an
        // ISO-8601 string — see FirestoreGatewayImpl._normalizeRow).
        final staleRemoteRow = await gateway.fetchDocument(
          profileId: profileId,
          collection: 'preferences',
          docId: 'notification_settings',
        );
        expect(staleRemoteRow, isNotNull);

        // 2. THIS device made its own genuinely later edit — reminders on
        //    at 07:30 — which already settled locally (real time, after
        //    the push above committed) before the stale row is merged in.
        final store = _FakeMergeStore();
        final localEditAt = DateTime.now().toUtc();
        store._timestamps
                .putIfAbsent('notification_settings', () => {})
                .putIfAbsent(profileId, () => {})['preferences'] =
            localEditAt;
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderEnabledKey(profileId): true,
          NotificationPreferencesRepository.reminderHourKey(profileId): 7,
          NotificationPreferencesRepository.reminderMinuteKey(profileId): 30,
        });

        // 3. Pull/merge the stale remote row into this device.
        final merger = NotificationSettingsMerger(store: store);
        await merger.merge(profileId: profileId, rows: [staleRemoteRow!]);

        // 4. The genuinely later local edit must survive: the fast-clock
        //    device's fabricated 2099 claim must NOT have won, because
        //    pushNotificationSettings overwrote it with a real server
        //    Timestamp (effectively "now", which is earlier than
        //    localEditAt).
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(
            NotificationPreferencesRepository.reminderEnabledKey(profileId),
          ),
          isTrue,
          reason:
              'the genuinely later local edit must not be clobbered by a '
              'stale push whose device clock lied about the time',
        );
        expect(
          prefs.getInt(
            NotificationPreferencesRepository.reminderHourKey(profileId),
          ),
          7,
        );
        expect(
          prefs.getInt(
            NotificationPreferencesRepository.reminderMinuteKey(profileId),
          ),
          30,
        );
      },
    );
  });
}
