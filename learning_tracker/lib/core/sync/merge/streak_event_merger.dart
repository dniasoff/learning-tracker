/// `StreakEventMerger` — append-only merger for `streak_events`.
///
/// Streak state is derived by replaying the event log
/// ([StreakReducer]). Merging a pull therefore reduces to "insert any
/// unseen rows"; the reducer rebuilds the snapshot on the next read.
/// Duplicates (cross-device same-instant completions) are dropped by
/// the composite-UNIQUE `(profileId, eventTimestamp, eventType)` from
/// Story 25.2 (DNI-323).
///
/// NOTE (W3.37): The current Firestore shape uses `event_type` /
/// `event_timestamp`. After W3.37 migrates streak to `streak_events/{ulid}`
/// with `study_date` / `created_at`, this merger will consume
/// [StreakEventCodec] directly.
library;

import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_log.dart';

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
      final ts = FirestoreCodec.parseDateTime(row['event_timestamp']);
      if (eventType == null || ts == null) continue;

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
