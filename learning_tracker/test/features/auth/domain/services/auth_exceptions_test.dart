// Tests for auth exception classes — covers toString() methods
// that are pure and do not require database or auth setup.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/domain/services/upgrade_to_cloud_service.dart';

void main() {
  // =========================================================================
  // LocalAuthService exceptions
  // =========================================================================

  group('DuplicateEmailException', () {
    test('toString contains class name but NOT raw email (log-safe)', () {
      // The raw email is intentionally excluded from toString() for logger
      // safety — callers that need it read ex.email directly.
      const ex = DuplicateEmailException('alice@example.com');
      expect(ex.toString(), contains('DuplicateEmailException'));
      expect(ex.toString(), isNot(contains('alice@example.com')));
    });

    test('is an Exception', () {
      const ex = DuplicateEmailException('test@test.com');
      expect(ex, isA<Exception>());
    });

    test('exposes email field', () {
      const ex = DuplicateEmailException('bob@example.com');
      expect(ex.email, 'bob@example.com');
    });
  });

  group('InvalidCredentialsException', () {
    test('toString returns descriptive string', () {
      const ex = InvalidCredentialsException();
      expect(ex.toString(), contains('InvalidCredentialsException'));
    });

    test('is an Exception', () {
      const ex = InvalidCredentialsException();
      expect(ex, isA<Exception>());
    });
  });

  group('InvalidInputException', () {
    test('toString contains field and reason', () {
      const ex = InvalidInputException(
        'email',
        InvalidInputCode.invalidEmail,
        'invalid format',
      );
      expect(ex.toString(), contains('email'));
      expect(ex.toString(), contains('invalid format'));
      expect(ex.toString(), contains('InvalidInputException'));
    });

    test('exposes field, code and reason', () {
      const ex = InvalidInputException(
        'password',
        InvalidInputCode.passwordTooShort,
        'too short',
      );
      expect(ex.field, 'password');
      expect(ex.code, InvalidInputCode.passwordTooShort);
      expect(ex.reason, 'too short');
    });

    test('is an Exception', () {
      const ex = InvalidInputException(
        'name',
        InvalidInputCode.displayNameRequired,
        'required',
      );
      expect(ex, isA<Exception>());
    });
  });

  // =========================================================================
  // UpgradeToCloudService exceptions
  // =========================================================================

  group('EmailCollisionException', () {
    // AUD-t-auth-03: this group previously asserted toString() DID contain
    // the raw email — the opposite of the sibling DuplicateEmailException
    // group above — which locked in inconsistent PII redaction between the
    // two sibling exception types. Corrected to assert the same log-safety
    // property as DuplicateEmailException (not a weakening: the new
    // assertion is strictly stricter than the one it replaces).
    test('toString contains class name but NOT raw email (log-safe)', () {
      // The raw email is intentionally excluded from toString() for logger
      // safety — callers that need it read ex.email directly.
      const ex = EmailCollisionException('charlie@example.com');
      expect(ex.toString(), contains('EmailCollisionException'));
      expect(ex.toString(), isNot(contains('charlie@example.com')));
    });

    test('exposes email field', () {
      const ex = EmailCollisionException('user@domain.com');
      expect(ex.email, 'user@domain.com');
    });

    test('redactedEmail exposes a log-safe form of the email', () {
      const ex = EmailCollisionException('user@domain.com');
      expect(ex.redactedEmail, '***@domain.com');
      expect(ex.toString(), isNot(contains('user@domain.com')));
    });

    test('is an Exception', () {
      const ex = EmailCollisionException('x@y.com');
      expect(ex, isA<Exception>());
    });
  });

  group('UpgradePasswordMismatchException', () {
    test('toString returns descriptive string', () {
      const ex = UpgradePasswordMismatchException();
      expect(ex.toString(), contains('UpgradePasswordMismatchException'));
    });

    test('is an Exception', () {
      const ex = UpgradePasswordMismatchException();
      expect(ex, isA<Exception>());
    });
  });

  group('UpgradeEmailNotVerifiedException', () {
    test('toString returns descriptive string', () {
      const ex = UpgradeEmailNotVerifiedException();
      expect(ex.toString(), contains('UpgradeEmailNotVerifiedException'));
    });

    test('is an Exception', () {
      const ex = UpgradeEmailNotVerifiedException();
      expect(ex, isA<Exception>());
    });
  });
}
