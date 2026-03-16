import 'package:drift/drift.dart';

/// Streaks table — single-row table tracking global learning streak.
///
/// Stores current streak count, maximum streak ever achieved,
/// and the last completion date for day-boundary calculations.
class Streaks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get maxStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastCompletionDate => dateTime().nullable()();
}
