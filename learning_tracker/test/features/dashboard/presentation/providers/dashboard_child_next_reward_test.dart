/// Tests for [DashboardChildNextReward] model class.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';

void main() {
  group('DashboardChildNextReward', () {
    test('constructs with required fields', () {
      const reward = DashboardChildNextReward(
        trackId: 5,
        trackPoints: 150,
        threshold: 300,
        title: 'Silver Star',
      );
      expect(reward.trackId, 5);
      expect(reward.trackPoints, 150);
      expect(reward.threshold, 300);
      expect(reward.title, 'Silver Star');
      expect(reward.isGlobal, isFalse); // default value
    });

    test('isGlobal defaults to false', () {
      const reward = DashboardChildNextReward(
        trackId: 1,
        trackPoints: 0,
        threshold: 500,
        title: 'Bronze Star',
      );
      expect(reward.isGlobal, isFalse);
    });

    test('constructs with isGlobal = true for global milestone', () {
      const reward = DashboardChildNextReward(
        trackId: 0, // kGlobalTrackSentinel
        trackPoints: 900,
        threshold: 1000,
        title: 'Global Star',
        isGlobal: true,
      );
      expect(reward.isGlobal, isTrue);
      expect(reward.trackId, 0);
    });

    test('trackPoints can equal threshold', () {
      const reward = DashboardChildNextReward(
        trackId: 2,
        trackPoints: 500,
        threshold: 500,
        title: 'Bronze Star',
      );
      expect(reward.trackPoints, reward.threshold);
    });

    test('trackPoints can be 0', () {
      const reward = DashboardChildNextReward(
        trackId: 3,
        trackPoints: 0,
        threshold: 500,
        title: 'Bronze Star',
      );
      expect(reward.trackPoints, 0);
    });
  });
}
