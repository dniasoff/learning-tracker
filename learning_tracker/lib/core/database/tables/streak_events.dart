import 'package:drift/drift.dart';

/// Append-only event log for streak state reconstruction (Epic 20 v2 §4.1).
///
/// Each device appends events; state is derived by replaying the
/// log. Sync replicates the log, not the derived state — this makes
/// streak corruption via ordering mistakes mathematically impossible.
///
/// DNI-323 (Story 25.2) introduces `dayUtc` and declares a UNIQUE composite
/// `(profileId, dayUtc, eventType)` so two devices writing the same logical
/// day-event collapse to one row.
@TableIndex(
  name: 'streak_events_natural_key',
  columns: {#profileId, #dayUtc, #eventType},
  unique: true,
)
class StreakEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();

  /// `completion` | `day_boundary` | `manual_adjust`
  TextColumn get eventType => text()();

  /// UTC date this event belongs to, normalised to midnight. Used as part
  /// of the natural-key dedup key — two completions on the same UTC day for
  /// the same profile collapse to one row.
  DateTimeColumn get dayUtc => dateTime()();

  /// UTC timestamp of the real-world moment the event occurred.
  /// Used for ordering inside a single day.
  DateTimeColumn get eventTimestamp => dateTime()();

  /// Optional device hint for diagnostics. No security bearing.
  TextColumn get clientDeviceId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
