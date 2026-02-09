import 'package:drift/drift.dart';

/// Content items table per D1 schema.
///
/// Stores hierarchical content (e.g., Mishnayos) with up to 4 levels
/// of hierarchy and curriculum association.
class ContentItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  TextColumn get level1 => text()();
  TextColumn get level2 => text().nullable()();
  TextColumn get level3 => text().nullable()();
  TextColumn get level4 => text().nullable()();
  TextColumn get displayNameHe => text()();
  TextColumn get displayNameEn => text()();
  TextColumn get sefariaRef => text().nullable()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isLeaf => boolean()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {curriculumId, level1, level2, level3, level4},
  ];
}
