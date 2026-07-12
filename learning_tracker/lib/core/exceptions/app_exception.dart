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

/// Stable, localizable failure category for [ValidationException] (EH-5).
///
/// This app ships EN + Hebrew. [ValidationException.message] is a
/// developer-facing (English-only) string meant for logs/Crashlytics — it
/// must never be surfaced directly in the UI. Presentation resolves the
/// user-facing string for [ValidationException.validationCode] through
/// `AppLocalizations`/ARB instead (mirrors the `SyncErrorCode` reference
/// pattern in `lib/features/sync/domain/models/sync_error_code.dart`; see
/// `AppErrorView._configFor` for the resolution site).
///
/// Named `validationCode` rather than `code` because some leaves (e.g.
/// [InvalidInputException] in `local_auth_service.dart`) already declare
/// their own, more granular `code` field with a leaf-specific enum for
/// callers that catch that leaf directly — this base-level field is a
/// separate, always-present, coarser-grained code every [ValidationException]
/// carries for generic consumers like [AppErrorView]. A same-named field
/// would collide (Dart requires override-compatible types).
enum ValidationErrorCode {
  /// Generic invalid-input / invariant-violation failure not covered by a
  /// more specific code. Every current [ValidationException] leaf uses this
  /// code today; splitting individual leaves into more specific codes as
  /// their user-facing copy is designed is a future, additive change.
  invalidInput,
}

/// Thrown when a value object or service receives invalid or out-of-range input.
///
/// Examples: malformed Sefaria reference, negative pace value, start date
/// outside the allowed enrollment window.
abstract class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.validationCode = ValidationErrorCode.invalidInput,
  });

  /// Stable, localizable failure category (EH-5). Presentation must resolve
  /// this — never [message] — into a user-facing string.
  final ValidationErrorCode validationCode;
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

// ─── Shared toString() formatting ────────────────────────────────────────────

/// Shared ` caused by: <cause>` formatting for leaf exceptions that carry an
/// optional underlying [cause].
///
/// AUD-core-sync-32: this ternary was hand-copied into 3 sync exception
/// classes (`FirestorePermissionDeniedException`, `MergeException`,
/// `OutboxDeadLetterException`) — the latter two were since deleted as dead
/// code by AUD-core-sync-27, leaving `FirestorePermissionDeniedException` as
/// the sole current user. Mixing this in still gives every future leaf
/// exception one place to change the formatting — e.g. to redact a
/// PII-bearing `FirebaseException` payload before it reaches
/// AppLogger/Crashlytics.
///
/// Not applied to [SyncPushException] — its `toString()` uses a
/// deliberately different, unconditional `cause: $cause` shape (it always
/// has a cause, by construction) rather than this optional-suffix form.
mixin CauseSuffix {
  /// The underlying error, if any. Implementers typically already declare
  /// this field (directly or inherited from [NetworkException]); the mixin
  /// only requires it be readable.
  Object? get cause;

  /// `' caused by: $cause'` when [cause] is non-null, else the empty string.
  String get causeSuffix => cause != null ? ' caused by: $cause' : '';
}
