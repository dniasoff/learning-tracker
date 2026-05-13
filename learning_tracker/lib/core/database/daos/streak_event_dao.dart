import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/streak_events.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'streak_event_dao.g.dart';

/// DAO for the [StreakEvents] append-only log (Story 25.2 / DNI-323).
///
/// FR5 invariant: insert-only. No public delete API. Duplicate inserts on
/// the natural key `(profileId, dayUtc, eventType)` collapse to one row
/// via `INSERT OR IGNORE` and return the existing row id.
@DriftAccessor(tables: [StreakEvents])
class StreakEventDao extends DatabaseAccessor<UserDatabase>
    with _$StreakEventDaoMixin {
  StreakEventDao(super.db);

  /// Append a streak event. Idempotent on the natural key — returns the
  /// existing row id when `(profileId, dayUtc, eventType)` already exists.
  Future<int> appendEvent(StreakEventsCompanion entry) async {
    await into(streakEvents).insert(entry, mode: InsertMode.insertOrIgnore);
    final row =
        await (select(streakEvents)
              ..where(
                (t) =>
                    t.profileId.equals(entry.profileId.value) &
                    t.dayUtc.equals(entry.dayUtc.value) &
                    t.eventType.equals(entry.eventType.value),
              )
              ..limit(1))
            .getSingle();
    return row.id;
  }

  /// All events for a profile, ordered by event timestamp ascending.
  Future<List<StreakEvent>> getEventsByProfile(int profileId) =>
      (select(streakEvents)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.asc(t.eventTimestamp)]))
          .get();
}
