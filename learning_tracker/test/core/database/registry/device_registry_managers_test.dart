/// Tests for DeviceRegistryDatabase managers (filter/orderBy) and
/// DeviceAccount/DeviceState DataClass methods.
///
/// Raises coverage on device_registry_database.g.dart by exercising:
///   • $$DeviceAccountsTableFilterComposer — all filter fields
///   • $$DeviceAccountsTableOrderingComposer — orderBy fields
///   • $$DeviceAccountsTableTableManager — CRUD via managers API
///   • DeviceAccountsCompanion.custom() and toString()
///   • DeviceAccount DataClass methods (toColumns, copyWith, etc.)
///   • DeviceStateCompanion.custom() and toString()
///   • DeviceStateData DataClass methods
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';

void main() {
  late DeviceRegistryDatabase db;

  final now = DateTime.utc(2026, 3, 1, 12);

  setUp(() {
    db = DeviceRegistryDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DeviceAccountsCompanion makeAccountCompanion({
    required String id,
    String email = 'test@test.local',
    String tier = 'cloudBorn',
    String? firebaseUid,
    int avatarIndex = 0,
  }) => DeviceAccountsCompanion.insert(
    accountId: id,
    email: email,
    displayName: 'User $id',
    tier: tier,
    firebaseUid: Value(firebaseUid),
    avatarIndex: Value(avatarIndex),
    createdAt: now,
    lastUsedAt: now,
    dbFileName: 'user_acc_$id.db',
  );

  // ─── DeviceAccountsCompanion Companion methods ────────────────────────────

  group('DeviceAccountsCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = DeviceAccountsCompanion(
        accountId: Value('abc123'),
        email: Value('user@test.local'),
        tier: Value('cloudBorn'),
        displayName: Value('User'),
      );
      final s = c.toString();
      expect(s, contains('DeviceAccountsCompanion'));
      expect(s, contains('accountId'));
      expect(s, contains('email'));
      expect(s, contains('tier'));
      expect(s, contains('firebaseUid'));
      expect(s, contains('avatarIndex'));
      expect(s, contains('rowid'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = DeviceAccountsCompanion.custom(
        accountId: const Variable('raw-acc'),
        email: const Variable('raw@test.local'),
        displayName: const Variable('Raw User'),
        tier: const Variable('localBorn'),
        firebaseUid: const Variable('fb-raw'),
        avatarIndex: const Variable(2),
        createdAt: Variable(now),
        lastUsedAt: Variable(now),
        dbFileName: const Variable('raw.db'),
        rowid: const Variable(42),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('account_id'), isTrue);
      expect(cols.containsKey('firebase_uid'), isTrue);
      expect(cols.containsKey('avatar_index'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('toColumns with all fields present', () {
      final c = DeviceAccountsCompanion(
        accountId: const Value('id1'),
        email: const Value('e@t.l'),
        displayName: const Value('Disp'),
        tier: const Value('cloudBorn'),
        firebaseUid: const Value('fb-1'),
        avatarIndex: const Value(1),
        createdAt: Value(now),
        lastUsedAt: Value(now),
        dbFileName: const Value('f.db'),
        rowid: const Value(1),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('account_id'), isTrue);
      expect(cols.containsKey('firebase_uid'), isTrue);
      expect(cols.containsKey('avatar_index'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('copyWith preserves absent fields and overrides present ones', () {
      final original = makeAccountCompanion(id: 'c1', email: 'a@t.l');
      final copy = original.copyWith(
        email: const Value('b@t.l'),
        firebaseUid: const Value('fb-new'),
      );
      expect(copy.accountId.value, 'c1');
      expect(copy.email.value, 'b@t.l');
      expect(copy.firebaseUid.value, 'fb-new');
    });
  });

  // ─── DeviceAccount DataClass methods ─────────────────────────────────────

  group('DeviceAccount DataClass', () {
    Future<DeviceAccount> insertAndGet(String id, {String? firebaseUid}) async {
      await db.addAccount(makeAccountCompanion(id: id, firebaseUid: firebaseUid));
      return (await db.findById(id))!;
    }

    test('toJson / fromJson round-trip', () async {
      final account = await insertAndGet('da1', firebaseUid: 'fb-da1');
      final json = account.toJson();
      expect(json['accountId'], 'da1');
      expect(json['firebaseUid'], 'fb-da1');

      final restored = DeviceAccount.fromJson(json);
      expect(restored.accountId, account.accountId);
      expect(restored.firebaseUid, account.firebaseUid);
      expect(restored, equals(account));
    });

    test('toJson / fromJson with null firebaseUid', () async {
      final account = await insertAndGet('da2');
      final json = account.toJson();
      expect(json['firebaseUid'], isNull);

      final restored = DeviceAccount.fromJson(json);
      expect(restored.firebaseUid, isNull);
    });

    test('copyWith changes specific fields', () async {
      final account = await insertAndGet('da3');
      final copy = account.copyWith(
        displayName: 'Updated Name',
        tier: 'localBorn',
        firebaseUid: const Value('fb-da3'),
      );
      expect(copy.accountId, 'da3');
      expect(copy.displayName, 'Updated Name');
      expect(copy.tier, 'localBorn');
      expect(copy.firebaseUid, 'fb-da3');
    });

    test('copyWithCompanion applies companion changes', () async {
      final account = await insertAndGet('da4');
      final copy = account.copyWithCompanion(
        const DeviceAccountsCompanion(
          displayName: Value('Companion Updated'),
          avatarIndex: Value(5),
        ),
      );
      expect(copy.accountId, 'da4');
      expect(copy.displayName, 'Companion Updated');
      expect(copy.avatarIndex, 5);
    });

    test('toColumns with non-null firebaseUid', () async {
      final account = await insertAndGet('da5', firebaseUid: 'fb-da5');
      final cols = account.toColumns(true);
      expect(cols.containsKey('firebase_uid'), isTrue);

      // Also nullToAbsent=false variant
      final colsNoAbsent = account.toColumns(false);
      expect(colsNoAbsent.containsKey('firebase_uid'), isTrue);
    });

    test('toColumns with null firebaseUid and nullToAbsent=false', () async {
      final account = await insertAndGet('da6');
      final cols = account.toColumns(false);
      // When nullToAbsent=false, firebase_uid is included even when null
      expect(cols.containsKey('firebase_uid'), isTrue);
    });

    test('toCompanion with nullToAbsent=false includes nullable field', () async {
      final account = await insertAndGet('da7', firebaseUid: 'fb-da7');
      final companion = account.toCompanion(false);
      expect(companion.accountId.value, 'da7');
      expect(companion.firebaseUid.value, 'fb-da7');
      expect(companion.firebaseUid.present, isTrue);
    });

    test('toCompanion with nullToAbsent=true omits null nullable field', () async {
      final account = await insertAndGet('da8');
      final companion = account.toCompanion(true);
      expect(companion.accountId.value, 'da8');
      expect(companion.firebaseUid.present, isFalse);
    });

    test('toString covers StringBuffer body', () async {
      final account = await insertAndGet('da9', firebaseUid: 'fb-da9');
      final s = account.toString();
      expect(s, contains('DeviceAccount'));
      expect(s, contains('da9'));
      expect(s, contains('fb-da9'));
    });

    test('hashCode and == work correctly', () async {
      final a1 = await insertAndGet('da10');
      final a2 = await db.findById('da10');
      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2!.hashCode));

      final a3 = await insertAndGet('da11');
      expect(a1, isNot(equals(a3)));
    });
  });

  // ─── DeviceStateData DataClass methods ───────────────────────────────────

  group('DeviceStateData DataClass', () {
    test('toJson / fromJson round-trip with value', () async {
      await db.setLastActiveAccountId('acc-state-1');
      final id = await db.getLastActiveAccountId();
      expect(id, 'acc-state-1');
    });

    test('DeviceStateData toString covers StringBuffer', () {
      const d = DeviceStateData(key: 'last_account', value: 'acc-123');
      final s = d.toString();
      expect(s, contains('DeviceStateData'));
      expect(s, contains('last_account'));
      expect(s, contains('acc-123'));
    });

    test('DeviceStateData toJson / fromJson round-trip', () {
      const d = DeviceStateData(key: 'some_key', value: 'some_value');
      final json = d.toJson();
      expect(json['key'], 'some_key');
      expect(json['value'], 'some_value');

      final restored = DeviceStateData.fromJson(json);
      expect(restored.key, 'some_key');
      expect(restored.value, 'some_value');
      expect(restored, equals(d));
    });

    test('DeviceStateData fromJson with null value', () {
      final json = {'key': 'k', 'value': null};
      final d = DeviceStateData.fromJson(json);
      expect(d.key, 'k');
      expect(d.value, isNull);
    });

    test('DeviceStateData copyWith', () {
      const d = DeviceStateData(key: 'k', value: 'v1');
      final copy1 = d.copyWith(value: const Value('v2'));
      expect(copy1.key, 'k');
      expect(copy1.value, 'v2');

      // copyWith with absent Value preserves original value
      final copy2 = d.copyWith(key: 'k2');
      expect(copy2.key, 'k2');
      expect(copy2.value, 'v1');
    });

    test('DeviceStateData copyWithCompanion', () {
      const d = DeviceStateData(key: 'k', value: 'old');
      final copy = d.copyWithCompanion(
        const DeviceStateCompanion(value: Value('new')),
      );
      expect(copy.key, 'k');
      expect(copy.value, 'new');
    });

    test('DeviceStateData toColumns with value present', () {
      const d = DeviceStateData(key: 'k', value: 'v');
      final cols = d.toColumns(true);
      expect(cols.containsKey('key'), isTrue);
      expect(cols.containsKey('value'), isTrue);

      final colsNoAbsent = d.toColumns(false);
      expect(colsNoAbsent.containsKey('value'), isTrue);
    });

    test('DeviceStateData toColumns with null value and nullToAbsent=true', () {
      const d = DeviceStateData(key: 'k');
      final cols = d.toColumns(true);
      expect(cols.containsKey('key'), isTrue);
      expect(cols.containsKey('value'), isFalse);

      // nullToAbsent=false includes null
      final colsNoAbsent = d.toColumns(false);
      expect(colsNoAbsent.containsKey('value'), isTrue);
    });

    test('DeviceStateData hashCode and ==', () {
      const d1 = DeviceStateData(key: 'k', value: 'v');
      const d2 = DeviceStateData(key: 'k', value: 'v');
      const d3 = DeviceStateData(key: 'other', value: 'v');
      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1, isNot(equals(d3)));
    });
  });

  // ─── DeviceStateCompanion ─────────────────────────────────────────────────

  group('DeviceStateCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = DeviceStateCompanion(
        key: Value('my_key'),
        value: Value('my_value'),
      );
      final s = c.toString();
      expect(s, contains('DeviceStateCompanion'));
      expect(s, contains('my_key'));
      expect(s, contains('rowid'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = DeviceStateCompanion.custom(
        key: const Variable('custom_key'),
        value: const Variable('custom_value'),
        rowid: const Variable(99),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('key'), isTrue);
      expect(cols.containsKey('value'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('toColumns with all fields present', () {
      const c = DeviceStateCompanion(
        key: Value('k'),
        value: Value('v'),
        rowid: Value(1),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('key'), isTrue);
      expect(cols.containsKey('value'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('copyWith', () {
      const c = DeviceStateCompanion(key: Value('k'), value: Value('v'));
      final copy = c.copyWith(value: const Value('v2'), rowid: const Value(5));
      expect(copy.key.value, 'k');
      expect(copy.value.value, 'v2');
      expect(copy.rowid.value, 5);
    });
  });

  // ─── managers.deviceAccounts — filter and orderBy ─────────────────────────

  group('managers.deviceAccounts — filter', () {
    setUp(() async {
      await db.addAccount(makeAccountCompanion(
        id: 'f1',
        email: 'a@test.local',
        tier: 'localBorn',
        firebaseUid: null,
        avatarIndex: 1,
      ));
      await db.addAccount(makeAccountCompanion(
        id: 'f2',
        email: 'b@test.local',
        tier: 'cloudBorn',
        firebaseUid: 'fb-f2',
        avatarIndex: 2,
      ));
      await db.addAccount(makeAccountCompanion(
        id: 'f3',
        email: 'c@test.local',
        tier: 'cloudBorn',
        firebaseUid: 'fb-f3',
        avatarIndex: 0,
      ));
    });

    test('filter by accountId', () async {
      final rows = await db.managers.deviceAccounts
          .filter((f) => f.accountId('f1'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.accountId, 'f1');
    });

    test('filter by email', () async {
      final rows = await db.managers.deviceAccounts
          .filter((f) => f.email('b@test.local'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.accountId, 'f2');
    });

    test('filter by displayName', () async {
      final rows = await db.managers.deviceAccounts
          .filter((f) => f.displayName('User f2'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by tier', () async {
      final cloudRows = await db.managers.deviceAccounts
          .filter((f) => f.tier('cloudBorn'))
          .get();
      expect(cloudRows, hasLength(2));

      final localRows = await db.managers.deviceAccounts
          .filter((f) => f.tier('localBorn'))
          .get();
      expect(localRows, hasLength(1));
    });

    test('filter by firebaseUid', () async {
      final rows = await db.managers.deviceAccounts
          .filter((f) => f.firebaseUid('fb-f2'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.accountId, 'f2');
    });

    test('filter by avatarIndex', () async {
      final rows = await db.managers.deviceAccounts
          .filter((f) => f.avatarIndex(1))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.accountId, 'f1');
    });

    test('filter by createdAt', () async {
      final rows = await db.managers.deviceAccounts
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, hasLength(3));
    });

    test('filter by lastUsedAt', () async {
      final rows = await db.managers.deviceAccounts
          .filter((f) => f.lastUsedAt(now))
          .get();
      expect(rows, hasLength(3));
    });

    test('filter by dbFileName', () async {
      final rows = await db.managers.deviceAccounts
          .filter((f) => f.dbFileName('user_acc_f1.db'))
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy accountId asc', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.accountId.asc())
          .get();
      expect(rows.map((r) => r.accountId).toList(), ['f1', 'f2', 'f3']);
    });

    test('orderBy email desc', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.email.desc())
          .get();
      expect(rows.first.email, 'c@test.local');
    });

    test('orderBy displayName', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.displayName.asc())
          .get();
      expect(rows, hasLength(3));
    });

    test('orderBy tier', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.tier.asc())
          .get();
      expect(rows, hasLength(3));
    });

    test('orderBy firebaseUid', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.firebaseUid.asc())
          .get();
      expect(rows, hasLength(3));
    });

    test('orderBy avatarIndex desc', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.avatarIndex.desc())
          .get();
      expect(rows.first.avatarIndex, 2);
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(3));
    });

    test('orderBy lastUsedAt', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.lastUsedAt.desc())
          .get();
      expect(rows, hasLength(3));
    });

    test('orderBy dbFileName', () async {
      final rows = await db.managers.deviceAccounts
          .orderBy((o) => o.dbFileName.asc())
          .get();
      expect(rows.first.dbFileName, 'user_acc_f1.db');
    });

    test('managers count', () async {
      final count = await db.managers.deviceAccounts.count();
      expect(count, 3);
    });

    test('managers delete', () async {
      await db.managers.deviceAccounts
          .filter((f) => f.accountId('f1'))
          .delete();
      final count = await db.managers.deviceAccounts.count();
      expect(count, 2);
    });
  });

  // ─── managers.deviceState ─────────────────────────────────────────────────

  group('managers.deviceState — filter and orderBy', () {
    test('insert and filter by key', () async {
      await db.setLastActiveAccountId('ds-acc-1');

      final rows = await db.managers.deviceState
          .filter((f) => f.key('lastActiveAccountId'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.value, 'ds-acc-1');
    });

    test('filter by value', () async {
      await db.setLastActiveAccountId('ds-acc-2');

      final rows = await db.managers.deviceState
          .filter((f) => f.value('ds-acc-2'))
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy key', () async {
      await db.setLastActiveAccountId('ds-acc-3');
      final rows = await db.managers.deviceState
          .orderBy((o) => o.key.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy value', () async {
      await db.setLastActiveAccountId('ds-acc-4');
      final rows = await db.managers.deviceState
          .orderBy((o) => o.value.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('managers count', () async {
      expect(await db.managers.deviceState.count(), 0);
      await db.setLastActiveAccountId('acc-5');
      expect(await db.managers.deviceState.count(), 1);
    });
  });

  // ─── validateIntegrity missing paths ─────────────────────────────────────

  group('validateIntegrity missing paths', () {
    test('insert DeviceAccount without accountId throws', () {
      expect(
        () => db.into(db.deviceAccounts).insert(const DeviceAccountsCompanion()),
        throwsA(anything),
      );
    });

    test('insert DeviceState without key throws', () {
      expect(
        () => db.into(db.deviceState).insert(const DeviceStateCompanion()),
        throwsA(anything),
      );
    });
  });
}
