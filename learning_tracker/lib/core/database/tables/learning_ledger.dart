import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';

/// Learning Ledger table — append-only record of lifetime learning completions.
///
/// This table is INSERT-only. No UPDATE or DELETE operations
/// should be performed on ledger records. Entries survive track deletion
/// and curriculum deactivation (no foreign keys to those tables).
@TableIndex(
  name: 'learning_ledger_profile_created',
  columns: {#profileId, #createdAt},
)
class LearningLedger extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get curriculumId => text()();
  TextColumn get unitType => text()(); // 'seder', 'masechta', 'sefer'
  TextColumn get unitIdentifier => text()(); // level1 or level2 value
  TextColumn get unitDisplayNameHe => text()();
  TextColumn get unitDisplayNameEn => text()();
  TextColumn get trackType => text()(); // v1: always 'personal'
  IntColumn get trackId => integer().nullable().references(
    CurriculumTracks,
    #id,
  )(); // survives track deletion
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get completionNumber => integer()(); // nth time completing
  IntColumn get markedBy => integer()(); // profile_id of who marked it
  BoolColumn get isManual =>
      boolean().withDefault(const Constant(false))(); // auto vs siyum override
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
