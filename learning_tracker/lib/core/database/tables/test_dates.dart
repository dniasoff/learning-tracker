import 'package:drift/drift.dart';

/// Test dates table — scheduled test dates for learning programs.
///
/// Stores test calendar entries for programs that have tests (e.g., Dirshu).
/// Seeded with upcoming test dates and updateable with app releases.
class TestDates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer()();
  DateTimeColumn get testDate => dateTime()();
  TextColumn get materialDescription =>
      text().withDefault(const Constant(''))();
}
