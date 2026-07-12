// Validation-function coverage for the auth forms.
//
// Locks in the email-validation branches that drive the sign-in/sign-up
// inline field errors. Regression target for the on-device report that a
// malformed-but-nonempty email ("abnotanemail") surfaced "Email is required"
// instead of "Please enter a valid email address": the empty/null branch must
// fire ONLY for empty input, and any nonempty string that fails the email
// pattern must fall through to the "valid email" branch.
@Tags(['account', 'auth_validators'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

void main() {
  // AUD-onboarding-03: validators resolve messages through AppLocalizations
  // rather than returning hardcoded English literals — exercised against
  // BOTH locales so a regression that reintroduces a hardcoded literal (which
  // would be locale-invariant) is caught.
  final en = AppLocalizationsEn();
  final he = AppLocalizationsHe();

  group('validateEmail', () {
    test('null returns the localized "Email is required" message', () {
      expect(validateEmail(null, en), en.authEmailRequired);
      expect(validateEmail(null, he), he.authEmailRequired);
      expect(he.authEmailRequired, isNot(en.authEmailRequired));
    });

    test('empty string returns the localized "Email is required" message', () {
      expect(validateEmail('', en), en.authEmailRequired);
      expect(validateEmail('', he), he.authEmailRequired);
    });

    test('malformed nonempty (no @) returns the valid-email message, '
        'NOT the required message', () {
      expect(validateEmail('abnotanemail', en), en.authEmailInvalid);
      expect(validateEmail('abnotanemail', he), he.authEmailInvalid);
      expect(he.authEmailInvalid, isNot(en.authEmailInvalid));
    });

    test('missing TLD (no dot) returns the valid-email message', () {
      expect(validateEmail('a@b', en), en.authEmailInvalid);
    });

    test('well-formed email returns null', () {
      expect(validateEmail('a@b.co', en), isNull);
    });
  });
}
