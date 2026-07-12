// Extra tests for UserProfileDao — covers findCloudBornByFirebaseUid,
// UserTierX.fromDb, and findByTier (uncovered lines 21-24 and 54-62).
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/dao_invariant_error.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // UserTierX.fromDb
  // =========================================================================

  group('UserTierX.fromDb', () {
    test('parses cloudBorn', () {
      expect(UserTierX.fromDb('cloudBorn'), UserTier.cloudBorn);
    });

    test('parses localBorn', () {
      expect(UserTierX.fromDb('localBorn'), UserTier.localBorn);
    });

    test(
      'throws a typed DaoInvariantError with a stable code, not a raw '
      'English message, for an unknown value (AUD-core-database-14, EH-5)',
      () {
        expect(
          () => UserTierX.fromDb('unknown'),
          throwsA(
            isA<DaoInvariantError>().having(
              (e) => e.code,
              'code',
              DaoErrorCode.unknownAccountTier,
            ),
          ),
        );
      },
    );
  });

  // =========================================================================
  // AccountX.accountTier (AUD-core-database-07, EH-4)
  // =========================================================================

  group('AccountX.accountTier', () {
    test('returns cloudBorn for a cloudBorn row', () async {
      final now = DateTime.utc(2026, 1, 1);
      final account = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              email: 'cloud@example.com',
              displayName: 'Cloud',
              tier: 'cloudBorn',
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(account.accountTier, UserTier.cloudBorn);
    });

    test('throws StateError (not a silent localBorn fallback) for an '
        'unrecognized tier value — a bad migration or hand-edited row must '
        'be loud, not silently treated as local-born everywhere accountTier '
        'is read (sync gating, balance-row eligibility)', () async {
      final now = DateTime.utc(2026, 1, 1);
      // Insert directly at the Drift layer with a corrupted tier string —
      // bypasses the UserTier enum entirely, simulating a bad migration
      // or hand-edited row on-device.
      final account = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              email: 'corrupt@example.com',
              displayName: 'Corrupt',
              tier: 'notARealTier',
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        () => account.accountTier,
        throwsA(
          isA<DaoInvariantError>().having(
            (e) => e.code,
            'code',
            DaoErrorCode.unknownAccountTier,
          ),
        ),
      );
    });
  });

  // =========================================================================
  // UserProfileDao.findCloudBornByFirebaseUid
  // =========================================================================

  group('UserProfileDao.findCloudBornByFirebaseUid', () {
    test('returns null when no cloud-born account exists', () async {
      final result = await db.userProfileDao.findCloudBornByFirebaseUid(
        'nonexistent-uid',
      );
      expect(result, isNull);
    });

    test('returns cloud-born account by firebaseUid', () async {
      final now = DateTime.utc(2026, 1, 1);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'cloud@example.com',
              displayName: 'Cloud User',
              tier: 'cloudBorn',
              firebaseUid: const Value('uid-cloud-1'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final result = await db.userProfileDao.findCloudBornByFirebaseUid(
        'uid-cloud-1',
      );
      expect(result, isNotNull);
      expect(result!.email, 'cloud@example.com');
      expect(result.tier, 'cloudBorn');
    });

    test('does not return local-born row with same email', () async {
      final now = DateTime.utc(2026, 1, 1);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'local@example.com',
              displayName: 'Local User',
              tier: 'localBorn',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final result = await db.userProfileDao.findCloudBornByFirebaseUid(
        'local@example.com',
      );
      expect(result, isNull);
    });
  });

  // =========================================================================
  // UserProfileDao.findByTier
  // =========================================================================

  group('UserProfileDao.findByTier', () {
    test('returns empty list when no accounts', () async {
      final result = await db.userProfileDao.findByTier(UserTier.cloudBorn);
      expect(result, isEmpty);
    });

    test('returns only cloud-born accounts', () async {
      final now = DateTime.utc(2026, 1, 1);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'cloud@example.com',
              displayName: 'Cloud',
              tier: 'cloudBorn',
              firebaseUid: const Value('uid-123'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'local@example.com',
              displayName: 'Local',
              tier: 'localBorn',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final cloudAccounts = await db.userProfileDao.findByTier(
        UserTier.cloudBorn,
      );
      expect(cloudAccounts, hasLength(1));
      expect(cloudAccounts.first.email, 'cloud@example.com');

      final localAccounts = await db.userProfileDao.findByTier(
        UserTier.localBorn,
      );
      expect(localAccounts, hasLength(1));
      expect(localAccounts.first.email, 'local@example.com');
    });
  });
}
