import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Thrown when a Firestore batch push partially succeeds before failing.
///
/// The `committed` field lists the entity keys of items that successfully
/// committed before the failure. The `OutboxProcessor` uses this list to
/// delete only those outbox rows and mark the remainder as attempted —
/// ensuring that rows which genuinely committed are never re-pushed and
/// never dead-lettered.
///
/// Extends [NetworkException] — the root cause is always a transport or
/// Firestore write failure.
class SyncPushException extends NetworkException {
  SyncPushException({required this.committed, required Object pushCause})
    : super(
        'Batch push failed after ${committed.length} committed item(s)',
        cause: pushCause,
      );

  /// Entity keys of items that committed before the failure.
  final List<String> committed;

  @override
  String toString() =>
      'SyncPushException(committed: ${committed.length}, cause: $cause)';
}
