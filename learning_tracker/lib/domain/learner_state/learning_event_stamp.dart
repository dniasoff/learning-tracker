/// Retry-stable identity for a new learning event (AD-31, AD-46, parent
/// AD-5).
///
/// The client ULID and `recorded_at` are allocated ONCE, before the first
/// write, by an [EventStamper] whose clock and id source are injected at
/// the command boundary. A [PendingLearningEventWrite] then holds the
/// finished, validated event; every retry re-sends that same value and
/// never touches the clock again.
library;

import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// A UTC clock.
typedef UtcClock = DateTime Function();

/// Mints a ULID whose time prefix is [at].
typedef UlidSource = String Function(DateTime at);

/// The id and `recorded_at` of one new event.
final class EventStamp {
  /// Creates a stamp.
  const EventStamp({required this.id, required this.recordedAt});

  /// Client ULID (document id).
  final String id;

  /// Client `recorded_at` (UTC).
  final DateTime recordedAt;
}

/// Allocates [EventStamp]s from injected sources.
final class EventStamper {
  /// Creates a stamper.
  const EventStamper({required this.clock, required this.newUlid});

  /// Read exactly once per [stamp].
  final UtcClock clock;

  /// Called exactly once per [stamp].
  final UlidSource newUlid;

  /// Reads the clock once and mints one ULID from that instant.
  EventStamp stamp() {
    final at = clock().toUtc();
    final id = newUlid(at);
    if (!isUlid(id)) {
      throw const StorageFormatException('EventStamp', '<id>', 'not a ULID');
    }
    return EventStamp(id: id, recordedAt: at);
  }
}

/// A learning-event write that can be attempted any number of times with
/// an identical payload.
final class PendingLearningEventWrite {
  /// Validates [event] once (throws `StorageFormatException` if invalid)
  /// and freezes it for retries.
  PendingLearningEventWrite(this.scope, this.event)
    : payload = Map.unmodifiable(event.toStorage());

  /// Where the event is written.
  final LearnerScope scope;

  /// The immutable event.
  final LearningEvent event;

  /// The storage payload every attempt sends.
  final Map<String, Object?> payload;

  /// One attempt. Retrying calls this again with the same [event]; nothing
  /// here reads a clock or mints an id.
  Future<void> attempt(LearningEventRepository repository) =>
      repository.create(scope, event);
}
