import 'package:drift/drift.dart';

/// Goals table — learning goals with per-curriculum deadlines.
///
/// Each goal has a target completion percentage and optional deadline.
/// Multiple goals per curriculum are allowed.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  RealColumn get targetPercent => real().withDefault(const Constant(100.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get dateType => text().withDefault(const Constant('gregorian'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
