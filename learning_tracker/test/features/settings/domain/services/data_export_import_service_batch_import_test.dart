import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  test(
    'import commits more than one Firestore batch without losing records',
    () async {
      final source = FakeFirebaseFirestore();
      await seedProfile(source, uid: testUid, profileId: testProfileId);
      final payload = await exportedMap(backupService(source));
      final profile = profileFrom(payload, testProfileId);
      final collections = profile['collections'] as Map<String, dynamic>;
      collections['preferences'] = [
        for (var i = 0; i < 501; i++)
          {
            'id': 'preference-$i',
            'data': {'ordinal': i, 'enabled': i.isEven},
          },
      ];

      final target = FakeFirebaseFirestore();
      await backupService(target).importData(jsonEncode(payload));
      final restored = await target
          .collection('users')
          .doc(testUid)
          .collection('learner_profiles')
          .doc(testProfileId)
          .collection('preferences')
          .get();
      expect(restored.docs, hasLength(501));
      expect(
        restored.docs
            .singleWhere((doc) => doc.id == 'preference-500')
            .data()['ordinal'],
        500,
      );
    },
  );
}
