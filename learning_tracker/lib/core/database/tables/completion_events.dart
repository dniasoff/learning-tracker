import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Append-only event log of completions (Story 25.2 / DNI-323).
///
/// One row per logical completion, deduplicated on the natural key
/// `(profileId, sefariaRef, stageId, trackType, curriculumId)`. The legacy
/// `completions` table remains as a non-unique projection so review-count
/// semantics (multiple rows per natural key) continue to work; this
/// `completion_events` table is the FR5 append-only source of truth and the
/// sync engine pushes only these rows.
///
/// INSERT-only. No update or delete. Duplicate inserts use
/// `INSERT OR IGNORE` so two devices writing the same logical event collapse
/// to one row.
///
/// C3: [purgedAt] is the tombstone for purgeHistory — never delete rows,
/// instead set this field. Row count never decreases (N8 invariant).
@TableIndex(
  name: 'completion_events_natural_key',
  columns: {#profileId, #sefariaRef, #stageId, #trackType, #curriculumId},
  unique: true,
)
class CompletionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();

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

  /// AUD-scheduler-15 (v37): explicit marker for what [stageId] encodes.
  /// `'stageOrder'` — the value is a [StageDefinitions.stageOrder] ordinal
  /// (every current writer, [CompletionWriter], stamps this). `'legacyId'`
  /// — the value is a [StageDefinitions.id] reference (pre-v37 rows the v37
  /// migration could unambiguously classify as id-based). `null` — unknown
  /// (any pre-v37 row the migration could not classify with certainty, or a
  /// row inserted by a path that predates this column, e.g. a synced pull);
  /// readers fall back to the historical best-effort heuristic for these.
  ///
  /// Both `stage_definitions.id` (a global autoincrement) and `stageOrder`
  /// (a small 1..10 per-curriculum ordinal) are small positive integers that
  /// can coincide — especially after [StageDefinitionRepository.reorderStages]
  /// changes a stage's order while its id stays fixed — so a per-read
  /// "does this value look like a known stageOrder" guess can silently
  /// resolve to the WRONG stage. This column removes the guess for any row
  /// that carries it. See [SchedulerCompletionRepositoryImpl.resolveStageOrder].
  TextColumn get stageIdFormat => text().nullable()();

  // NOTE: The `priorMarkOnly` column was removed in W4.26.
  // Import provenance is tracked in [PriorCompletionImports] table.
  // See BulkPriorCompletionService + CompletionWriter for the B8 upgrade path.
}
