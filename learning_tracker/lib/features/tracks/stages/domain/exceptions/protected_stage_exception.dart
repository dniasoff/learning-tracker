/// Exception thrown when attempting to delete the protected Learn stage.
class ProtectedStageException implements Exception {
  const ProtectedStageException();

  String get userMessage => 'The Learn stage cannot be deleted';

  @override
  String toString() => 'ProtectedStageException: $userMessage';
}
