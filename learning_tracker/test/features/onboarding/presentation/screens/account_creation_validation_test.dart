import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';
import 'package:test/test.dart';

/// Tests for the extracted auth validation functions.
///
/// AUD-onboarding-03: asserted against localized [AppLocalizations] output
/// (both en and he) rather than hardcoded English literals, so a regression
/// that reintroduces a hardcoded literal is caught by the he assertions.
void main() {
  final en = AppLocalizationsEn();
  final he = AppLocalizationsHe();

  group('Email validation', () {
    test('rejects null', () {
      expect(validateEmail(null, en), en.authEmailRequired);
      expect(validateEmail(null, he), he.authEmailRequired);
    });

    test('rejects empty string', () {
      expect(validateEmail('', en), en.authEmailRequired);
    });

    test('rejects invalid format - no @', () {
      expect(validateEmail('userexample.com', en), isNotNull);
    });

    test('rejects invalid format - no domain', () {
      expect(validateEmail('user@', en), isNotNull);
    });

    test('rejects invalid format - no TLD', () {
      expect(validateEmail('user@example', en), isNotNull);
    });

    test('accepts valid email', () {
      expect(validateEmail('user@example.com', en), isNull);
    });

    test('accepts email with subdomain', () {
      expect(validateEmail('user@mail.example.com', en), isNull);
    });
  });

  group('Password validation', () {
    test('rejects null', () {
      expect(validatePassword(null, en), en.authPasswordRequired);
      expect(validatePassword(null, he), he.authPasswordRequired);
    });

    test('rejects empty string', () {
      expect(validatePassword('', en), en.authPasswordRequired);
    });

    test('rejects password under 6 characters', () {
      expect(validatePassword('12345', en), isNotNull);
    });

    test('accepts password of exactly 6 characters', () {
      expect(validatePassword('123456', en), isNull);
    });

    test('accepts long password', () {
      expect(validatePassword('aVeryLongPassword123', en), isNull);
    });
  });

  group('Display name validation', () {
    test('rejects null', () {
      expect(validateDisplayName(null, en), en.authDisplayNameRequired);
      expect(validateDisplayName(null, he), he.authDisplayNameRequired);
    });

    test('rejects empty string', () {
      expect(validateDisplayName('', en), en.authDisplayNameRequired);
    });

    test('accepts valid name', () {
      expect(validateDisplayName('Test User', en), isNull);
    });
  });
}
