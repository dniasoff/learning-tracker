import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_service.dart';

/// Provider for the RewardService singleton.
final rewardServiceProvider = Provider<RewardService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return RewardService(database);
});

/// Next unearned reward (lowest threshold).
final nextRewardProvider = FutureProvider<Reward?>((ref) async {
  final service = ref.watch(rewardServiceProvider);
  return service.getNextReward();
});

/// Progress toward next reward (0.0 to 1.0).
final rewardProgressProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(rewardServiceProvider);
  return service.getProgressToNextReward();
});

/// All earned rewards for history display.
final earnedRewardsProvider = FutureProvider<List<Reward>>((ref) async {
  final service = ref.watch(rewardServiceProvider);
  return service.getEarnedRewards();
});

/// All configured rewards.
final allRewardsProvider = FutureProvider<List<Reward>>((ref) async {
  final service = ref.watch(rewardServiceProvider);
  return service.getAllRewards();
});

/// Check and award rewards. Returns newly earned rewards.
final checkRewardsProvider = FutureProvider.family<List<Reward>, UserMode>((
  ref,
  userMode,
) async {
  final service = ref.watch(rewardServiceProvider);
  return service.checkAndAwardRewards(userMode: userMode);
});
