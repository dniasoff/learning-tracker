import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';

/// Goals table — learning goals with per-curriculum deadlines.
///
/// Each goal has a target completion percentage and optional deadline.
/// Multiple goals per curriculum are allowed.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get curriculumId => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  RealColumn get targetPercent => real().withDefault(const Constant(100.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get dateType => text().withDefault(const Constant('gregorian'))();
  TextColumn get goalType => text().withDefault(const Constant('deadline'))();
  IntColumn get paceValue => integer().nullable()();
  // SQL column: pace_unit (preserved for schema compat)
  TextColumn get pacePeriod => text().nullable().named('pace_unit')();

  /// Learning unit: 'amud', 'daf', or null. Used for Bavli/Yerushalmi curricula.
  // SQL column: learning_unit (preserved for schema compat)
  TextColumn get paceGranularity => text().nullable().named('learning_unit')();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
