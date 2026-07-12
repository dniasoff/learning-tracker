/// `StreakEventLog` — thin wrapper over the `streak_events` table.
///
/// The single mutation method is [append]. Idempotency is enforced by
/// the UNIQUE `(profileId, dayUtc, eventType)` index on
/// `streak_events` (Story 25.2 / DNI-323): duplicate appends are
/// silently swallowed via `InsertMode.insertOrIgnore`.
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/features/gamification/streak/streak_event.dart';

class StreakEventLog {
  const StreakEventLog(this._db);

  final UserDatabase _db;

  /// Append a single event. Safe to call twice with identical fields —
  /// the second call is a no-op (UNIQUE collapse).
  ///
  /// Returns `true` if a row was inserted, `false` if the UNIQUE
  /// constraint dropped a duplicate.
  Future<bool> append(StreakEvent event) async {
    final ts = event.eventTimestamp.toUtc();
    final dayUtc = DateTime.utc(ts.year, ts.month, ts.day);
    final affected = await _db
        .into(_db.streakEvents)
        .insert(
          StreakEventsCompanion.insert(
            profileId: event.profileId,
            eventType: event.eventType,
            dayUtc: dayUtc,
            eventTimestamp: event.eventTimestamp,
            clientDeviceId: event.clientDeviceId == null
                ? const Value.absent()
                : Value(event.clientDeviceId),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return affected > 0;
  }
}
