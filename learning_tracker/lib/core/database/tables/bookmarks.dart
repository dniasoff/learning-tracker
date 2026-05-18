import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Bookmarks table for tracking current position per curriculum/track.
///
/// sefariaRef references the content item in bundled JSON assets,
/// replacing the old contentItemId FK to the content_items table.
///
/// Schema v1 (DNI-322): profileId is now required (no default); trackType
/// string replaced by trackId FK referencing curriculum_tracks.id.
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get curriculumId => text()();

  /// FK to curriculum_tracks.id. ON DELETE CASCADE so bookmarks are removed
  /// when a track is hard-deleted (purgeHistory), preserving referential
  /// integrity after PRAGMA foreign_keys = ON is enabled in C2.
  IntColumn get trackId => integer().references(
    CurriculumTracks,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get sefariaRef => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, trackId},
  ];
}
