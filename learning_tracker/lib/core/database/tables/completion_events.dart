import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Append-only event log of completions (Story 25.2 / DNI-323).
///
/// One row per logical completion, deduplicated on the natural key
/// `(profileId, sefariaRef, stageId, trackType)`. The legacy `completions`
/// table remains as a non-unique projection so review-count semantics
/// (multiple rows per natural key) continue to work; this `completion_events`
/// table is the FR5 append-only source of truth and the sync engine pushes
/// only these rows.
///
/// INSERT-only. No update or delete. Duplicate inserts use
/// `INSERT OR IGNORE` so two devices writing the same logical event collapse
/// to one row.
///
/// C3: [purgedAt] is the tombstone for purgeHistory — never delete rows,
/// instead set this field. Row count never decreases (N8 invariant).
@TableIndex(
  name: 'completion_events_natural_key',
  columns: {#profileId, #sefariaRef, #stageId, #trackType},
  unique: true,
)
class CompletionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId => integer().references(
    LearnerProfiles,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get curriculumId => text()();
  TextColumn get sefariaRef => text()();
  IntColumn get stageId => integer()();
  TextColumn get trackType => text()();
  /// FK → CurriculumTracks.id. Added v20 to enable the completions view.
  /// Nullable for legacy rows that pre-date this column.
  IntColumn get trackId => integer().nullable()();
  IntColumn get points => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get eventTimestamp => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// C3: tombstone timestamp set by purgeHistory instead of deleting the row.
  /// null = active; non-null = purged at this UTC timestamp.
  DateTimeColumn get purgedAt => dateTime().nullable()();
}
