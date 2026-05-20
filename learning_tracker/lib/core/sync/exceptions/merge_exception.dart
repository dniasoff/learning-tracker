import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Thrown when the sync merge pipeline encounters an unrecoverable error.
///
/// Extends [InternalException] because a merge failure indicates that the
/// data layer is in an unexpected state that the app cannot self-correct.
/// Callers that catch [MergeException] should record the event via crisis
/// telemetry (W7.5 / W7.6) and surface a recoverable error to the user.
///
/// Distinct from a transient network failure ([NetworkException]) — a merge
/// failure means the data *arrived* but could not be applied.
class MergeException extends InternalException {
  const MergeException(super.message, {this.entityKind, this.cause});

  /// The entity kind being merged when the failure occurred, if known.
  final String? entityKind;

  /// The underlying error, if any.
  final Object? cause;

  @override
  String toString() =>
      'MergeException: $message'
      '${entityKind != null ? ' (entity: $entityKind)' : ''}'
      '${cause != null ? ' caused by: $cause' : ''}';
}
