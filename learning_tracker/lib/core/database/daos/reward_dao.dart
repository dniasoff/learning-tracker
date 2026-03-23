import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/rewards.dart';

part 'reward_dao.g.dart';

/// DAO for the rewards table.
@DriftAccessor(tables: [Rewards])
class RewardDao extends DatabaseAccessor<AppDatabase> with _$RewardDaoMixin {
  RewardDao(super.db);

  /// Get all rewards ordered by point threshold ascending.
  Future<List<Reward>> getAllRewards() => (select(
    rewards,
  )..orderBy([(t) => OrderingTerm.asc(t.pointsThreshold)])).get();

  // ========== Profile-Scoped Queries ==========

  /// Get all rewards for a specific profile.
  Future<List<Reward>> getRewardsByProfile(int profileId) =>
      (select(rewards)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.asc(t.pointsThreshold)]))
          .get();

  /// Get earned rewards for a specific profile.
  Future<List<Reward>> getEarnedRewardsByProfile(int profileId) =>
      (select(rewards)
            ..where(
              (t) => t.profileId.equals(profileId) & t.isEarned.equals(true),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.earnedAt)]))
          .get();

  /// Watch all rewards for a specific profile.
  Stream<List<Reward>> watchRewardsByProfile(int profileId) =>
      (select(rewards)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.asc(t.pointsThreshold)]))
          .watch();

  /// Get a single reward by ID.
  Future<Reward?> getRewardById(int id) =>
      (select(rewards)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get all earned rewards ordered by earnedAt descending.
  Future<List<Reward>> getEarnedRewards() =>
      (select(rewards)
            ..where((t) => t.isEarned.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.earnedAt)]))
          .get();

  /// Get all unearned rewards ordered by point threshold ascending.
  Future<List<Reward>> getUnearnedRewards() =>
      (select(rewards)
            ..where((t) => t.isEarned.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.pointsThreshold)]))
          .get();

  /// Insert a new reward.
  Future<int> insertReward(RewardsCompanion entry) =>
      into(rewards).insert(entry);

  /// Update an existing reward.
  Future<int> updateReward(RewardsCompanion entry) =>
      (update(rewards)..where((t) => t.id.equals(entry.id.value))).write(entry);

  /// Mark a reward as earned.
  Future<void> markEarned(int id, {required DateTime earnedAt}) =>
      (update(rewards)..where((t) => t.id.equals(id))).write(
        RewardsCompanion(
          isEarned: const Value(true),
          earnedAt: Value(earnedAt),
        ),
      );

  /// Reveal a reward (parent reveals mystery reward).
  Future<void> revealReward(int id) =>
      (update(rewards)..where((t) => t.id.equals(id))).write(
        const RewardsCompanion(isRevealed: Value(true)),
      );

  /// Delete a reward by ID.
  Future<int> deleteReward(int id) =>
      (delete(rewards)..where((t) => t.id.equals(id))).go();

  /// Watch all rewards for reactive UI updates.
  Stream<List<Reward>> watchAllRewards() => (select(
    rewards,
  )..orderBy([(t) => OrderingTerm.asc(t.pointsThreshold)])).watch();

  /// Upsert a reward by title (last-write-wins per D4).
  ///
  /// Matches by [title]. Inserts if not found, or updates using LWW on
  /// [updatedAt], falling back to most-progress-wins when timestamps are equal.
  Future<void> upsertReward({
    required String title,
    required String description,
    required int pointsThreshold,
    required bool isRevealed,
    required bool isEarned,
    required DateTime? earnedAt,
    required DateTime createdAt,
    required DateTime? updatedAt,
    required String? curriculumId,
  }) async {
    final existing = await (select(
      rewards,
    )..where((t) => t.title.equals(title))).getSingleOrNull();

    final effectiveUpdatedAt = updatedAt ?? createdAt;

    if (existing == null) {
      await insertReward(
        RewardsCompanion.insert(
          title: title,
          description: description,
          pointsThreshold: pointsThreshold,
          isRevealed: Value(isRevealed),
          isEarned: Value(isEarned),
          earnedAt: Value(earnedAt),
          createdAt: Value(createdAt),
          updatedAt: Value(effectiveUpdatedAt),
          curriculumId: Value(curriculumId),
        ),
      );
    } else {
      // LWW: only update if remote is newer
      final remoteIsNewer = effectiveUpdatedAt.isAfter(existing.updatedAt);
      // Fallback: most-progress-wins when timestamps are equal
      final sameTime = effectiveUpdatedAt.isAtSameMomentAs(existing.updatedAt);
      final moreProgress =
          isEarned && !existing.isEarned || isRevealed && !existing.isRevealed;

      if (remoteIsNewer || (sameTime && moreProgress)) {
        await (update(rewards)..where((t) => t.id.equals(existing.id))).write(
          RewardsCompanion(
            isRevealed: Value(isRevealed || existing.isRevealed),
            isEarned: Value(isEarned || existing.isEarned),
            earnedAt: Value(earnedAt ?? existing.earnedAt),
            updatedAt: Value(effectiveUpdatedAt),
          ),
        );
      }
    }
  }
}
