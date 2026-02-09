import 'package:drift/drift.dart';

/// Completions table — append-only record of all completions.
///
/// This table is INSERT-only. No UPDATE or DELETE operations
/// should be performed on completion records.
class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  IntColumn get contentItemId => integer()();
  IntColumn get stageId => integer()();
  TextColumn get trackType => text()();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get points => integer().withDefault(const Constant(0))();
}
