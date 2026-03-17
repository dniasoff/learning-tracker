import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_model.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/tutor_mode/domain/tutor_mode_provider.dart';

/// Service for managing mystery rewards.
///
/// Rewards are earned by accumulating points. In child mode, rewards are
/// hidden ("Mystery Reward!") until a parent reveals them. In adult mode,
/// rewards are visible immediately upon earning.
class RewardService {
  final AppDatabase _database;
  final PointsService _pointsService;
  final bool isTutorMode;

  RewardService(
    this._database,
    this._pointsService, {
    this.isTutorMode = false,
  });

  /// Get the next unearned reward (lowest threshold above current points or
  /// the lowest unearned regardless).
  Future<RewardModel?> getNextReward() async {
    final unearned = await _database.rewardDao.getUnearnedRewards();
    if (unearned.isEmpty) return null;
    return RewardModel.fromDriftRow(unearned.first);
  }

  /// Calculate progress percentage toward the next unearned reward.
  ///
  /// Returns 0.0 if no unearned rewards exist.
  /// Returns a value between 0.0 and 1.0.
  Future<double> getProgressToNextReward() async {
    final next = await getNextReward();
    if (next == null) return 0.0;

    final globalPoints = await _pointsService.getGlobalTotal();
    // Find the previous earned threshold as the base
    final earned = await _database.rewardDao.getEarnedRewards();
    final base = earned.isEmpty ? 0 : _highestEarnedThreshold(earned);

    final range = next.pointsThreshold - base;
    if (range <= 0) return 1.0;

    final progress = (globalPoints - base) / range;
    return progress.clamp(0.0, 1.0);
  }

  /// Check all reward thresholds against current global points and mark
  /// any newly earned rewards.
  ///
  /// In adult mode, rewards are automatically revealed on earning.
  /// Returns list of newly earned rewards.
  Future<List<RewardModel>> checkAndAwardRewards({
    required UserMode userMode,
  }) async {
    final globalPoints = await _pointsService.getGlobalTotal();
    final unearned = await _database.rewardDao.getUnearnedRewards();
    final newlyEarned = <RewardModel>[];

    for (final reward in unearned) {
      if (globalPoints >= reward.pointsThreshold) {
        final now = DateTime.now().toUtc();
        await _database.rewardDao.markEarned(reward.id, earnedAt: now);

        if (userMode == UserMode.adult) {
          await _database.rewardDao.revealReward(reward.id);
        }

        // Fetch updated reward
        final updated = await _database.rewardDao.getRewardById(reward.id);
        if (updated != null) newlyEarned.add(RewardModel.fromDriftRow(updated));
      }
    }

    return newlyEarned;
  }

  /// Reveal a mystery reward (parent action in child mode).
  ///
  /// Throws [TutorModeReadOnlyException] if tutor mode is active.
  Future<void> revealReward(int rewardId) async {
    guardTutorModeWriteFromBool(isTutorMode);
    await _database.rewardDao.revealReward(rewardId);
  }

  /// Get all earned rewards for display in history.
  Future<List<RewardModel>> getEarnedRewards() async {
    final rows = await _database.rewardDao.getEarnedRewards();
    return rows.map(RewardModel.fromDriftRow).toList();
  }

  /// Get all configured rewards.
  Future<List<RewardModel>> getAllRewards() async {
    final rows = await _database.rewardDao.getAllRewards();
    return rows.map(RewardModel.fromDriftRow).toList();
  }

  /// Add a new reward configuration.
  ///
  /// Throws [TutorModeReadOnlyException] if tutor mode is active.
  Future<int> addReward({
    required String title,
    required String description,
    required int pointsThreshold,
    String? curriculumId,
  }) async {
    guardTutorModeWriteFromBool(isTutorMode);
    return _database.rewardDao.insertReward(
      RewardsCompanion.insert(
        title: title,
        description: description,
        pointsThreshold: pointsThreshold,
        curriculumId: Value(curriculumId),
      ),
    );
  }

  /// Update an existing reward (only allowed for unearned rewards).
  ///
  /// Throws [TutorModeReadOnlyException] if tutor mode is active.
  Future<void> updateReward({
    required int id,
    required String title,
    required String description,
    required int pointsThreshold,
  }) async {
    guardTutorModeWriteFromBool(isTutorMode);
    final reward = await _database.rewardDao.getRewardById(id);
    if (reward == null) return;
    if (reward.isEarned) {
      throw StateError('Cannot edit an earned reward');
    }
    await _database.rewardDao.updateReward(
      RewardsCompanion(
        id: Value(id),
        title: Value(title),
        description: Value(description),
        pointsThreshold: Value(pointsThreshold),
      ),
    );
  }

  /// Delete a reward (only allowed for unearned rewards).
  ///
  /// Throws [TutorModeReadOnlyException] if tutor mode is active.
  Future<void> deleteReward(int id) async {
    guardTutorModeWriteFromBool(isTutorMode);
    final reward = await _database.rewardDao.getRewardById(id);
    if (reward == null) return;
    if (reward.isEarned) {
      throw StateError('Cannot delete an earned reward');
    }
    await _database.rewardDao.deleteReward(id);
  }

  int _highestEarnedThreshold(List<Reward> earnedRewards) {
    final sorted = [...earnedRewards]
      ..sort((a, b) => b.pointsThreshold.compareTo(a.pointsThreshold));
    return sorted.first.pointsThreshold;
  }
}
