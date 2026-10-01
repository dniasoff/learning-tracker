/// Port for `learning_events` — the complete read the engine consumes and
/// the append-only, create-only write `LearningCommands` uses (AD-31,
/// AD-35, AD-46). Implemented in
/// `lib/data/repositories/firestore_learning_event_repository.dart`.
library;

import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
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

  /// Writes the prebuilt [event] at `learning_events/{event.id}`.
  ///
  /// Create-only and idempotent: the id and every timestamp are already
  /// fixed in [event] (allocated once, before the first attempt), so a
  /// retry with the same value sends an identical payload — never a fresh
  /// time or a server timestamp (AD-46, parent AD-5). Throws
  /// `StorageFormatException` before any I/O if [event] is invalid.
  Future<void> create(LearnerScope scope, LearningEvent event);
}
