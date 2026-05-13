import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';

/// Bookmarks table for tracking current position per curriculum/track.
///
/// sefariaRef references the content item in bundled JSON assets,
/// replacing the old contentItemId FK to the content_items table.
///
/// Schema v1 (DNI-322): profileId is now required (no default); trackType
/// string replaced by trackId FK referencing curriculum_tracks.id.
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get curriculumId => text()();

  /// FK to curriculum_tracks.id — replaces the old trackType TEXT column.
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();

  TextColumn get sefariaRef => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, trackId},
  ];
}
