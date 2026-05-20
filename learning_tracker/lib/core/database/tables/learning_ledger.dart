import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';
import 'package:learning_tracker/core/time/ulid.dart';

/// Learning Ledger table — append-only record of lifetime learning completions.
///
/// This table is INSERT-only. No UPDATE or DELETE operations
/// should be performed on ledger records. Entries survive track deletion
/// and curriculum deactivation (no foreign keys to those tables).
///
/// DNI-323 (Story 25.2) adds a per-row `ulid` and a UNIQUE composite
/// `(profileId, ulid)` so duplicate syncs of the same logical entry collapse
/// to one row.
@TableIndex(
  name: 'learning_ledger_profile_created',
  columns: {#profileId, #createdAt},
)
@TableIndex(
  name: 'learning_ledger_profile_ulid',
  columns: {#profileId, #ulid},
  unique: true,
)
class LearningLedger extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();

  /// ULID identifying the logical ledger entry across devices. Two devices
  /// writing the same entry use the same ULID so the UNIQUE composite
  /// `(profileId, ulid)` collapses duplicates. Auto-generated client-side
  /// when omitted on insert.
  TextColumn get ulid => text().clientDefault(newUlid)();

  TextColumn get curriculumId => text()();

  /// Scope of the learning ledger entry: 'seder', 'masechta', 'sefer'.
  TextColumn get entryScope => text()();
  TextColumn get unitIdentifier => text()(); // level1 or level2 value
  TextColumn get unitDisplayNameHe => text()();
  TextColumn get unitDisplayNameEn => text()();
  TextColumn get trackType => text()(); // v1: always 'personal'
  /// Nullable FK. ON DELETE SET NULL so ledger entries survive track deletion
  /// (purgeHistory hard-deletes the track row but ledger rows are append-only).
  IntColumn get trackId => integer().nullable().references(
    CurriculumTracks,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get completionNumber => integer()(); // nth time completing
  IntColumn get markedBy => integer()(); // profile_id of who marked it
  BoolColumn get isManual =>
      boolean().withDefault(const Constant(false))(); // auto vs siyum override
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
