// Regression test: AccountLifecycleService._deleteDbFile must delete the
// drift_flutter file which is "$dbFileName.sqlite" on the filesystem,
// NOT the bare "$dbFileName".
//
// drift_flutter 0.2.8 src/native.dart line 51: `'$name.sqlite'`
// So driftDatabase(name:'user_acc_xxx.db') → "user_acc_xxx.db.sqlite" on disk.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/features/account/domain/services/account_lifecycle_service.dart';
import 'package:mocktail/mocktail.dart';

class MockRegistry extends Mock implements DeviceRegistryDatabase {}

DeviceAccount _makeAccount({
  required String accountId,
  required String tier,
  required String dbFileName,
  String? firebaseUid,
}) {
  final now = DateTime.now();
  return DeviceAccount(
    accountId: accountId,
    email: '$accountId@example.com',
    displayName: 'Test $accountId',
    tier: tier,
    dbFileName: dbFileName,
    firebaseUid: firebaseUid,
    avatarIndex: 0,
    createdAt: now,
    lastUsedAt: now,
  );
}

void main() {
  group(
    'AccountLifecycleService._deleteDbFile — drift_flutter .sqlite suffix',
    () {
      late Directory tempDir;
      late MockRegistry registry;
      late AccountLifecycleService service;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('acct_lifecycle_test_');
        registry = MockRegistry();
        service = AccountLifecycleService(
          registry: registry,
          databasesPath: tempDir.path,
        );
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      test(
        'removeCloudFromDevice deletes the drift_flutter .sqlite file',
        () async {
          const accountId = 'acc-del-cloud';
          const dbFileName = 'user_acc_cloud.db';
          final driftFile = File('${tempDir.path}/$dbFileName.sqlite');
          await driftFile.create();

          when(() => registry.findById(accountId)).thenAnswer(
            (_) async => _makeAccount(
              accountId: accountId,
              tier: 'cloudBorn',
              dbFileName: dbFileName,
              firebaseUid: 'uid-cloud',
            ),
          );
          when(
            () => registry.removeAccount(accountId),
          ).thenAnswer((_) async => 1);

          await service.removeCloudFromDevice(accountId);

          expect(
            driftFile.existsSync(),
            isFalse,
            reason:
                'removeCloudFromDevice must delete the .sqlite-suffixed drift file',
          );
          verify(() => registry.removeAccount(accountId)).called(1);
        },
      );
    },
  );
}
