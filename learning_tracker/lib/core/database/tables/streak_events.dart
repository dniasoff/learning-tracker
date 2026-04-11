import 'package:drift/drift.dart';

/// Append-only event log for streak state reconstruction (Epic 20 v2 §4.1).
///
/// Each device appends events; state is derived by replaying the
/// log. Sync replicates the log, not the derived state — this makes
/// streak corruption via ordering mistakes mathematically impossible.
class StreakEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();

  /// `completion` | `day_boundary` | `manual_adjust`
  TextColumn get eventType => text()();

  /// UTC timestamp of the real-world moment the event occurred.
  /// Used for ordering and as part of the idempotency key.
  DateTimeColumn get eventTimestamp => dateTime()();

  /// Optional device hint for diagnostics. No security bearing.
  TextColumn get clientDeviceId => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, eventTimestamp, eventType},
      ];
}
