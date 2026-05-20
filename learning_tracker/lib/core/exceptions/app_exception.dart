// core/exceptions/app_exception.dart — W1.28
//
// Abstract root exception + 6 category base classes.
//
// Hierarchy:
//   AppException (root)
//   ├── ValidationException   — invalid input / value-object invariant violated
//   ├── ConflictException     — state conflict (duplicate, concurrent write clash)
//   ├── PermissionException   — caller not authorised for the requested operation
//   ├── NotFoundException     — entity does not exist or was not found
//   ├── NetworkException      — transient or permanent transport/connectivity error
//   └── InternalException     — unexpected internal state; should never reach the UI
//
// Usage:
//   - Catch [AppException] to handle all application-level errors uniformly.
//   - Catch a specific subclass (e.g. [PermissionException]) to handle a
//     particular category.
//   - Define leaf exceptions in the relevant feature or core module by
//     extending the appropriate category base.
//
// Note: [ValidationException] and [PermissionException] also exist in their
// own files for historical reasons (created before this hierarchy). They
// implement [AppException] here to satisfy the single-root invariant; their
// files re-export this file's definitions for backwards-compatibility.

/// Abstract root for all application-level exceptions.
///
/// Every domain, data, and service exception in the app MUST ultimately extend
/// one of the six category bases below. Catching [AppException] gives a safe
/// boundary for "anything the app logic can throw".
abstract class AppException implements Exception {
  const AppException(this.message);

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

// ─── Category bases ──────────────────────────────────────────────────────────

/// Thrown when a value object or service receives invalid or out-of-range input.
///
/// Examples: malformed Sefaria reference, negative pace value, start date
/// outside the allowed enrollment window.
abstract class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Thrown when an operation cannot proceed because of a conflicting state.
///
/// Examples: duplicate completion, concurrent track edit clash, unique
/// constraint violation in Drift.
abstract class ConflictException extends AppException {
  const ConflictException(super.message);
}

/// Thrown when the caller is not authorised to perform the requested operation.
///
/// Examples: tutor attempting to mark a live completion, parent PIN mismatch,
/// Firestore `PERMISSION_DENIED`.
///
/// Note: [TutorWriteForbiddenException] in `permission_exception.dart` extends
/// this class.
abstract class PermissionException extends AppException {
  const PermissionException(super.message);
}

/// Thrown when a required entity does not exist or cannot be found.
///
/// Examples: profile deleted before sync completes, stage definition missing
/// for a curriculum key, content chunk not cached and network unavailable.
abstract class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Thrown when a transport or connectivity failure prevents completion.
///
/// Callers should treat [NetworkException] as potentially transient — it is
/// safe to retry with back-off unless the inner [cause] is a permanent error.
abstract class NetworkException extends AppException {
  const NetworkException(super.message, {this.cause});

  /// Optional underlying error from the transport layer.
  final Object? cause;
}

/// Thrown when the app reaches an unexpected internal state.
///
/// [InternalException] signals a programming error or an assumption violation.
/// It should never be shown in the UI; Crashlytics will capture it.
abstract class InternalException extends AppException {
  const InternalException(super.message);
}
