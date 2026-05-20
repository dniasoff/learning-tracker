/// Base class for all validation errors — thrown when a value object
/// receives out-of-range or logically invalid input.
///
/// Part of the `AppException` category hierarchy defined in W1.28.
/// Until W1.28 lands, this is a standalone base. Once S1 ships the full
/// exception tree, this class will be reparented under `ValidationException`
/// from `core/exceptions/app_exception.dart`.
abstract class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => '${runtimeType.toString()}: $message';
}
