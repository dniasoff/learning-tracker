import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';

void main() {
  group('ImportValidationException', () {
    test('is a ValidationException (and therefore an AppException)', () {
      const exception = ImportValidationException('Invalid JSON format');

      expect(exception, isA<ValidationException>());
      expect(exception, isA<AppException>());
    });

    test('is not a dart:core FormatException', () {
      // AUD-settings-13: distinct from the FormatException json.decode
      // itself can throw, so callers can catch this type specifically.
      const exception = ImportValidationException('Invalid JSON format');

      expect(exception, isNot(isA<FormatException>()));
    });

    test('carries the given message', () {
      const exception = ImportValidationException(
        'Missing required section: goals',
      );

      expect(exception.message, 'Missing required section: goals');
    });

    test('defaults to the generic invalidInput validation code', () {
      const exception = ImportValidationException('Invalid JSON format');

      expect(exception.validationCode, ValidationErrorCode.invalidInput);
    });

    test('toString() includes the runtime type and message', () {
      const exception = ImportValidationException('Invalid JSON format');

      expect(
        exception.toString(),
        'ImportValidationException: Invalid JSON format',
      );
    });
  });
}
