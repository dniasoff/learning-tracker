import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/reward_pool_items.dart';
import 'package:learning_tracker/core/database/tables/reward_pools.dart';

part 'reward_pool_dao.g.dart';

/// DAO for reward pools and their items.
@DriftAccessor(tables: [RewardPools, RewardPoolItems])
class RewardPoolDao extends DatabaseAccessor<AppDatabase>
    with _$RewardPoolDaoMixin {
  RewardPoolDao(super.db);

  /// Get all pools for a profile (includes shared pools).
  Future<List<RewardPool>> getPoolsByProfile(int profileId) =>
      (select(rewardPools)
            ..where(
              (t) => t.profileId.equals(profileId) | t.isShared.equals(true),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  /// Get a pool by ID.
  Future<RewardPool?> getPoolById(int id) =>
      (select(rewardPools)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Create a new pool.
  Future<int> insertPool(RewardPoolsCompanion entry) =>
      into(rewardPools).insert(entry);

  /// Delete a pool and its items.
  Future<void> deletePool(int poolId) async {
    await (delete(rewardPoolItems)..where((t) => t.poolId.equals(poolId))).go();
    await (delete(rewardPools)..where((t) => t.id.equals(poolId))).go();
  }

  /// Get all items in a pool.
  Future<List<RewardPoolItem>> getPoolItems(int poolId) =>
      (select(rewardPoolItems)..where((t) => t.poolId.equals(poolId))).get();

  /// Get unused items in a pool.
  Future<List<RewardPoolItem>> getUnusedPoolItems(int poolId) => (select(
    rewardPoolItems,
  )..where((t) => t.poolId.equals(poolId) & t.isUsed.equals(false))).get();

  /// Add an item to a pool.
  Future<int> insertPoolItem(RewardPoolItemsCompanion entry) =>
      into(rewardPoolItems).insert(entry);

  /// Mark a pool item as used.
  Future<void> markItemUsed(int itemId) =>
      (update(rewardPoolItems)..where((t) => t.id.equals(itemId))).write(
        const RewardPoolItemsCompanion(isUsed: Value(true)),
      );

  /// Delete a pool item.
  Future<int> deletePoolItem(int itemId) =>
      (delete(rewardPoolItems)..where((t) => t.id.equals(itemId))).go();
}
