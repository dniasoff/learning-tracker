import 'package:drift/drift.dart';

/// Rewards table for gamification system.
///
/// curriculum_id is nullable to support global (cross-curriculum) rewards.
class Rewards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().withDefault(const Constant(0))();
  TextColumn get title => text()();
  TextColumn get description => text()();
  IntColumn get pointsThreshold => integer()();
  BoolColumn get isRevealed => boolean().withDefault(const Constant(false))();
  BoolColumn get isEarned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get earnedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get curriculumId => text().nullable()();

  /// 'specific' (single reward) or 'pool' (child picks from pool)
  TextColumn get rewardMode => text().withDefault(const Constant('specific'))();

  /// Milestone trigger: 'points', 'finish_masechta', 'finish_seder', 'every_n_items'
  TextColumn get milestoneType =>
      text().withDefault(const Constant('points'))();

  /// Whether the reward is visible to the child (vs surprise)
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();

  /// Links to reward_pools.id for pool-mode rewards
  IntColumn get poolId => integer().nullable()();

  /// For 'every_n_items' milestone type — triggers every N completions
  IntColumn get repeatInterval => integer().nullable()();
}
