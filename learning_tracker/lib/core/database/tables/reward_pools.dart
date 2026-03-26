import 'package:drift/drift.dart';

/// Reward pools — collections of rewards a child can choose from
/// when they hit a milestone.
class RewardPools extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get profileId => integer()();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
