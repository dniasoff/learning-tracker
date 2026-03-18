import 'package:drift/drift.dart';

/// Profile-program association table.
///
/// Stores which learning program preset a profile selected per curriculum.
class ProfilePrograms extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get curriculumType => text()();
  IntColumn get programId => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumType},
  ];
}
