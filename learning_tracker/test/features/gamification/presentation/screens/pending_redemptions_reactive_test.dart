@Tags(['gamification', 'staleness'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_redemption.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart';

RewardRedemptionEntity _redemption(String title) => RewardRedemptionEntity(
  ulid: '01J00000000000000000000013',
  rewardTitle: title,
  iconIndex: 0,
  pointsCost: 40,
  status: RewardRedemptionStatus.pendingFulfilment,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  test(
    'pending provider re-emits a new Firestore redemption without invalidation',
    () async {
      final controller = StreamController<List<RewardRedemptionEntity>>();
      final container = ProviderContainer(
        overrides: [
          pendingRedemptionsProvider.overrideWith((ref) => controller.stream),
        ],
      );
      addTearDown(controller.close);
      addTearDown(container.dispose);
      final values = <List<RewardRedemptionEntity>>[];
      final subscription = container
          .listen<AsyncValue<List<RewardRedemptionEntity>>>(
            pendingRedemptionsProvider,
            (_, next) => next.whenData(values.add),
            fireImmediately: true,
          );
      addTearDown(subscription.close);
      controller.add([_redemption('Ice Cream')]);
      await Future<void>.delayed(Duration.zero);
      expect(values.last.single.rewardTitle, 'Ice Cream');
    },
  );
}
