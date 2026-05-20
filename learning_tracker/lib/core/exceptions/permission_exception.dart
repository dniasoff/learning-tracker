// PermissionException hierarchy — W4.33 / W1.28
//
// [PermissionException] base is defined in app_exception.dart (W1.28).
// This file re-exports it and adds [TutorWriteForbiddenException].

import 'package:learning_tracker/core/exceptions/app_exception.dart';

export 'package:learning_tracker/core/exceptions/app_exception.dart'
    show PermissionException;

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
