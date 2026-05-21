import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Pre-aggregated monthly activity rollup for the calendar sliver widget.
///
/// This table is a write-through cache: rows are written/upserted whenever
/// completion events land (or are purged). The sliver calendar reads directly
/// from this table so the "All Time" view never has to iterate 9 000+ raw
/// completion rows in the presentation layer.
///
/// Primary key: `(profileId, yearMonth)`.
///
/// [yearMonth] format: `'YYYY-MM'` (e.g. `'2026-05'`). Storing as text keeps
/// the value human-readable and lexicographically sortable, which is all the
/// sliver calendar needs.
@DataClassName('MonthlyActivityRollup')
class MonthlyActivityRollups extends Table {
  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();

  /// ISO month string, e.g. '2026-05'. Part of the composite primary key.
  TextColumn get yearMonth => text()();

  /// Number of distinct calendar days that had at least one live completion.
  IntColumn get activeDays => integer().withDefault(const Constant<int>(0))();

  /// Total live completion events in this month (stage 1 only).
  IntColumn get totalCompletions =>
      integer().withDefault(const Constant<int>(0))();

  /// Total chazara completion events in this month (stage > 1).
  IntColumn get totalChazaros =>
      integer().withDefault(const Constant<int>(0))();

  /// UTC timestamp of the earliest completion event in this month. Nullable
  /// because a rollup row may be created before any completions exist.
  DateTimeColumn get firstActivityDate => dateTime().nullable()();

  /// UTC timestamp of the most recent completion event in this month. Nullable
  /// for the same reason as [firstActivityDate].
  DateTimeColumn get lastActivityDate => dateTime().nullable()();

  /// Per-day activity bitmap for the month (max 31 days), stored as a
  /// space-separated list of day numbers that had activity, e.g. '1 4 15 28'.
  ///
  /// The sliver calendar uses this to render the 7-cell mini heat-strip for
  /// the last 7 days of the month without re-querying the raw events table.
  TextColumn get activeDaysList =>
      text().withDefault(const Constant<String>(''))();

  @override
  Set<Column<Object>> get primaryKey => {profileId, yearMonth};
}
