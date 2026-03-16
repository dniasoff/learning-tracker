import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';

/// Service for managing mystery rewards.
///
/// Rewards are earned by accumulating points. In child mode, rewards are
/// hidden ("Mystery Reward!") until a parent reveals them. In adult mode,
/// rewards are visible immediately upon earning.
class RewardService {
  final AppDatabase _database;

  RewardService(this._database);

  /// Get the next unearned reward (lowest threshold above current points or
  /// the lowest unearned regardless).
  Future<Reward?> getNextReward() async {
    final unearned = await _database.rewardDao.getUnearnedRewards();
    if (unearned.isEmpty) return null;
    return unearned.first; // Already ordered by pointsThreshold ascending
  }

  /// Calculate progress percentage toward the next unearned reward.
  ///
  /// Returns 0.0 if no unearned rewards exist.
  /// Returns a value between 0.0 and 1.0.
  Future<double> getProgressToNextReward() async {
    final next = await getNextReward();
    if (next == null) return 0.0;

    final globalPoints = await _getGlobalPoints();
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
  Future<List<Reward>> checkAndAwardRewards({
    required UserMode userMode,
  }) async {
    final globalPoints = await _getGlobalPoints();
    final unearned = await _database.rewardDao.getUnearnedRewards();
    final newlyEarned = <Reward>[];

    for (final reward in unearned) {
      if (globalPoints >= reward.pointsThreshold) {
        final now = DateTime.now();
        await _database.rewardDao.markEarned(reward.id, earnedAt: now);

        if (userMode == UserMode.adult) {
          await _database.rewardDao.revealReward(reward.id);
        }

        // Fetch updated reward
        final updated = await _database.rewardDao.getRewardById(reward.id);
        if (updated != null) newlyEarned.add(updated);
      }
    }

    return newlyEarned;
  }

  /// Reveal a mystery reward (parent action in child mode).
  Future<void> revealReward(int rewardId) async {
    await _database.rewardDao.revealReward(rewardId);
  }

  /// Get all earned rewards for display in history.
  Future<List<Reward>> getEarnedRewards() async {
    return _database.rewardDao.getEarnedRewards();
  }

  /// Get all configured rewards.
  Future<List<Reward>> getAllRewards() async {
    return _database.rewardDao.getAllRewards();
  }

  /// Add a new reward configuration.
  Future<int> addReward({
    required String title,
    required String description,
    required int pointsThreshold,
    String? curriculumId,
  }) async {
    return _database.rewardDao.insertReward(
      RewardsCompanion.insert(
        title: title,
        description: description,
        pointsThreshold: pointsThreshold,
        curriculumId: Value(curriculumId),
      ),
    );
  }

  Future<int> _getGlobalPoints() async {
    final completions = await _database.completionDao.getAllCompletions();
    return completions.fold<int>(0, (sum, c) => sum + c.points);
  }

  int _highestEarnedThreshold(List<Reward> earnedRewards) {
    return earnedRewards.fold<int>(
      0,
      (max, r) => r.pointsThreshold > max ? r.pointsThreshold : max,
    );
  }
}
