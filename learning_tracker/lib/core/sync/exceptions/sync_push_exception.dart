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
  SyncPushException({
    required List<String> committed,
    required Object pushCause,
  }) : committed = List.unmodifiable(committed),
       super(
         'Batch push failed after ${committed.length} committed item(s)',
         cause: pushCause,
       );

  /// Entity keys of items that committed before the failure.
  ///
  /// AUD-core-sync-33: defensively copied via [List.unmodifiable] in the
  /// constructor so the partial-commit invariant this field exists to
  /// protect — "committed rows are never re-pushed or dead-lettered" (H3,
  /// see class doc) — is enforced by the type itself. Previously this held
  /// only because the single production call site
  /// (firestore_gateway_impl.dart) remembered to wrap the list in
  /// `List.unmodifiable(pushed)` before throwing; a future call site (or
  /// test double) that passed a live, still-growable list reference could
  /// otherwise silently corrupt this accounting after construction.
  final List<String> committed;

  @override
  String toString() =>
      'SyncPushException(committed: ${committed.length}, cause: $cause)';
}
