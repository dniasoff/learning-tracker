/// Port for the chunked learning-event write: events plus their AD-50
/// `pts_{eventId}` points awards, in one batch per chunk.
///
/// Filled by DNI-469 (1.7) inside `firestore_learning_event_repository.dart`
/// (ruling B4(a): DNI-464 owns that file).
library;

import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// The points award co-written with a learning event (doc
/// `pts_{eventId}`).
final class PointsAward {
  /// Creates an award.
  const PointsAward({
    required this.eventId,
    required this.amount,
    required this.createdAt,
  });

  /// The earning learning event.
  final String eventId;

  /// Points awarded.
  final int amount;

  /// Award instant (UTC).
  final DateTime createdAt;

  /// The `points_ledger` document id.
  String get docId => 'pts_$eventId';

  @override
  bool operator ==(Object other) =>
      other is PointsAward &&
      other.eventId == eventId &&
      other.amount == amount &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(eventId, amount, createdAt);

  @override
  String toString() => 'PointsAward($eventId, $amount)';
}

/// One atomic write: [events] and their [awards].
final class LearningWriteChunk {
  /// Creates a chunk.
  ///
  /// Throws [ArgumentError] when it holds more than [maxWrites] writes or
  /// an award whose event is not in [events].
  LearningWriteChunk({
    required List<LearningEvent> events,
    List<PointsAward> awards = const [],
  }) : events = List.unmodifiable(events),
       awards = List.unmodifiable(awards) {
    if (events.length + awards.length > maxWrites) {
      throw ArgumentError.value(
        events.length + awards.length,
        'writes',
        'a chunk holds at most $maxWrites writes',
      );
    }
    final ids = {for (final e in events) e.id};
    for (final award in awards) {
      if (!ids.contains(award.eventId)) {
        throw ArgumentError.value(
          award.eventId,
          'awards',
          'award for an event outside the chunk',
        );
      }
    }
  }

  /// Writes per chunk (below Firestore's 500-op batch limit).
  static const maxWrites = 450;

  /// The learning events.
  final List<LearningEvent> events;

  /// The points awards.
  final List<PointsAward> awards;

  @override
  String toString() =>
      'LearningWriteChunk(${events.length} events, ${awards.length} awards)';
}

/// Commits learning-write chunks.
abstract interface class LearningWritePort {
  /// Commits [chunk] for [scope] as one batch. Throws
  /// [PermanentWriteRejection] when the server will never accept it.
  Future<void> commit(LearnerScope scope, LearningWriteChunk chunk);
}

/// A write the server rejected for good (permission or validation), so a
/// retry would fail the same way.
final class PermanentWriteRejection implements Exception {
  /// Creates the rejection with the server [code].
  const PermanentWriteRejection(this.code);

  /// The server error code, e.g. `permission-denied`.
  final String code;

  @override
  String toString() => 'PermanentWriteRejection($code)';
}
