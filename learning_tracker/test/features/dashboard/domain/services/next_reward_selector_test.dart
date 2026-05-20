import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/dashboard/domain/services/next_reward_selector.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';

RewardMilestone _milestone({
  required int threshold,
  required String title,
  bool isEnabled = true,
  int trackId = 1,
}) => RewardMilestone(
  id: 'm_$title',
  profileId: 1,
  trackId: trackId,
  title: title,
  thresholdPoints: threshold,
  isEnabled: isEnabled,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  const selector = NextRewardSelector();

  group('NextRewardSelector', () {
    test('returns null when no milestones', () {
      final result = selector.select(
        trackEntries: [],
        globalPoints: 0,
        globalMilestones: [],
      );
      expect(result, isNull);
    });

    test('returns null when all milestones already earned', () {
      final result = selector.select(
        trackEntries: [
          TrackMilestoneEntry(
            trackId: 1,
            points: 100,
            milestones: [_milestone(threshold: 50, title: 'A')],
          ),
        ],
        globalPoints: 200,
        globalMilestones: [_milestone(threshold: 100, title: 'G')],
      );
      expect(result, isNull);
    });

    test('picks single unearned milestone', () {
      final result = selector.select(
        trackEntries: [
          TrackMilestoneEntry(
            trackId: 1,
            points: 30,
            milestones: [_milestone(threshold: 50, title: 'Bicycle')],
          ),
        ],
        globalPoints: 0,
        globalMilestones: [],
      );
      expect(result, isNotNull);
      expect(result!.title, 'Bicycle');
      expect(result.trackId, 1);
      expect(result.trackPoints, 30);
      expect(result.threshold, 50);
      expect(result.isGlobal, isFalse);
    });

    test('picks closest gap milestone across per-track', () {
      final result = selector.select(
        trackEntries: [
          TrackMilestoneEntry(
            trackId: 1,
            points: 40,
            milestones: [
              _milestone(threshold: 100, title: 'Far'), // gap 60
              _milestone(threshold: 50, title: 'Close'), // gap 10
            ],
          ),
        ],
        globalPoints: 0,
        globalMilestones: [],
      );
      expect(result!.title, 'Close');
    });

    test('picks global milestone when it is closer than per-track', () {
      final result = selector.select(
        trackEntries: [
          TrackMilestoneEntry(
            trackId: 1,
            points: 0,
            milestones: [_milestone(threshold: 100, title: 'TrackBig')],
          ),
        ],
        globalPoints: 90,
        globalMilestones: [
          _milestone(
            threshold: 100,
            title: 'GlobalClose',
            trackId: 0,
          ), // gap 10
        ],
      );
      expect(result!.title, 'GlobalClose');
      expect(result.isGlobal, isTrue);
      expect(result.trackId, RewardMilestone.kGlobalTrackSentinel);
    });

    test('skips disabled milestones', () {
      final result = selector.select(
        trackEntries: [
          TrackMilestoneEntry(
            trackId: 1,
            points: 0,
            milestones: [
              _milestone(threshold: 10, title: 'Disabled', isEnabled: false),
              _milestone(threshold: 50, title: 'Enabled'),
            ],
          ),
        ],
        globalPoints: 0,
        globalMilestones: [],
      );
      expect(result!.title, 'Enabled');
    });

    test('skips earned milestones but returns next one', () {
      final result = selector.select(
        trackEntries: [
          TrackMilestoneEntry(
            trackId: 1,
            points: 60,
            milestones: [
              _milestone(threshold: 50, title: 'Earned'),
              _milestone(threshold: 100, title: 'Next'),
            ],
          ),
        ],
        globalPoints: 0,
        globalMilestones: [],
      );
      expect(result!.title, 'Next');
    });
  });
}
