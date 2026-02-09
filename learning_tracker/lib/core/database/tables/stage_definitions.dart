import 'package:drift/drift.dart';

/// Stage definitions table per D3.
///
/// Defines the learning stages (e.g., learning, chazara1, chazara2)
/// for each curriculum with ordering and delay configuration.
class StageDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  IntColumn get stageOrder => integer()();
  TextColumn get stageName => text()();
  IntColumn get delayDays => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {curriculumId, stageOrder},
  ];
}
