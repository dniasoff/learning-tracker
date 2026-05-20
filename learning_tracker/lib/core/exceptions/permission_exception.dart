// PermissionException hierarchy — W4.33
//
// Base class for permission-related errors. Subclasses are thrown when a
// caller attempts an operation they are not authorised to perform.

/// Base exception for permission violations.
///
/// Callers should catch [PermissionException] when they want to handle all
/// permission errors uniformly, or catch specific subclasses to handle
/// individual cases.
abstract class PermissionException implements Exception {
  const PermissionException(this.message);

  /// Human-readable description of the permission violation.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a tutor attempts an operation that requires owner-level access.
///
/// The canonical use case is a tutor trying to mark a live (today's) completion
/// directly from the client. This is forbidden by the security model:
///   - The Firestore rules enforce `isOwner(uid)` on the completions collection.
///   - The client domain layer throws this exception before the write reaches
///     Firestore, so the UI can surface a meaningful error message.
///
/// Bulk-prior completions are NOT forbidden — they go through the Cloud
/// Function proxy (W3.43, tutorBulkPriorCompletions), which validates that
/// completedAt is strictly in the past.
///
/// See also: [TutorPermissions.canMarkLiveCompletion] (always false).
class TutorWriteForbiddenException extends PermissionException {
  const TutorWriteForbiddenException({
    String message =
        'Tutors cannot mark live completions. '
        'Bulk-prior completions must use the Cloud Function proxy.',
  }) : super(message);
}
