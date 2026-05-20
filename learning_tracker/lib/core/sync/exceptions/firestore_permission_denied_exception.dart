import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Thrown when a Firestore operation returns PERMISSION_DENIED.
///
/// Extends [PermissionException] — the Firestore security rules rejected the
/// request.  This can happen due to:
///   - Expired or revoked session tokens (re-auth required).
///   - A tutor attempting to write to a collection protected by
///     `isOwner(uid)` rules.
///   - A misconfigured `firestore.rules` deployment (bug — should surface
///     as Crashlytics non-fatal, wired at W7.10).
///
/// Distinct from [TutorWriteForbiddenException], which is a *client-side*
/// domain guard thrown before the request reaches Firestore.
class FirestorePermissionDeniedException extends PermissionException {
  const FirestorePermissionDeniedException(
    super.message, {
    this.collection,
    this.operation,
    this.cause,
  });

  /// The Firestore collection that was accessed, if known.
  final String? collection;

  /// The operation that was attempted (e.g. `read`, `write`, `delete`).
  final String? operation;

  /// The underlying Firestore error.
  final Object? cause;

  @override
  String toString() =>
      'FirestorePermissionDeniedException: $message'
      '${collection != null ? ' (collection: $collection)' : ''}'
      '${operation != null ? ', op: $operation' : ''}'
      '${cause != null ? ' caused by: $cause' : ''}';
}
