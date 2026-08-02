/// Unit tests for
/// `lib/features/account/domain/models/account_entity.dart` — the entity
/// mirrored test required by audit check 29/40 (AG-5) alongside
/// `firestore_account_repository_test.dart`. Covers: `toFirestore`/
/// `fromFirestore` round-trip, `uid` never appearing in the write map, the
/// nullable-`email` round-trip (both set and absent), and the documented
/// throw-on-missing-timestamp decode failure.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';

void main() {
  group('toFirestore / fromFirestore round-trip', () {
    test('round-trips every field when email is set', () {
      final account = AccountEntity(
        uid: 'uid-1',
        email: 'daniel@example.com',
        displayName: 'Daniel',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final decoded = AccountEntity.fromFirestore(
        'uid-1',
        account.toFirestore(),
      );

      expect(decoded, account);
    });

    test('round-trips a null email (anonymous account, not yet linked)', () {
      final account = AccountEntity(
        uid: 'uid-2',
        displayName: 'Anonymous',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final data = account.toFirestore();
      expect(data['email'], isNull);

      final decoded = AccountEntity.fromFirestore('uid-2', data);
      expect(decoded.email, isNull);
    });

    test('toFirestore never includes a uid field — the path already '
        'carries it', () {
      final account = AccountEntity(
        uid: 'uid-3',
        displayName: 'Someone',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(account.toFirestore(), isNot(contains('uid')));
    });

    test('fromFirestore uses the caller-supplied uid, not any document '
        'field', () {
      final data = AccountEntity(
        uid: 'ignored',
        displayName: 'Someone',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ).toFirestore();

      final decoded = AccountEntity.fromFirestore('real-uid', data);

      expect(decoded.uid, 'real-uid');
    });
  });

  group('fromFirestore — decode failures', () {
    test('throws FormatException when created_at is missing', () {
      expect(
        () => AccountEntity.fromFirestore('uid-1', {
          'display_name': 'Daniel',
          'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when updated_at is missing', () {
      expect(
        () => AccountEntity.fromFirestore('uid-1', {
          'display_name': 'Daniel',
          'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('defaults a missing display_name to an empty string rather than '
        'throwing', () {
      final decoded = AccountEntity.fromFirestore('uid-1', {
        'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      });

      expect(decoded.displayName, '');
    });
  });
}
