import 'dart:convert';

import 'package:drift/drift.dart';
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
/// [commit] opens one Drift transaction that inserts the `completions`
/// projection row and the `outbox` row that drives the cloud push. Either
/// both rows commit or both roll back; the writer never leaves a completion
/// without its outbox companion.
///
/// Idempotency: the writer checks for an existing
/// `(profileId, sefariaRef, stageId, trackType)` row inside the transaction.
/// A duplicate command returns the existing completion with `isNew = false`
/// and does NOT enqueue a second outbox push.
///
/// Out of scope for this story:
///  - `completion_events` append-only row (added by DNI-323).
///  - Streak-event tee (moved into CompletionWriter by DNI-337).
///  - Reader-screen `completionCommittedProvider` notifier swap (Story 26.13).
///
/// Incoming Firestore pulls MUST NOT use this writer — pulled completions
/// must not generate outbox rows (that would loop remote writes back into
/// the push pipeline).
class CompletionWriter {
  CompletionWriter(this._db);

  final UserDatabase _db;

  Future<CompletionWriteResult> commit(CompletionCommand cmd) async {
    return _db.transaction(() async {
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
        // Drift returned a row id but the read-back failed inside the same
        // transaction — surface a hard error so the transaction rolls back.
        throw StateError(
          'CompletionWriter: inserted row id=$id could not be read back',
        );
      }
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
