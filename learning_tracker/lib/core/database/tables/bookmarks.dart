import 'package:drift/drift.dart';

/// Bookmarks table for tracking current position per curriculum/track.
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  TextColumn get trackType => text()();
  IntColumn get contentItemId => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {curriculumId, trackType},
  ];
}
