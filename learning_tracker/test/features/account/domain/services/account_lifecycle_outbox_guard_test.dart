// Regression test for AUD-account-01: removeCloudFromDevice() must refuse to
// delete a cloud-born account's local DB file while it still has undrained
// outbox rows -- those rows are the only copy of a mutation until the push
// pipeline drains them, and the confirmation dialog promises "your cloud
// data is safe" unconditionally today. See:
//   docs/audits/standards-audit-2026-07-03/delivery/findings/AUD-account-01.json
//
// BUG LOG:
//   - RED (pre-fix): "blocks removal when outbox has undrained rows" failed
//     because removeCloudFromDevice deleted the .sqlite file unconditionally,
//     with zero OutboxDao.depth() check anywhere in the method.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/account/domain/services/account_lifecycle_service.dart';
import 'package:mocktail/mocktail.dart';

class MockRegistry extends Mock implements DeviceRegistryDatabase {}

DeviceAccount _cloudAccount({
  required String accountId,
  required String dbFileName,
}) {
  final now = DateTime.now();
  return DeviceAccount(
    accountId: accountId,
    email: '$accountId@example.com',
    displayName: 'Test $accountId',
    tier: 'cloudBorn',
    firebaseUid: 'uid-$accountId',
    dbFileName: dbFileName,
    avatarIndex: 0,
    createdAt: now,
    lastUsedAt: now,
  );
}

Future<void> _insertOutboxRow(File driftFile, {required int profileId}) async {
  final db = UserDatabase(NativeDatabase(driftFile));
  try {
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: 'completion',
            entityKey: 'k-1',
            payload: '{}',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
  } finally {
    await db.close();
  }
}

void main() {
  group('AccountLifecycleService.removeCloudFromDevice — outbox guard', () {
    late Directory tempDir;
    late MockRegistry registry;
    late AccountLifecycleService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'acct_lifecycle_outbox_test_',
      );
      registry = MockRegistry();
      service = AccountLifecycleService(
        registry: registry,
        databasesPath: tempDir.path,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('blocks removal and preserves the DB file when the outbox has '
        'undrained rows', () async {
      const accountId = 'acc-undrained';
      const dbFileName = 'user_acc_undrained.db';
      final driftFile = File('${tempDir.path}/$dbFileName.sqlite');

      // Seed a real Drift DB (not a blank file) with one pending outbox
      // row on profile 1 -- an offline completion that hasn't synced yet.
      await _insertOutboxRow(driftFile, profileId: 1);

      when(() => registry.findById(accountId)).thenAnswer(
        (_) async =>
            _cloudAccount(accountId: accountId, dbFileName: dbFileName),
      );

      await expectLater(
        service.removeCloudFromDevice(accountId),
        throwsA(isA<UndrainedOutboxException>()),
      );

      expect(
        driftFile.existsSync(),
        isTrue,
        reason:
            'the DB file (and its one unsynced outbox row) must survive a '
            'blocked removal',
      );
      verifyNever(() => registry.removeAccount(accountId));
    });

    test(
      'sums undrained rows across every profile under the account',
      () async {
        const accountId = 'acc-multi-profile';
        const dbFileName = 'user_acc_multi.db';
        final driftFile = File('${tempDir.path}/$dbFileName.sqlite');

        // Two profiles under the same account, each with a pending row.
        await _insertOutboxRow(driftFile, profileId: 1);
        await _insertOutboxRow(driftFile, profileId: 2);

        when(() => registry.findById(accountId)).thenAnswer(
          (_) async =>
              _cloudAccount(accountId: accountId, dbFileName: dbFileName),
        );

        UndrainedOutboxException? caught;
        try {
          await service.removeCloudFromDevice(accountId);
        } on UndrainedOutboxException catch (e) {
          caught = e;
        }

        expect(caught, isNotNull);
        expect(
          caught!.pendingCount,
          2,
          reason: 'depth must be summed across both profiles, not just one',
        );
      },
    );

    test('still succeeds when the outbox is fully drained (no happy-path '
        'regression)', () async {
      const accountId = 'acc-drained';
      const dbFileName = 'user_acc_drained.db';
      final driftFile = File('${tempDir.path}/$dbFileName.sqlite');

      // Create a real (empty-schema) Drift DB with zero outbox rows --
      // mirrors a cloud account whose outbox has fully pushed.
      final db = UserDatabase(NativeDatabase(driftFile));
      await db.close();

      when(() => registry.findById(accountId)).thenAnswer(
        (_) async =>
            _cloudAccount(accountId: accountId, dbFileName: dbFileName),
      );
      when(() => registry.removeAccount(accountId)).thenAnswer((_) async => 1);

      await service.removeCloudFromDevice(accountId);

      expect(
        driftFile.existsSync(),
        isFalse,
        reason: 'a fully-drained outbox must not block removal',
      );
      verify(() => registry.removeAccount(accountId)).called(1);
    });
  });
}
