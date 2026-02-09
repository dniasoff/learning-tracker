import 'package:drift/drift.dart';

/// Curriculum hierarchy configuration table per D1.
///
/// Defines the label names for each hierarchy level and how many
/// levels a given curriculum uses.
class CurriculumHierarchyConfig extends Table {
  TextColumn get curriculumId => text()();
  TextColumn get level1Label => text()();
  TextColumn get level2Label => text().nullable()();
  TextColumn get level3Label => text().nullable()();
  TextColumn get level4Label => text().nullable()();
  IntColumn get maxLevels => integer()();

  @override
  Set<Column> get primaryKey => {curriculumId};
}
