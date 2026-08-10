import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/domain/value_objects/account_tier.dart';

/// Test double that lets a single test simulate a crash between
/// [removeAccount]'s delete and its `lastActiveAccountId` clear (AUD-core-
/// database-08 / DB-2). [setLastActiveAccountId] is called with an implicit
/// `this` receiver from inside [removeAccount], so overriding it here is
/// enough to inject a fault partway through the method without touching
/// production code.
class _CrashingDeviceRegistryDatabase extends DeviceRegistryDatabase {
  _CrashingDeviceRegistryDatabase(super.e);

  /// When true, the next [setLastActiveAccountId] call throws instead of
  /// writing — simulating a process death after the delete has already
  /// gone to disk but before the pointer-clear commits.
  bool crashOnNextClear = false;

  @override
  Future<void> setLastActiveAccountId(String? accountId) async {
    if (crashOnNextClear) {
      crashOnNextClear = false;
      throw StateError('simulated crash between delete and state-clear');
    }
    return super.setLastActiveAccountId(accountId);
  }
}

void main() {
  late DeviceRegistryDatabase db;

  setUp(() {
    db = DeviceRegistryDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  DeviceAccountsCompanion makeAccount({
    required String id,
    String email = 'test@test.local',
    String tier = 'cloudBorn',
    String? firebaseUid,
    String? dbFileName,
  }) => DeviceAccountsCompanion.insert(
    accountId: id,
    email: email,
    displayName: 'User $id',
    tier: tier,
    firebaseUid: Value(firebaseUid),
    createdAt: DateTime.utc(2026, 1, 1),
    lastUsedAt: DateTime.utc(2026, 1, 1),
    dbFileName: dbFileName ?? 'user_acc_$id.db',
  );

  group('DeviceRegistryDatabase', () {
    test('addAccount inserts and getAllAccounts returns it', () async {
      await db.addAccount(makeAccount(id: 'a1', email: 'alice@test.local'));

      final accounts = await db.getAllAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.first.email, 'alice@test.local');
      expect(accounts.first.accountId, 'a1');
    });

    test('max 5 accounts enforced', () async {
      for (var i = 1; i <= 5; i++) {
        await db.addAccount(makeAccount(id: 'a$i', email: 'user$i@test.local'));
      }
      final accounts = await db.getAllAccounts();
      expect(accounts, hasLength(5));

      expect(
        () => db.addAccount(makeAccount(id: 'a6', email: 'user6@test.local')),
        throwsA(isA<MaxAccountsReachedException>()),
      );

      // Count still 5 after rejected insert
      expect(await db.getAllAccounts(), hasLength(5));
    });

    test('findByEmail is case-insensitive', () async {
      await db.addAccount(makeAccount(id: 'a1', email: 'Alice@Example.COM'));

      final found = await db.findByEmail('alice@example.com');
      expect(found, isNotNull);
      expect(found!.accountId, 'a1');

      final notFound = await db.findByEmail('bob@example.com');
      expect(notFound, isNull);
    });

    test('findByFirebaseUid returns correct match', () async {
      await db.addAccount(makeAccount(id: 'a1', firebaseUid: 'fb-uid-1'));

      final found = await db.findByFirebaseUid('fb-uid-1');
      expect(found, isNotNull);
      expect(found!.accountId, 'a1');

      expect(await db.findByFirebaseUid('fb-uid-nope'), isNull);
    });

    test('removeAccount deletes the row', () async {
      await db.addAccount(makeAccount(id: 'a1'));
      await db.addAccount(makeAccount(id: 'a2', email: 'b@test.local'));

      await db.removeAccount('a1');
      final accounts = await db.getAllAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.first.accountId, 'a2');
    });

    test('updateLastUsed changes the timestamp', () async {
      await db.addAccount(makeAccount(id: 'a1'));

      final newTime = DateTime(2026, 6, 15);
      await db.updateLastUsed('a1', newTime);

      final account = await db.findById('a1');
      expect(account!.lastUsedAt, newTime);
    });

    test('updateAccountTier changes tier and firebaseUid', () async {
      await db.addAccount(makeAccount(id: 'a1', tier: 'localBorn'));

      await db.updateAccountTier('a1', 'cloudBorn', firebaseUid: 'new-fb-uid');

      final account = await db.findById('a1');
      expect(account!.tier, 'cloudBorn');
      expect(account.firebaseUid, 'new-fb-uid');
    });

    test('getAllAccounts orders by lastUsedAt descending', () async {
      await db.addAccount(makeAccount(id: 'a1', email: 'a@t.l'));
      await db.addAccount(makeAccount(id: 'a2', email: 'b@t.l'));
      await db.updateLastUsed('a1', DateTime.utc(2026, 3, 1));
      await db.updateLastUsed('a2', DateTime.utc(2026, 6, 1));

      final accounts = await db.getAllAccounts();
      expect(accounts.first.accountId, 'a2'); // more recent
      expect(accounts.last.accountId, 'a1');
    });
  });

  group('DeviceAccountX.accountTier (AUD-core-database-16, EH-4)', () {
    test('parses "cloudBorn" to AccountTier.cloud', () async {
      await db.addAccount(makeAccount(id: 'a1', tier: 'cloudBorn'));
      final account = await db.findById('a1');
      expect(account!.accountTier, AccountTier.cloud);
    });

    test('parses "localBorn" to AccountTier.local', () async {
      await db.addAccount(makeAccount(id: 'a1', tier: 'localBorn'));
      final account = await db.findById('a1');
      expect(account!.accountTier, AccountTier.local);
    });

    test('falls back to AccountTier.local for an unrecognised stored value '
        'without catching an Error subtype', () async {
      // The tier column is a raw String with no DB-level enum constraint,
      // so a legacy/corrupted row can carry an unrecognised value.
      await db.addAccount(makeAccount(id: 'a1', tier: 'not-a-real-tier'));
      final account = await db.findById('a1');
      expect(account!.accountTier, AccountTier.local);
    });
  });

  group('DeviceState (lastActiveAccountId)', () {
    test('initially null', () async {
      expect(await db.getLastActiveAccountId(), isNull);
    });

    test('set and read back', () async {
      await db.setLastActiveAccountId('a1');
      expect(await db.getLastActiveAccountId(), 'a1');
    });

    test('overwrite with new value', () async {
      await db.setLastActiveAccountId('a1');
      await db.setLastActiveAccountId('a2');
      expect(await db.getLastActiveAccountId(), 'a2');
    });

    test('clear by setting null', () async {
      await db.setLastActiveAccountId('a1');
      await db.setLastActiveAccountId(null);
      expect(await db.getLastActiveAccountId(), isNull);
    });

    test(
      'removeAccount clears it when removing the ACTIVE account (D10)',
      () async {
        await db.addAccount(makeAccount(id: 'a1'));
        await db.addAccount(makeAccount(id: 'a2', email: 'b@test.local'));
        await db.setLastActiveAccountId('a1');

        await db.removeAccount('a1');

        expect(
          await db.getLastActiveAccountId(),
          isNull,
          reason:
              'removing the active account must clear the pointer so the next '
              'launch does not auto-activate an arbitrary fallback account',
        );
      },
    );

    test(
      'removeAccount leaves it when removing a DIFFERENT account (D10)',
      () async {
        await db.addAccount(makeAccount(id: 'a1'));
        await db.addAccount(makeAccount(id: 'a2', email: 'b@test.local'));
        await db.setLastActiveAccountId('a1');

        await db.removeAccount('a2');

        expect(await db.getLastActiveAccountId(), 'a1');
      },
    );

    test(
      'survives DB close and reopen (in-memory is fresh, but API works)',
      () async {
        // With in-memory DB this just validates the API contract
        await db.setLastActiveAccountId('a1');
        expect(await db.getLastActiveAccountId(), 'a1');
      },
    );

    test('removeAccount rolls back the delete if the state-clear throws '
        'mid-method (crash-safety, DB-2 / AUD-core-database-08)', () async {
      final crashingDb = _CrashingDeviceRegistryDatabase(
        NativeDatabase.memory(),
      );
      addTearDown(crashingDb.close);

      await crashingDb.addAccount(makeAccount(id: 'a1'));
      await crashingDb.addAccount(makeAccount(id: 'a2', email: 'b@test.local'));
      await crashingDb.setLastActiveAccountId('a1');

      crashingDb.crashOnNextClear = true;

      await expectLater(
        () => crashingDb.removeAccount('a1'),
        throwsA(isA<StateError>()),
      );

      // Neither write may have applied: the row must still exist AND the
      // pointer must still reference it — a bare exception between two
      // un-transacted writes must not leave a half-applied removal.
      final accounts = await crashingDb.getAllAccounts();
      expect(
        accounts.map((a) => a.accountId),
        contains('a1'),
        reason:
            'the delete must roll back when the state-clear throws before '
            'the operation commits (transaction() required by DB-2)',
      );
      expect(
        await crashingDb.getLastActiveAccountId(),
        'a1',
        reason:
            'the pointer-clear must roll back together with the delete — '
            'a torn write here is the exact D10 dangling-pointer state '
            'removeAccount exists to prevent',
      );
    });
  });

  // ─── dedupeByEmail — heals "two cards in the account picker" symptom ────
  //
  // When a user deletes their cloud account server-side and re-signs-up
  // with the same email, Firebase Auth mints a new uid. The old registry
  // row still exists; the new sign-in pre-fix added a second row. This
  // method merges the email group down to the most-recently-used row.

  group('dedupeByEmail', () {
    test('is a no-op when no duplicates exist', () async {
      await db.addAccount(makeAccount(id: 'a1', email: 'alice@test.local'));
      await db.addAccount(makeAccount(id: 'a2', email: 'bob@test.local'));

      final removed = await db.dedupeByEmail();

      expect(removed, 0);
      final accounts = await db.getAllAccounts();
      expect(accounts.map((a) => a.accountId).toSet(), {'a1', 'a2'});
    });

    test(
      'keeps the most-recently-used row when two share an email, removes the older',
      () async {
        // a_old was used earlier; a_new is the recent re-signup.
        await db.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'a_old',
            email: 'family@example.com',
            displayName: 'Family Niasoff',
            tier: 'cloudBorn',
            firebaseUid: const Value('uid_deleted'),
            dbFileName: 'user_acc_a_old.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 5, 20, 10, 0, 0),
          ),
        );
        await db.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'a_new',
            email: 'family@example.com',
            displayName: 'Family Niasoff',
            tier: 'cloudBorn',
            firebaseUid: const Value('uid_resignup'),
            dbFileName: 'user_acc_a_new.db',
            createdAt: DateTime.utc(2026, 5, 21),
            lastUsedAt: DateTime.utc(2026, 5, 21, 19, 0, 0),
          ),
        );

        final removed = await db.dedupeByEmail();

        expect(removed, 1);
        final accounts = await db.getAllAccounts();
        expect(accounts, hasLength(1));
        expect(accounts.first.accountId, 'a_new');
      },
    );

    test('groups case-insensitively', () async {
      await db.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'lower',
          email: 'mixedcase@test.local',
          displayName: 'lower',
          tier: 'cloudBorn',
          dbFileName: 'user_acc_lower.db',
          createdAt: DateTime.utc(2026, 1, 1),
          lastUsedAt: DateTime.utc(2026, 5, 20),
        ),
      );
      await db.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'upper',
          email: 'MixedCase@test.local',
          displayName: 'upper',
          tier: 'cloudBorn',
          dbFileName: 'user_acc_upper.db',
          createdAt: DateTime.utc(2026, 5, 21),
          lastUsedAt: DateTime.utc(2026, 5, 21),
        ),
      );

      final removed = await db.dedupeByEmail();

      expect(removed, 1);
      final accounts = await db.getAllAccounts();
      expect(accounts.single.accountId, 'upper');
    });

    test('multi-email duplicates are deduped independently', () async {
      // Two duplicates on email A, two duplicates on email B, one unique.
      for (final spec in [
        ('a_older', 'a@test.local', DateTime.utc(2026, 5, 19)),
        ('a_newer', 'a@test.local', DateTime.utc(2026, 5, 21)),
        ('b_older', 'b@test.local', DateTime.utc(2026, 5, 18)),
        ('b_newer', 'b@test.local', DateTime.utc(2026, 5, 20)),
        ('c_only', 'c@test.local', DateTime.utc(2026, 5, 17)),
      ]) {
        await db.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: spec.$1,
            email: spec.$2,
            displayName: spec.$1,
            tier: 'cloudBorn',
            dbFileName: 'user_acc_${spec.$1}.db',
            createdAt: spec.$3,
            lastUsedAt: spec.$3,
          ),
        );
      }

      final removed = await db.dedupeByEmail();

      expect(removed, 2);
      final accounts = await db.getAllAccounts();
      expect(accounts.map((a) => a.accountId).toSet(), {
        'a_newer',
        'b_newer',
        'c_only',
      });
    });

    test(
      'skips rows with blank/whitespace-only emails (legacy tolerance)',
      () async {
        await db.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'blank1',
            email: '',
            displayName: 'blank1',
            tier: 'cloudBorn',
            dbFileName: 'user_acc_blank1.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 5, 20),
          ),
        );
        await db.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'blank2',
            email: '   ',
            displayName: 'blank2',
            tier: 'cloudBorn',
            dbFileName: 'user_acc_blank2.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 5, 21),
          ),
        );

        final removed = await db.dedupeByEmail();

        // Blank-email rows are not grouped (one anomaly per row); leave both.
        expect(removed, 0);
        expect(await db.getAllAccounts(), hasLength(2));
      },
    );
  });
}
