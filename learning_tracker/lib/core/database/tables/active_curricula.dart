import 'package:drift/drift.dart';

/// Active curricula table — stores which curricula are currently active.
///
/// Each row represents an active curriculum. Deactivating a curriculum
/// removes its row. At least one curriculum must be active at all times.
class ActiveCurricula extends Table {
  /// curriculum_id from CurriculumId enum storageKey
  TextColumn get curriculumId => text()();

  /// When this curriculum was activated
  DateTimeColumn get activatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {curriculumId};
}
