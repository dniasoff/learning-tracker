import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/notifications/domain/services/reward_milestone_notification_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';

/// Provider for the [RewardMilestoneNotificationService] singleton.
///
/// Uses a manual provider (not @riverpod codegen) to avoid stale .g.dart
/// issues when the Refinery checks out branches.
final rewardMilestoneNotificationServiceProvider =
    Provider<RewardMilestoneNotificationService>((ref) {
      final notifService = ref.watch(notificationServiceProvider);
      return RewardMilestoneNotificationService(
        notificationService: notifService,
      );
    });
