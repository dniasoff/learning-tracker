import 'package:test/test.dart';

/// Tests for email and password validation logic used in account creation.
///
/// The validation functions are extracted here for unit testing.
/// They mirror the logic in AccountCreationScreen.
void main() {
  group('Email validation', () {
    String? validateEmail(String? value) {
      if (value == null || value.isEmpty) {
        return 'Email is required';
      }
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(value)) {
        return 'Please enter a valid email address';
      }
      return null;
    }

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
    String? validatePassword(String? value) {
      if (value == null || value.isEmpty) {
        return 'Password is required';
      }
      if (value.length < 6) {
        return 'Password must be at least 6 characters';
      }
      return null;
    }

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
}
