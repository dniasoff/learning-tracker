import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Tracking table for completion_events rows injected via the bulk-prior-mark
/// flow (BulkPriorCompletionService / AddTrack wizard "I already learned this").
///
/// ### Why a separate table?
/// Keeping `priorMarkOnly` as a column on `completion_events` conflates the
/// canonical event log with import-provenance metadata. Separating the two:
///
///  - `completion_events` stays a clean append-only log of all learning events,
///    regardless of source.
///  - `prior_completion_imports` is a set of natural keys whose rows in
///    `completion_events` originated from a bulk import.
///
/// ### Lifecycle
/// 1. [BulkPriorCompletionService.execute] inserts one row per imported
///    completion (keyed by the same natural key as the matching
///    `completion_events` row).
/// 2. [BulkPriorCompletionService.expungePriorCompletions] tombstones the
///    matching `completion_events` rows (sets `purgedAt`) and then deletes the
///    corresponding rows from this table.
/// 3. When a real in-app learning event hits the same natural key as a
///    prior-import row, [CompletionWriter] deletes the row from this table so
///    the event is no longer considered a bulk import — any future
///    `expungePriorCompletions` call will skip it.
///
/// ### B1 bulkInTrack credit policy
/// Because all rows in `prior_completion_imports` originate from
/// [CompletionSource.bulkInTrack] or [CompletionSource.lifetimeOnly],
/// engagement-tier side effects (streak events, gamification points) are never
/// fired for these rows. The import table acts as the single source of truth
/// for "has this completion been upgraded to a real-learning event?" — a row
/// present here means it has not.
class PriorCompletionImports extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK → learner_profiles(id) CASCADE DELETE — mirrors the FK on
  /// completion_events so profile deletion cascades cleanly.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get curriculumId => text()();
  TextColumn get sefariaRef => text()();
  IntColumn get stageId => integer()();
  TextColumn get trackType => text()();

  /// The [CompletionSource] that produced this import row.
  ///
  /// Stored as the enum name string so SQL queries can distinguish
  /// [CompletionSource.bulkInTrack] from [CompletionSource.lifetimeOnly]
  /// without an extra join.  Only `bulkInTrack` and `lifetimeOnly` are valid
  /// values; [CompletionSource.live] completions never enter this table.
  TextColumn get source => text()();

  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
}
