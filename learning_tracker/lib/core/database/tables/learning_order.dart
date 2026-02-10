import 'package:drift/drift.dart';

/// Learning order table per D7.
///
/// Allows users to customize the order in which content items
/// are presented within a curriculum.
///
/// sefariaRef references the content item in bundled JSON assets,
/// replacing the old contentItemId FK to the content_items table.
class LearningOrder extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  TextColumn get sefariaRef => text()();
  IntColumn get userSortOrder => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {curriculumId, sefariaRef},
  ];
}
