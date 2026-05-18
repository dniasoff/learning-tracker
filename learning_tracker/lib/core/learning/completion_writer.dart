import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';

/// Result of a [CompletionWriter.commit] call.
///
/// `completion` is always the persisted row. `isNew` is `true` when the
/// transaction inserted a new completion + outbox row; `false` when the
/// command was a duplicate of an existing completion and no outbox row was
/// enqueued.
class CompletionWriteResult {
  const CompletionWriteResult({required this.completion, required this.isNew});

  final Completion completion;
  final bool isNew;
}

/// Single, authoritative path for recording a completion (FR15, T2.7).
///
/// [commit] opens one Drift transaction that atomically inserts two rows:
///  1. `completion_events` — canonical FR5 event log (DNI-336 / AC 25.15).
///  2. `outbox` — drives the cloud push pipeline.
///
/// Both rows commit or both roll back. The `completions` table is no longer
/// written to after schema v20 (C1); it is now a legacy projection and the
/// Drift view `completions_view` is the read surface.
///
/// Idempotency: the writer checks for an existing
/// `(profileId, sefariaRef, stageId, trackType)` row in `completion_events`.
/// A duplicate command returns the existing view row with `isNew = false`
/// and does NOT enqueue a second outbox push.
///
/// Out of scope for this writer:
///  - Streak-event tee (moved into CompletionWriter by DNI-337).
///  - Reader-screen `completionCommittedProvider` notifier swap (Story 26.13).
///
/// Incoming Firestore pulls MUST NOT use this writer — pulled completions
/// must not generate outbox rows (that would loop remote writes back into
/// the push pipeline).
class CompletionWriter {
  CompletionWriter(this._db, {AnalyticsService? analytics})
    : _analytics = analytics ?? const NullAnalyticsService();

  final UserDatabase _db;
  final AnalyticsService _analytics;

  Future<CompletionWriteResult> commit(CompletionCommand cmd) async {
    return _db.transaction(() async {
      // Idempotency check on completion_events (UNIQUE canonical table).
      // getSingleOrNull() is safe because the UNIQUE constraint guarantees
      // at most one row per natural key.
      final existingEvent =
          await (_db.select(_db.completionEvents)..where(
                (t) =>
                    t.profileId.equals(cmd.profileId) &
                    t.sefariaRef.equals(cmd.sefariaRef) &
                    t.stageId.equals(cmd.stageId) &
                    t.trackType.equals(cmd.trackType),
              ))
              .getSingleOrNull();

      if (existingEvent != null) {
        // Event already recorded — read from the view (purgedAt IS NULL).
        final existing =
            await _db.completionDao.getCompletionById(existingEvent.id);
        if (existing != null) {
          return CompletionWriteResult(completion: existing, isNew: false);
        }
        // Event exists but the view row is absent (purgedAt IS NOT NULL — C3
        // tombstone). Falling through to appendEvent would call INSERT OR IGNORE
        // (the UNIQUE key already exists), return the purged row's id, then
        // getCompletionById would return null → StateError. Instead reconstruct
        // the Completion directly from the raw event row and return isNew=false.
        // The caller is responsible for deciding whether to act on a purged row.
        final purgedCompletion = Completion(
          id: existingEvent.id,
          profileId: existingEvent.profileId,
          curriculumId: existingEvent.curriculumId,
          sefariaRef: existingEvent.sefariaRef,
          stageId: existingEvent.stageId,
          trackType: existingEvent.trackType,
          trackId: existingEvent.trackId ?? 0,
          completedAt: existingEvent.eventTimestamp,
          points: existingEvent.points,
          derivedFromEvents: true,
        );
        return CompletionWriteResult(
          completion: purgedCompletion,
          isNew: false,
        );
      } else {
        // No event yet — also guard against legacy completions rows that
        // predate v20 (derivedFromEvents = false) so we don't double-count.
        final legacy =
            await (_db.select(_db.completions)..where(
                  (t) =>
                      t.profileId.equals(cmd.profileId) &
                      t.sefariaRef.equals(cmd.sefariaRef) &
                      t.stageId.equals(cmd.stageId) &
                      t.trackType.equals(cmd.trackType) &
                      t.derivedFromEvents.equals(false),
                ))
                .getSingleOrNull();
        if (legacy != null) {
          return CompletionWriteResult(completion: legacy, isNew: false);
        }
      }

      // Write canonical event (INSERT OR IGNORE — idempotent on natural key).
      // trackId is included so the completions_view can serve track-scoped queries.
      final eventId = await _db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: cmd.profileId,
          curriculumId: cmd.curriculumId,
          sefariaRef: cmd.sefariaRef,
          stageId: cmd.stageId,
          trackType: cmd.trackType,
          trackId: Value<int?>(cmd.trackId),
          points: Value(cmd.points),
          eventTimestamp: cmd.completedAt,
        ),
      );

      await _db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: cmd.profileId,
          entityKind: OutboxEntityKind.completion,
          entityKey: _outboxEntityKey(cmd),
          payload: jsonEncode(_outboxPayload(cmd)),
          createdAt: cmd.completedAt,
        ),
      );

      final inserted = await _db.completionDao.getCompletionById(eventId);
      if (inserted == null) {
        throw StateError(
          'CompletionWriter: event id=$eventId not found in completions_view',
        );
      }
      // Story 27.14 (DNI-390): fire analytics event for new completions only.
      unawaited(
        _analytics.logCompletionRecorded(
          sefariaRef: cmd.sefariaRef,
          trackType: cmd.trackType,
        ),
      );
      return CompletionWriteResult(completion: inserted, isNew: true);
    });
  }

  static String _outboxEntityKey(CompletionCommand cmd) =>
      '${cmd.profileId}:${cmd.sefariaRef}:${cmd.stageId}:${cmd.trackType}';

  static Map<String, Object?> _outboxPayload(CompletionCommand cmd) => {
    'profileId': cmd.profileId,
    'curriculumId': cmd.curriculumId,
    'sefariaRef': cmd.sefariaRef,
    'stageId': cmd.stageId,
    'trackType': cmd.trackType,
    'trackId': cmd.trackId,
    'completedAt': cmd.completedAt.toUtc().toIso8601String(),
    'points': cmd.points,
  };
}
