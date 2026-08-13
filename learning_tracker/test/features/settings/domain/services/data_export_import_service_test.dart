import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  test(
    'validateAndPreview reports backup metadata and document counts',
    () async {
      final firestore = FakeFirebaseFirestore();
      await seedAccount(firestore, uid: testUid);
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      final service = backupService(firestore, appVersion: '1.2.3');

      final preview = service.validateAndPreview(await service.exportData());
      expect(preview.userProfileCount, 1);
      expect(preview.appVersion, '1.2.3');
      expect(preview.exportedAt, isNot('unknown'));
      expect(preview.totalRecords, greaterThanOrEqualTo(2));
    },
  );

  test(
    'validation rejects missing document data and invalid profile ULIDs',
    () async {
      final service = backupService(FakeFirebaseFirestore());
      final invalid = {
        'version': 1,
        'uid': testUid,
        'account': {'id': testUid, 'data': null},
        'profileSnapshot': <dynamic>[],
        'diagnosticLogs': <dynamic>[],
        'profiles': [
          {
            'id': 'too-short',
            'data': <String, dynamic>{},
            'collections': <String, dynamic>{},
          },
        ],
      };
      expect(
        () => service.validateAndPreview(jsonEncode(invalid)),
        throwsA(isA<ImportValidationException>()),
      );
    },
  );
}
