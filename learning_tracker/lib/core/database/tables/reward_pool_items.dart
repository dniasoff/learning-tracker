import 'package:drift/drift.dart';

/// Individual items within a reward pool.
class RewardPoolItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get poolId => integer()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get isUsed => boolean().withDefault(const Constant(false))();
}
