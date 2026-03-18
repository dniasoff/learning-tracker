import 'package:drift/drift.dart';

/// Test scores table — logged scores for completed tests.
///
/// Profile-scoped. Stores percentage scores after test dates pass.
class TestScores extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  IntColumn get programId => integer()();
  IntColumn get testDateId => integer().nullable()();
  IntColumn get scorePercentage => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
}
