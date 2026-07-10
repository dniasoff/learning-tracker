/// `StreakEventMerger` — append-only merger for `streak_events`.
///
/// Streak state is derived by replaying the event log
/// ([StreakReducer]). Merging a pull therefore reduces to "insert any
/// unseen rows"; the reducer rebuilds the snapshot on the next read.
/// Duplicates (cross-device same-instant completions) are dropped by
/// the composite-UNIQUE `(profileId, eventTimestamp, eventType)` from
/// Story 25.2 (DNI-323).
///
/// W3.37: Streak Firestore schema changed from a single snapshot document
/// `streak/{profileId}` to a per-event collection `streak_events/{ulid}`.
/// Each document now carries `study_date` (the canonical event date) and
/// `created_at` (write timestamp) instead of `event_timestamp`. This merger
/// consumes [StreakEventCodec] for decoding, with a fallback to the legacy
/// `event_timestamp` field so pre-migration docs (if any) are still ingested.
library;

import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/codec/streak_event_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_log.dart';

class StreakEventMerger implements EntityMerger {
  StreakEventMerger(UserDatabase db, {AppLogger? logger})
    : _log = StreakEventLog(db),
      _logger = logger;

  @override
  String get kind => EntityKind.streak;

  final StreakEventLog _log;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;

  static const _codec = StreakEventCodec();

  /// Insert any unseen pulled rows.
  ///
  /// W3.37 shape: `event_type`, `study_date`, `created_at`, `profile_id`.
  /// Legacy fallback: `event_timestamp` is accepted so any pre-migration docs
  /// still in Firestore are ingested rather than silently discarded.
  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
        // Try the W3.37 codec path first.
        final decoded = _codec.decode(row);
        if (decoded != null) {
          await _log.append(
            StreakEvent(
              profileId: decoded.profileId == 0 ? profileId : decoded.profileId,
              eventType: decoded.eventType,
              eventTimestamp: decoded.studyDate,
              clientDeviceId: row['client_device_id'] as String?,
            ),
          );
          continue;
        }

        // Legacy fallback: `event_timestamp` field (pre-W3.37 shape).
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
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_streak_event_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
