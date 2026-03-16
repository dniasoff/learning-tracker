import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart';
import 'package:test/test.dart';

/// Tests for the extracted auth validation functions.
void main() {
  group('Email validation', () {
    test('rejects null', () {
      expect(validateEmail(null), 'Email is required');
    });

    test('rejects empty string', () {
      expect(validateEmail(''), 'Email is required');
    });

    test('rejects invalid format - no @', () {
      expect(validateEmail('userexample.com'), isNotNull);
    });

    test('rejects invalid format - no domain', () {
      expect(validateEmail('user@'), isNotNull);
    });

    test('rejects invalid format - no TLD', () {
      expect(validateEmail('user@example'), isNotNull);
    });

    test('accepts valid email', () {
      expect(validateEmail('user@example.com'), isNull);
    });

    test('accepts email with subdomain', () {
      expect(validateEmail('user@mail.example.com'), isNull);
    });
  });

  group('Password validation', () {
    test('rejects null', () {
      expect(validatePassword(null), 'Password is required');
    });

    test('rejects empty string', () {
      expect(validatePassword(''), 'Password is required');
    });

    test('rejects password under 6 characters', () {
      expect(validatePassword('12345'), isNotNull);
    });

    test('accepts password of exactly 6 characters', () {
      expect(validatePassword('123456'), isNull);
    });

    test('accepts long password', () {
      expect(validatePassword('aVeryLongPassword123'), isNull);
    });
  });

  group('Display name validation', () {
    test('rejects null', () {
      expect(validateDisplayName(null), 'Display name is required');
    });

    test('rejects empty string', () {
      expect(validateDisplayName(''), 'Display name is required');
    });

    test('accepts valid name', () {
      expect(validateDisplayName('Test User'), isNull);
    });
  });
}
