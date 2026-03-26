import 'package:drift/drift.dart';

/// Profile-program association table.
///
/// Stores which learning program preset a profile selected per curriculum.
class ProfilePrograms extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get curriculumType => text()();
  IntColumn get programId => integer()();

  /// Start date for tracking window (Path A onboarding)
  DateTimeColumn get trackingStartDate => dateTime().nullable()();

  /// Sefaria ref of first item in tracking window
  TextColumn get trackingStartRef => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumType},
  ];
}
