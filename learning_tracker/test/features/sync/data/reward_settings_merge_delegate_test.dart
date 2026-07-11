/// Tests for [rewardSettingsMergeDelegateProvider] and its new
/// [rewardMilestoneServiceFactoryProvider] seam (AUD-sync-05, SM-7).
///
/// Before this fix, the delegate constructed [RewardMilestoneService]
/// directly inline, so a test could not substitute a fake without also
/// wiring a real [UserDatabase]. [RewardMilestoneService] construction now
/// lives in exactly one place — [rewardMilestoneServiceFactoryProvider] —
/// and [rewardSettingsMergeDelegateProvider] depends on that factory
/// instead. Overriding just the factory provider lets a test substitute a
/// fake service.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/sync/data/reward_settings_merge_delegate.dart';

void main() {
  group('rewardSettingsMergeDelegateProvider — factory seam (AUD-sync-05)', () {
    test(
      'the delegate calls the injected rewardMilestoneServiceFactory '
      'with the profile id it is given, not a self-constructed service',
      () async {
        final calls = <int>[];
        final mergedPayloads = <Map<String, dynamic>?>[];

        final container = ProviderContainer(
          overrides: [
            rewardMilestoneServiceFactoryProvider.overrideWithValue(({
              required int profileId,
            }) {
              calls.add(profileId);
              return _RecordingRewardMilestoneService(mergedPayloads);
            }),
          ],
        );
        addTearDown(container.dispose);

        final delegate = container.read(rewardSettingsMergeDelegateProvider);
        await delegate({'updated_at': '2026-05-29T00:00:00Z'}, 42);

        expect(
          calls,
          [42],
          reason:
              'the factory must be invoked with the delegate-supplied '
              'profile id',
        );
        expect(mergedPayloads, [
          {'updated_at': '2026-05-29T00:00:00Z'},
        ]);
      },
    );

    test(
      'a null remote payload is a no-op — the factory is never called',
      () async {
        final calls = <int>[];

        final container = ProviderContainer(
          overrides: [
            rewardMilestoneServiceFactoryProvider.overrideWithValue(({
              required int profileId,
            }) {
              calls.add(profileId);
              return _RecordingRewardMilestoneService([]);
            }),
          ],
        );
        addTearDown(container.dispose);

        final delegate = container.read(rewardSettingsMergeDelegateProvider);
        await delegate(null, 42);

        expect(calls, isEmpty);
      },
    );
  });
}

/// Records the payload handed to [mergeCloudPayload] instead of touching
/// SharedPreferences / Drift, so the test can assert on delegate behaviour
/// without wiring a real database.
class _RecordingRewardMilestoneService implements RewardMilestoneService {
  _RecordingRewardMilestoneService(this._sink);

  final List<Map<String, dynamic>?> _sink;

  @override
  Future<void> mergeCloudPayload(Map<String, dynamic>? remote) async {
    _sink.add(remote);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError();
  }
}
