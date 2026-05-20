import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Exception thrown when attempting to delete the protected Learn stage.
class ProtectedStageException extends ValidationException {
  const ProtectedStageException() : super('The Learn stage cannot be deleted');

  String get userMessage => message;
}
