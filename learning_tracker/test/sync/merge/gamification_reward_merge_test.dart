/// Phase 3: assert [GamificationSettingsMerger] invokes the
/// `onRewardSettings` callback after a successful apply, so the
/// reward-milestones sub-map propagates from device A to device B.
///
/// The wiring previously had `onRewardSettings: null` (the override
/// promised in W2.31 never landed), silently dropping reward-milestone
/// deltas pulled from the cloud. Phase 3 wires it via
/// [rewardSettingsMergeDelegateProvider] in features/sync.
@Tags(['gamification_reward_merge'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/gamification_settings_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

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
}

class _RewardCall {
  _RewardCall(this.remote, this.profileId);
  final Map<String, dynamic>? remote;
  final int profileId;
}
