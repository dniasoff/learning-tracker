import 'package:drift/drift.dart';

/// Configuration table for points awarded per stage per curriculum.
///
/// Each row maps a (curriculum_id, stage_order) pair to a point value.
/// Default values are seeded when a curriculum is activated.
class PointConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  IntColumn get stageOrder => integer()();
  IntColumn get points =>
      integer().customConstraint('NOT NULL CHECK (points > 0)')();

  @override
  List<Set<Column>> get uniqueKeys => [
    {curriculumId, stageOrder},
  ];
}
