import 'package:drift/drift.dart';

/// Bookmarks table for tracking current position per curriculum/track.
///
/// sefariaRef references the content item in bundled JSON assets,
/// replacing the old contentItemId FK to the content_items table.
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  TextColumn get trackType => text()();
  TextColumn get sefariaRef => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {curriculumId, trackType},
  ];
}
