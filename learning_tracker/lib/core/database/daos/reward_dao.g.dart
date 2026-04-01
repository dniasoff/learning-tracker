// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_dao.dart';

// ignore_for_file: type=lint
mixin _$RewardDaoMixin on DatabaseAccessor<UserDatabase> {
  $RewardsTable get rewards => attachedDatabase.rewards;
  RewardDaoManager get managers => RewardDaoManager(this);
}

class RewardDaoManager {
  final _$RewardDaoMixin _db;
  RewardDaoManager(this._db);
  $$RewardsTableTableManager get rewards =>
      $$RewardsTableTableManager(_db.attachedDatabase, _db.rewards);
}
