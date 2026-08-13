import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

Future<FakeFirebaseFirestore> restoreForTest(
  Map<String, dynamic> payload,
) async {
  final restored = FakeFirebaseFirestore();
  await backupService(restored).importData(jsonEncode(payload));
  return restored;
}

void main() {
  test(
    'export→import on an empty Firestore instance leaves it empty again',
    () async {
      final source = FakeFirebaseFirestore();
      final payload = await backupService(source).exportData();
      final target = FakeFirebaseFirestore();
      await backupService(target).importData(payload);
      expect((await target.collection('users').get()).docs, isEmpty);
    },
  );

  test(
    'import rejects malformed JSON with ImportValidationException',
    () async {
      expect(
        () => backupService(FakeFirebaseFirestore()).importData('not json'),
        throwsA(isA<ImportValidationException>()),
      );
    },
  );

  test('validateAndPreview rejects completely invalid JSON', () async {
    expect(
      () => backupService(
        FakeFirebaseFirestore(),
      ).validateAndPreview('{bad json'),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test('import rejects a payload with no version field', () async {
    final payload = {
      'uid': testUid,
      'account': {'id': testUid, 'data': null},
      'profileSnapshot': <dynamic>[],
      'diagnosticLogs': <dynamic>[],
      'profiles': <dynamic>[],
    };
    expect(
      () => backupService(
        FakeFirebaseFirestore(),
      ).importData(jsonEncode(payload)),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test('import rejects unsupported future versions', () async {
    final source = FakeFirebaseFirestore();
    final payload = await exportedMap(backupService(source));
    payload['version'] = 2;
    expect(
      () => backupService(source).importData(jsonEncode(payload)),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test(
    'import rejects a payload missing a required top-level section',
    () async {
      final payload = {
        'version': 1,
        'uid': testUid,
        'account': {'id': testUid, 'data': null},
        'profileSnapshot': <dynamic>[],
        'profiles': <dynamic>[],
      };
      expect(
        () => backupService(
          FakeFirebaseFirestore(),
        ).importData(jsonEncode(payload)),
        throwsA(isA<ImportValidationException>()),
      );
    },
  );

  test('import never deletes documents absent from the backup', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, uid: testUid, profileId: testProfileId);
    final service = backupService(firestore);
    final payload = await exportedMap(service);
    final profile = profileFrom(payload, testProfileId);
    final collections = profile['collections'] as Map<String, dynamic>;
    collections['preferences'] = [
      {
        'id': 'kept',
        'data': {'value': 1},
      },
    ];

    await firestore
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('preferences')
        .doc('unrelated')
        .set({'value': 2});
    await service.importData(jsonEncode(payload));

    final docs = await firestore
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('preferences')
        .get();
    expect(docs.docs.map((doc) => doc.id), containsAll(['kept', 'unrelated']));
  });

  test('import inserts an account document from a valid backup', () async {
    final source = FakeFirebaseFirestore();
    await seedAccount(source, uid: testUid, displayName: 'First');
    final target = FakeFirebaseFirestore();
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final account = await target.collection('users').doc(testUid).get();
    expect(account.exists, isTrue);
    expect(account.data()!['display_name'], 'First');
  });

  test(
    'second import is idempotent rather than wiping the first backup',
    () async {
      final source = FakeFirebaseFirestore();
      await seedProfile(source, uid: testUid, profileId: testProfileId);
      await source
          .collection('users')
          .doc(testUid)
          .collection('learner_profiles')
          .doc(testProfileId)
          .collection('preferences')
          .doc('one')
          .set({'value': 1});
      final payload = await backupService(source).exportData();
      final target = FakeFirebaseFirestore();
      final service = backupService(target);
      await service.importData(payload);
      await service.importData(payload);
      expect(
        (await target
                .collection('users')
                .doc(testUid)
                .collection('learner_profiles')
                .doc(testProfileId)
                .collection('preferences')
                .get())
            .docs,
        hasLength(1),
      );
    },
  );

  test('export→import→export preserves the complete logical payload', () async {
    final source = FakeFirebaseFirestore();
    await seedProfile(source, uid: testUid, profileId: testProfileId);
    await source
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('preferences')
        .doc('one')
        .set({
          'value': 1,
          'nested': {'kept': true},
        });
    final first = await exportedMap(backupService(source));
    final restored = await restoreForTest(first);
    final second = await exportedMap(backupService(restored));
    first.remove('exportedAt');
    second.remove('exportedAt');
    expect(second, first);
  });

  test('validateAndPreview rejects a non-list profile section', () async {
    final source = FakeFirebaseFirestore();
    final payload = await exportedMap(backupService(source));
    payload['profiles'] = 'not-a-list';
    expect(
      () => backupService(source).validateAndPreview(jsonEncode(payload)),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test(
    'preflight validation prevents partial writes for malformed nested data',
    () async {
      final source = FakeFirebaseFirestore();
      await seedProfile(source, uid: testUid, profileId: testProfileId);
      final payload = await exportedMap(backupService(source));
      final profile = profileFrom(payload, testProfileId);
      final collections = profile['collections'] as Map<String, dynamic>;
      collections['preferences'] = [
        {'id': 'bad', 'data': 'not-an-object'},
      ];

      final target = FakeFirebaseFirestore();
      expect(
        () => backupService(target).importData(jsonEncode(payload)),
        throwsA(isA<ImportValidationException>()),
      );
      expect((await target.collection('users').get()).docs, isEmpty);
    },
  );

  test(
    'preview counts nested collections and accepts an empty backup',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = backupService(firestore);
      final preview = service.validateAndPreview(await service.exportData());
      expect(preview.totalRecords, 0);
      expect(preview.userProfileCount, 0);
      expect(preview.ledgerCount, 0);
    },
  );
}
