import 'package:drift/drift.dart';

/// Rewards table for gamification system.
///
/// curriculum_id is nullable to support global (cross-curriculum) rewards.
class Rewards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  IntColumn get pointsThreshold => integer()();
  BoolColumn get isRevealed => boolean().withDefault(const Constant(false))();
  BoolColumn get isEarned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get earnedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get curriculumId => text().nullable()();
}
