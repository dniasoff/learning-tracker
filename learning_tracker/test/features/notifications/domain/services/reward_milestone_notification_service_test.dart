import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_model.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/reward_milestone_notification_service.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockNotificationService mockNotificationService;
  late RewardMilestoneNotificationService service;

  setUp(() {
    mockNotificationService = MockNotificationService();
    service = RewardMilestoneNotificationService(
      notificationService: mockNotificationService,
    );
  });

  RewardModel makeReward({String title = 'Gold Star', int threshold = 100}) {
    return RewardModel(
      id: 1,
      title: title,
      description: 'A reward',
      pointsThreshold: threshold,
      isEarned: true,
      isRevealed: false,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('RewardMilestoneNotificationService', () {
    group('buildBody', () {
      test('returns mystery message for child mode', () {
        final reward = makeReward();
        final body = RewardMilestoneNotificationService.buildBody(
          reward: reward,
          userMode: UserMode.child,
        );
        expect(body, 'Mystery reward earned!');
      });

      test('returns reward title for adult mode', () {
        final reward = makeReward(title: 'Silver Medal');
        final body = RewardMilestoneNotificationService.buildBody(
          reward: reward,
          userMode: UserMode.adult,
        );
        expect(body, 'Reward earned: Silver Medal');
      });
    });

    group('notifyNewRewards', () {
      test('shows notification for each newly earned reward', () async {
        when(
          () => mockNotificationService.showRewardMilestone(
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});

        final rewards = [
          makeReward(title: 'Reward A'),
          makeReward(title: 'Reward B'),
        ];

        await service.notifyNewRewards(
          newlyEarned: rewards,
          userMode: UserMode.adult,
        );

        verify(
          () => mockNotificationService.showRewardMilestone(
            body: 'Reward earned: Reward A',
          ),
        ).called(1);
        verify(
          () => mockNotificationService.showRewardMilestone(
            body: 'Reward earned: Reward B',
          ),
        ).called(1);
      });

      test('does nothing when list is empty', () async {
        await service.notifyNewRewards(
          newlyEarned: [],
          userMode: UserMode.adult,
        );

        verifyNever(
          () => mockNotificationService.showRewardMilestone(
            body: any(named: 'body'),
          ),
        );
      });
    });
  });
}
