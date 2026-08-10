/// Unit tests for [GamificationSettingsMerger]: the onRewardSettings
/// callback wiring, plus Phase-3 LWW symmetry and persistUpdatedAt against
/// a real [DriftMergeStore].
///
/// AG-5 (AUD-app-05): consolidates
/// test/sync/merge/gamification_reward_merge_test.dart,
/// test/sync/merge/lww_symmetric_test.dart's GamificationSettingsMerger
/// group, and test/sync/merge/persist_updated_at_test.dart's
/// GamificationSettingsMerger case into the single file mirroring
/// lib/core/sync/merge/gamification_settings_merger.dart.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/gamification_settings_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

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

  group('GamificationSettingsMerger.onRewardSettings wiring', () {
    late UserDatabase db;
    late DriftMergeStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      await seedProfile(db);
      store = DriftMergeStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'reward_settings sub-map is forwarded to the injected callback',
      () async {
        final calls = <_RewardCall>[];
        final merger = GamificationSettingsMerger(
          db: db,
          store: store,
          onRewardSettings: (remote, profileId) async {
            calls.add(_RewardCall(remote, profileId));
          },
        );

        final rewardSettings = <String, Object?>{
          'milestones': const <Map<String, Object?>>[
            {'id': 'm1', 'title': 'Bronze', 'threshold_points': 100},
          ],
        };

        await merger.merge(
          profileId: 1,
          rows: [
            {
              'updated_at': DateTime.utc(2026, 5, 21).toIso8601String(),
              'synced_at': DateTime.utc(2026, 5, 21).toIso8601String(),
              'points_config': const <Map<String, Object?>>[],
              'reward_settings': rewardSettings,
            },
          ],
        );

        expect(calls, hasLength(1));
        expect(calls.single.profileId, 1);
        expect(calls.single.remote, isNotNull);
        expect(calls.single.remote!['milestones'], isA<List<dynamic>>());
      },
    );

    test('remote without reward_settings → callback receives null', () async {
      final calls = <_RewardCall>[];
      final merger = GamificationSettingsMerger(
        db: db,
        store: store,
        onRewardSettings: (remote, profileId) async {
          calls.add(_RewardCall(remote, profileId));
        },
      );

      await merger.merge(
        profileId: 1,
        rows: [
          {
            'updated_at': DateTime.utc(2026, 5, 21).toIso8601String(),
            'synced_at': DateTime.utc(2026, 5, 21).toIso8601String(),
            'points_config': const <Map<String, Object?>>[],
            // no reward_settings
          },
        ],
      );

      expect(calls, hasLength(1));
      expect(calls.single.remote, isNull);
    });

    test('merger drops a remote whose updated_at is older than local — '
        'callback NOT invoked', () async {
      final calls = <_RewardCall>[];
      final merger = GamificationSettingsMerger(
        db: db,
        store: store,
        onRewardSettings: (remote, profileId) async {
          calls.add(_RewardCall(remote, profileId));
        },
      );

      // Seed local newer than remote.
      await store.persistUpdatedAt(
        kind: EntityKind.gamificationSettings,
        profileId: 1,
        naturalKey: 'config',
        updatedAt: DateTime.utc(2026, 5, 21),
      );

      await merger.merge(
        profileId: 1,
        rows: [
          {
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'points_config': const <Map<String, Object?>>[],
            'reward_settings': const <String, Object?>{
              'milestones': <Map<String, Object?>>[],
            },
          },
        ],
      );

      expect(
        calls,
        isEmpty,
        reason: 'merger must drop the remote before calling onRewardSettings',
      );
    });
  });

  group(
    'GamificationSettingsMerger — LWW symmetry + persistence (real DriftMergeStore)',
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

      group('GamificationSettingsMerger', () {
        late GamificationSettingsMerger merger;

        setUp(() {
          merger = GamificationSettingsMerger(
            db: db,
            store: store,
            onRewardSettings: null,
          );
        });

        Map<String, dynamic> row({
          required DateTime updatedAt,
          DateTime? syncedAt,
        }) => {
          'updated_at': updatedAt.toIso8601String(),
          if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
          'points_config': const <Map<String, Object?>>[],
        };

        test('remote newer than local → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.gamificationSettings,
            profileId: profileId,
            naturalKey: 'config',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.gamificationSettings,
            profileId: profileId,
            naturalKey: 'config',
          );
          expect(after, _remoteNewer);
        });

        test('local newer than remote → does NOT apply', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.gamificationSettings,
            profileId: profileId,
            naturalKey: 'config',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.gamificationSettings,
            profileId: profileId,
            naturalKey: 'config',
          );
          expect(after, _local);
        });
      });

      test('GamificationSettingsMerger', () async {
        await GamificationSettingsMerger(
          db: db,
          store: store,
          onRewardSettings: null,
        ).merge(
          profileId: _profileId,
          rows: [
            {
              'updated_at': _ts.toIso8601String(),
              'synced_at': _syncedAt.toIso8601String(),
              'points_config': const <Map<String, Object?>>[],
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.gamificationSettings,
          profileId: _profileId,
          naturalKey: 'config',
        );
        expect(updatedAt, _ts);
      });
    },
  );
}

class _RewardCall {
  _RewardCall(this.remote, this.profileId);
  final Map<String, dynamic>? remote;
  final int profileId;
}
