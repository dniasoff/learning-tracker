/// `StreakEventMerger` — append-only merger for `streak_events`.
///
/// Streak state is derived by replaying the event log
/// ([StreakReducer]). Merging a pull therefore reduces to "insert any
/// unseen rows"; the reducer rebuilds the snapshot on the next read.
/// Duplicates (cross-device same-instant completions) are dropped by
/// the composite-UNIQUE `(profileId, eventTimestamp, eventType)` from
/// Story 25.2 (DNI-323).
///
/// API note: lives at `core/sync/merge/` so the DNI-334 `MergeRouter`
/// can pick it up unchanged when that PR lands on `dev`. Until then
/// this class can be used directly by `core/streak/` code.
library;

import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/core/streak/streak_event.dart';
import 'package:learning_tracker/core/streak/streak_event_log.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class StreakEventMerger implements EntityMerger {
  StreakEventMerger(UserDatabase db) : _log = StreakEventLog(db);

  @override
  String get kind => EntityKind.streak;

  final StreakEventLog _log;

  /// Insert any unseen pulled rows. Each [rows] entry follows the
  /// Firestore shape (`event_type`, `event_timestamp` ISO-8601 string,
  /// optional `client_device_id`). UNIQUE silently collapses dupes.
  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final eventType = row['event_type'] as String?;
      final tsRaw = row['event_timestamp'];
      if (eventType == null || tsRaw == null) continue;
      final ts = tsRaw is DateTime ? tsRaw : DateTime.parse(tsRaw.toString());

      await _log.append(
        StreakEvent(
          profileId: profileId,
          eventType: eventType,
          eventTimestamp: ts,
          clientDeviceId: row['client_device_id'] as String?,
        ),
      );
    }
  }
}
