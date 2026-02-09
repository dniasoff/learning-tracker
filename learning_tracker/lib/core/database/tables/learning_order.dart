import 'package:drift/drift.dart';

/// Learning order table per D7.
///
/// Allows users to customize the order in which content items
/// are presented within a curriculum.
class LearningOrder extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  IntColumn get contentItemId => integer()();
  IntColumn get userSortOrder => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {curriculumId, contentItemId},
  ];
}
