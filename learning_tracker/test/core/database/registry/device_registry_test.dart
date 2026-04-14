import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';

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
  }) =>
      DeviceAccountsCompanion.insert(
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
        await db.addAccount(
          makeAccount(id: 'a$i', email: 'user$i@test.local'),
        );
      }
      final accounts = await db.getAllAccounts();
      expect(accounts, hasLength(5));

      expect(
        () => db.addAccount(
          makeAccount(id: 'a6', email: 'user6@test.local'),
        ),
        throwsA(isA<MaxAccountsReachedException>()),
      );

      // Count still 5 after rejected insert
      expect(await db.getAllAccounts(), hasLength(5));
    });

    test('findByEmail is case-insensitive', () async {
      await db.addAccount(
        makeAccount(id: 'a1', email: 'Alice@Example.COM'),
      );

      final found = await db.findByEmail('alice@example.com');
      expect(found, isNotNull);
      expect(found!.accountId, 'a1');

      final notFound = await db.findByEmail('bob@example.com');
      expect(notFound, isNull);
    });

    test('findByFirebaseUid returns correct match', () async {
      await db.addAccount(
        makeAccount(id: 'a1', firebaseUid: 'fb-uid-1'),
      );

      final found = await db.findByFirebaseUid('fb-uid-1');
      expect(found, isNotNull);
      expect(found!.accountId, 'a1');

      expect(await db.findByFirebaseUid('fb-uid-nope'), isNull);
    });

    test('removeAccount deletes the row', () async {
      await db.addAccount(makeAccount(id: 'a1'));
      await db.addAccount(
        makeAccount(id: 'a2', email: 'b@test.local'),
      );

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
      await db.addAccount(
        makeAccount(id: 'a1', tier: 'localBorn'),
      );

      await db.updateAccountTier('a1', 'cloudBorn',
          firebaseUid: 'new-fb-uid');

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

    test('survives DB close and reopen (in-memory is fresh, but API works)',
        () async {
      // With in-memory DB this just validates the API contract
      await db.setLastActiveAccountId('a1');
      expect(await db.getLastActiveAccountId(), 'a1');
    });
  });
}
