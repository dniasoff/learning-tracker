import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_model.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';

/// Service for showing instant notifications when reward milestones are reached.
///
/// Fires immediately (not scheduled) when points cross a reward threshold.
/// Message varies by user mode: child mode hides the reward title.
class RewardMilestoneNotificationService {
  RewardMilestoneNotificationService({
    required NotificationService notificationService,
  }) : _notificationService = notificationService;

  final NotificationService _notificationService;

  /// Show a notification for each newly earned reward.
  ///
  /// Called after [RewardService.checkAndAwardRewards] returns newly earned
  /// rewards. Only fires for rewards just earned (not on app restart).
  Future<void> notifyNewRewards({
    required List<RewardModel> newlyEarned,
    required UserMode userMode,
  }) async {
    for (final reward in newlyEarned) {
      final body = buildBody(reward: reward, userMode: userMode);
      await _notificationService.showRewardMilestone(body: body);
    }
  }

  /// Build the notification body based on user mode.
  ///
  /// Child mode: "Mystery reward earned!" (hides title)
  /// Adult mode: "Reward earned: [title]"
  static String buildBody({
    required RewardModel reward,
    required UserMode userMode,
  }) {
    if (userMode == UserMode.child) {
      return 'Mystery reward earned!';
    }
    return 'Reward earned: ${reward.title}';
  }
}
