import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Thrown when an outbox item has exhausted all retry attempts.
///
/// Extends [NetworkException] — the root cause is a persistent transport or
/// Firestore-write failure that survived back-off retries.  When this is
/// thrown the item should be moved to a dead-letter queue and crisis telemetry
/// (W7.7 — `outbox_dead_lettered` event) should be fired.
class OutboxDeadLetterException extends NetworkException {
  const OutboxDeadLetterException(
    super.message, {
    required this.outboxItemId,
    required this.attemptCount,
    super.cause,
  });

  /// Opaque identifier of the outbox row that was dead-lettered.
  final String outboxItemId;

  /// Number of delivery attempts that were made before giving up.
  final int attemptCount;

  @override
  String toString() =>
      'OutboxDeadLetterException: $message '
      '(itemId: $outboxItemId, attempts: $attemptCount)'
      '${cause != null ? ' caused by: $cause' : ''}';
}
