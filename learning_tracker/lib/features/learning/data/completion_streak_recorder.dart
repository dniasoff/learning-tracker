import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/streak_event_codec.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';

/// Drift-backed [CompletionStreakPort] — relocated verbatim from
/// `CompletionRepositoryImpl._appendStreakEvent` as part of the
/// completion-orchestrator lift (`docs/firestore-rewrite-map.md`, owner
/// decision 1). Writes a local `streak_events` row (idempotent per
/// `(profileId, dayUtc, eventType)` — DNI-323's UNIQUE index makes a same-day
/// re-record a benign no-op via `insertOrIgnore`) and tees it into the
/// outbox for cloud sync.
///
/// **No Firestore-backed sibling exists yet.** A future Firestore
/// [CompletionStreakPort] writes directly to `streak_events/{ulid}` (no
/// outbox — see `docs/firestore-rewrite-map.md`'s "Deleted outright",
/// `Outbox`) via `FirestoreStreakEventRepository`
/// (`lib/data/repositories/firestore_streak_event_repository.dart`); that is
/// a separate, not-yet-wired piece of work, out of this file's scope. Until
/// it lands, [CompletionOrchestrator] receives `streakPort: null` wherever it
/// sits above a Firestore-backed [CompletionRepository], which resolves the
/// streak step to a no-op rather than guessing at a Firestore shape here.
class DriftCompletionStreakRecorder implements CompletionStreakPort {
  DriftCompletionStreakRecorder({
    required UserDatabase database,
    OutboxSyncWriteFacade? outboxFacade,
  }) : _database = database,
       _outboxFacade = outboxFacade;

  final UserDatabase _database;
  final OutboxSyncWriteFacade? _outboxFacade;

  static const _streakCodec = StreakEventCodec();

  @override
  Future<void> recordStudyDay({
    required int profileId,
    required DateTime at,
  }) async {
    try {
      final dayUtc = DateTime.utc(at.year, at.month, at.day);
      await _database
          .into(_database.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: dayUtc,
              eventTimestamp: at,
            ),
            mode: drift.InsertMode.insertOrIgnore,
          );

      // Phase 1 — sync the streak event via the outbox. ULID encodes the
      // event timestamp so duplicate enqueues across two devices on the same
      // logical day collapse to one Firestore doc.
      final facade = _outboxFacade;
      if (facade != null) {
        final payload = _streakCodec.encode(
          StreakEventRow(
            profileId: profileId,
            eventType: 'completion',
            studyDate: dayUtc,
            createdAt: at,
            ulid: newUlid(at),
          ),
        );
        await facade.enqueueStreakPayload(payload);
      }
    } on Exception catch (e, stackTrace) {
      // AUD-learning-06 / EH-3 / EH-4: narrowed from a bare `catch (_)` —
      // see the original `CompletionRepositoryImpl._appendStreakEvent` doc
      // comment (preserved here) for why every Exception reaching this point
      // is unexpected and must be logged, not silently dropped, even though
      // this "telemetry tee" must never block or roll back the primary
      // completion write.
      AppLogger.instance.error(
        event: 'completion_streak_tee_failed',
        fields: {'profileId': profileId},
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }
}
