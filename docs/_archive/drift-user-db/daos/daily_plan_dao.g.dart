// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_plan_dao.dart';

// ignore_for_file: type=lint
mixin _$DailyPlanDaoMixin on DatabaseAccessor<UserDatabase> {
  $DailyPlansTable get dailyPlans => attachedDatabase.dailyPlans;
  DailyPlanDaoManager get managers => DailyPlanDaoManager(this);
}

class DailyPlanDaoManager {
  final _$DailyPlanDaoMixin _db;
  DailyPlanDaoManager(this._db);
  $$DailyPlansTableTableManager get dailyPlans =>
      $$DailyPlansTableTableManager(_db.attachedDatabase, _db.dailyPlans);
}
