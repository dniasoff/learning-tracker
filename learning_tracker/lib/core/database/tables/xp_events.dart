import 'package:drift/drift.dart';

/// Append-only event log for XP/gamification (Epic 20 v2 §4.1).
///
/// Each row represents an atomic XP delta. Total XP is derived by
/// summing all rows for a profile. Sync replicates rows, not totals.
class XpEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();

  /// Delta applied by this event. Positive for earned XP, negative
  /// for manual adjustments / penalties.
  IntColumn get xpDelta => integer()();

  /// `completion` | `reward` | `admin_adjust` | …
  TextColumn get source => text()();

  /// UTC timestamp of the real-world moment the event occurred.
  DateTimeColumn get eventTimestamp => dateTime()();

  TextColumn get clientDeviceId => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, eventTimestamp, source},
      ];
}
