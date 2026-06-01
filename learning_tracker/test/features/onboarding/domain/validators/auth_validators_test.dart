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

void main() {
  group('validateEmail', () {
    test('null returns "Email is required"', () {
      expect(validateEmail(null), 'Email is required');
    });

    test('empty string returns "Email is required"', () {
      expect(validateEmail(''), 'Email is required');
    });

    test('malformed nonempty (no @) returns the valid-email message, '
        'NOT "Email is required"', () {
      expect(
        validateEmail('abnotanemail'),
        'Please enter a valid email address',
      );
    });

    test('missing TLD (no dot) returns the valid-email message', () {
      expect(validateEmail('a@b'), 'Please enter a valid email address');
    });

    test('well-formed email returns null', () {
      expect(validateEmail('a@b.co'), isNull);
    });
  });
}
