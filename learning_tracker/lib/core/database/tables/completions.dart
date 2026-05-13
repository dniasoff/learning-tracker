import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';

/// Completions table — append-only record of all completions.
///
/// This table is INSERT-only. No UPDATE or DELETE operations
/// should be performed on completion records.
class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get curriculumId => text()();
  TextColumn get sefariaRef => text()();
  IntColumn get stageId => integer()();
  TextColumn get trackType => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get points => integer().withDefault(const Constant(0))();
}
