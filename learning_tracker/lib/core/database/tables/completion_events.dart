import 'package:drift/drift.dart';

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
@TableIndex(
  name: 'completion_events_natural_key',
  columns: {#profileId, #sefariaRef, #stageId, #trackType},
  unique: true,
)
class CompletionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get curriculumId => text()();
  TextColumn get sefariaRef => text()();
  IntColumn get stageId => integer()();
  TextColumn get trackType => text()();
  DateTimeColumn get eventTimestamp => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
