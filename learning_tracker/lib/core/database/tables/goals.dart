import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Goals table — learning goals with per-curriculum deadlines.
///
/// Each goal has a target completion percentage and optional deadline.
/// Multiple goals per curriculum are allowed.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get curriculumId => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  RealColumn get targetPercent => real().withDefault(const Constant(100.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get dateType => text().withDefault(const Constant('gregorian'))();
  TextColumn get goalType => text().withDefault(const Constant('deadline'))();
  IntColumn get paceValue => integer().nullable()();
  /// Pace period unit: 'day', 'week', 'month', or null.
  TextColumn get pacePeriod => text().nullable()();

  /// Learning unit: 'amud', 'daf', or null. Used for Bavli/Yerushalmi curricula.
  TextColumn get paceGranularity => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
