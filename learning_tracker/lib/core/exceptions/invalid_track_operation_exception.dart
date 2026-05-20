import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Thrown when attempting an invalid track operation.
///
/// Examples: deactivating the protected personal track, operating on a
/// track that doesn't exist for the given profile.
class InvalidTrackOperationException extends ValidationException {
  const InvalidTrackOperationException(super.message);
}
