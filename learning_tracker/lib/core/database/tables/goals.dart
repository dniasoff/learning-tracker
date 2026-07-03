import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Goals table — learning goals with per-curriculum deadlines.
///
/// Each goal has a target completion percentage and optional deadline.
/// Multiple goals per curriculum are allowed.
///
/// Schema v33: added a non-unique composite index on `(profileId,
/// curriculumId)` so `profileId` structurally participates in the
/// profile-scoping key (Story 25.1 multi-profile-leak invariant), matching
/// the pattern already used by the `outbox` table. Non-unique — deliberately
/// does NOT enforce one-goal-per-curriculum, since multiple goals per
/// curriculum remain allowed (goals are keyed one-per-track via
/// `GoalDao.upsertGoalByTrack`, not one-per-curriculum).
@TableIndex(
  name: 'goals_profile_curriculum',
  columns: {#profileId, #curriculumId},
)
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
