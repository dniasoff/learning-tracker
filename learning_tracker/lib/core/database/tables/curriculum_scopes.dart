import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Curriculum scopes table — limits which parts of a curriculum are tracked.
///
/// Each row represents a selected scope within a curriculum hierarchy.
/// Multiple rows for the same (profileId, curriculumId) = multiple scopes
/// (e.g., "Seder Zeraim" + "Seder Moed" in Mishnayos).
/// No rows = entire curriculum (backward compatible default).
///
/// W3.23: added `updatedAt` for LWW sync.
/// W3.25: profileId FK added.
class CurriculumScopes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// W3.25: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get curriculumId => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();

  /// Which hierarchy level the scope applies to (1-4, matching level1-level4).
  IntColumn get scopeLevel => integer()();

  /// The value at that level (e.g., "Seder Zeraim", "Berachos").
  TextColumn get scopeValue => text()();

  DateTimeColumn get createdAt => dateTime()();

  /// W3.23: LWW timestamp for sync.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, scopeLevel, scopeValue, trackId},
  ];
}
