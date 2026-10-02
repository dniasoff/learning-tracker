/// Port for `learning_events` — the complete read the engine consumes and
/// the append-only, create-only write `LearningCommands` uses (AD-31,
/// AD-35, AD-46). Implemented in
/// `lib/data/repositories/firestore_learning_event_repository.dart`.
library;

import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// Reads and appends a learner's learning events.
abstract interface class LearningEventRepository {
  /// The complete event log of [scope], live.
  ///
  /// Emits [CompleteReadLoading] first, then pages the collection by
  /// document id at ≤ 500 rows per query until a short page proves it is
  /// exhausted, and only then emits one [CompleteReadReady] with every
  /// event. Later changes re-assemble the pages and publish a new complete
  /// list; a partial list is never emitted. Stream-level listener failures
  /// are forwarded as error events and the listener recovers (AD-9).
  Stream<CompleteRead<LearningEvent>> watchAll(LearnerScope scope);

  /// One page of the events of [scope], newest `recorded_at` first (ties
  /// by document id, descending), after [after]; at most [limit] documents
  /// (1..[kChangeHistoryPageSize]). The parent Change history (DNI-513)
  /// merges it by effective instant using [HistoryPage.watermark].
  ///
  /// A document that does not decode is skipped and listed in
  /// [HistoryPage.rejected]; the cursor and watermark still advance past
  /// it. One single-field order: no composite index (AD-54).
  Future<HistoryPage<LearningEvent>> historyPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  });

  /// The events with [ids] that exist and decode, in no set order (e.g.
  /// the targets of `void` events not on a loaded history page). Missing
  /// or undecodable documents are left out.
  Future<List<LearningEvent>> eventsById(LearnerScope scope, Set<String> ids);

  /// Writes the prebuilt [event] at `learning_events/{event.id}`.
  ///
  /// Create-only and idempotent: the id and every timestamp are already
  /// fixed in [event] (allocated once, before the first attempt), so a
  /// retry with the same value sends an identical payload — never a fresh
  /// time or a server timestamp (AD-46, parent AD-5). Throws
  /// `StorageFormatException` before any I/O if [event] is invalid.
  ///
  /// Append-only: an identical replay of an event that already exists is a
  /// no-op, and a NON-identical write at an existing event id throws
  /// [LearningEventConflictException] without touching the stored event.
  Future<void> create(LearnerScope scope, LearningEvent event);
}

/// A create at an event id that already holds a DIFFERENT event — a replay
/// whose payload was rebuilt instead of reused, or an id collision. The
/// stored event is left unchanged (AD-31 append-only, AD-46 create-only
/// plus identical replay).
final class LearningEventConflictException implements Exception {
  /// Creates the exception for [eventId].
  const LearningEventConflictException(this.eventId);

  /// The contested `learning_events/{ulid}` id.
  final String eventId;

  @override
  String toString() =>
      'LearningEventConflictException: learning_events/$eventId already '
      'holds a different event';
}
