// Regression test for AUD-account-04 / AUD-account-10: a single,
// unit-tested extractFirebaseCode() replaces the drifted per-file regex
// copies in magic_link_service.dart, upgrade_to_cloud_service.dart,
// sign_in_controller.dart, and signup_screen.dart.
//
// BUG LOG:
//   - RED (pre-fix): this file/helper did not exist. The duplicated copies
//     using `RegExp(r'\[([a-z-]+)\]')` never matched Firebase's real
//     `[plugin/code]` toString() shape (the character class excludes both
//     `_` and `/`), so every real Firebase error silently fell through to
//     a generic message.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/utils/firebase_error_code.dart';

class _FakeFirebaseException {
  const _FakeFirebaseException(this.plugin, this.code, this.message);
  final String plugin;
  final String code;
  final String message;

  @override
  String toString() => '[$plugin/$code] $message';
}

void main() {
  group('extractFirebaseCode', () {
    test('extracts the code from the real "[plugin/code]" shape', () {
      const e = _FakeFirebaseException(
        'firebase_auth',
        'email-already-in-use',
        'The email address is already in use by another account.',
      );
      expect(extractFirebaseCode(e), 'email-already-in-use');
    });

    test('extracts the code from the bare "[code]" shape', () {
      final e = Exception('[wrong-password] The password is invalid.');
      expect(extractFirebaseCode(e), 'wrong-password');
    });

    test('a plugin segment with multiple underscores (cloud_firestore) still '
        'resolves to the bare code', () {
      const e = _FakeFirebaseException(
        'cloud_firestore',
        'permission-denied',
        'Missing or insufficient permissions.',
      );
      expect(extractFirebaseCode(e), 'permission-denied');
    });

    test('returns null when the string has no bracketed code', () {
      expect(extractFirebaseCode(Exception('boom')), isNull);
    });
  });
}
