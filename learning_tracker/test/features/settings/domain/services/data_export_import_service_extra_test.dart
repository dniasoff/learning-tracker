import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  test(
    'export preserves raw document ids and fields in extra collections',
    () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      final profileRef = firestore
          .collection('users')
          .doc(testUid)
          .collection('learner_profiles')
          .doc(testProfileId);
      await profileRef.collection('settings').doc('mishnayos').set({
        'custom_key': 'kept',
        'enabled': true,
      });
      await profileRef.collection('profile_programs').doc('mishnayos').set({
        'program_id': 'daf-yomi',
        'tracking_start_ref': 'Berakhot.2a',
      });
      await profileRef.collection('study_day_configs').doc('monday').set({
        'day_of_week': 1,
        'day_type': 'study',
      });

      final profile = profileFrom(
        await exportedMap(backupService(firestore)),
        testProfileId,
      );
      final collections = profile['collections'] as Map<String, dynamic>;
      final settings = (collections['settings'] as List)
          .cast<Map<String, dynamic>>()
          .single;
      expect(settings['id'], 'mishnayos');
      expect((settings['data'] as Map)['custom_key'], 'kept');
      expect(collections['profile_programs'] as List, hasLength(1));
      expect(collections['study_day_configs'] as List, hasLength(1));
    },
  );

  test('exported JSON validates and previews all nested records', () async {
    final firestore = FakeFirebaseFirestore();
    await seedAccount(firestore, uid: testUid);
    await seedProfile(firestore, uid: testUid, profileId: testProfileId);
    await firestore
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('goals')
        .doc('goal-1')
        .set({'target_percent': 50});

    final service = backupService(firestore);
    final preview = service.validateAndPreview(await service.exportData());
    expect(preview.userProfileCount, 1);
    expect(preview.goalCount, 1);
    expect(preview.totalRecords, greaterThanOrEqualTo(3));
    expect(jsonDecode(await service.exportData()), isA<Map<String, dynamic>>());
  });
}
