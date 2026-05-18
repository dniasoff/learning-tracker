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
/// [commit] opens one Drift transaction that atomically inserts three rows:
///  1. `completions` — projection row for review-count semantics.
///  2. `outbox` — drives the cloud push pipeline.
///  3. `completion_events` — append-only FR5 event log (DNI-336 / AC 25.15).
///
/// All three rows commit or all three roll back; the writer never leaves a
/// completion without its outbox and event-log companions.
///
/// Idempotency: the writer checks for an existing
/// `(profileId, sefariaRef, stageId, trackType)` row inside the transaction.
/// A duplicate command returns the existing completion with `isNew = false`
/// and does NOT enqueue a second outbox push or event-log row.
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
      // C1: idempotency check on completion_events (UNIQUE canonical table).
      // getSingleOrNull() is safe here because the UNIQUE constraint guarantees
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
        // Event already recorded — locate the derived completions row.
        final existing =
            await (_db.select(_db.completions)..where(
                  (t) =>
                      t.profileId.equals(cmd.profileId) &
                      t.sefariaRef.equals(cmd.sefariaRef) &
                      t.stageId.equals(cmd.stageId) &
                      t.trackType.equals(cmd.trackType),
                ))
                .getSingleOrNull();
        if (existing != null) {
          return CompletionWriteResult(completion: existing, isNew: false);
        }
        // Event exists but no derived row (edge case after partial failure).
        // Fall through to re-derive; appendEvent below is INSERT OR IGNORE.
      } else {
        // No event yet — also guard against legacy completions rows that
        // predate C1 (derived_from_events = false) so we don't double-count.
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

      // C1: write canonical event first (INSERT OR IGNORE — idempotent).
      await _db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: cmd.profileId,
          curriculumId: cmd.curriculumId,
          sefariaRef: cmd.sefariaRef,
          stageId: cmd.stageId,
          trackType: cmd.trackType,
          eventTimestamp: cmd.completedAt,
        ),
      );

      // C1: derive completions projection row, tagged as event-derived.
      final id = await _db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          profileId: cmd.profileId,
          curriculumId: cmd.curriculumId,
          sefariaRef: cmd.sefariaRef,
          stageId: cmd.stageId,
          trackType: cmd.trackType,
          trackId: cmd.trackId,
          completedAt: cmd.completedAt,
          points: Value(cmd.points),
          derivedFromEvents: const Value(true),
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

      final inserted = await _db.completionDao.getCompletionById(id);
      if (inserted == null) {
        throw StateError(
          'CompletionWriter: inserted row id=$id could not be read back',
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
