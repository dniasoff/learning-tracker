import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  test('import restores every owner-scoped profile collection', () async {
    final source = FakeFirebaseFirestore();
    await seedAccount(source, uid: testUid);
    await seedProfile(source, uid: testUid, profileId: testProfileId);
    final profileRef = source
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId);
    const collections = [
      'completions',
      'streak_events',
      'learning_ledger',
      'points_ledger',
      'reward_redemptions',
      'settings',
      'stage_definitions',
      'point_configs',
      'curriculum_tracks',
      'bookmarks',
      'learning_order',
      'track_learning_order',
      'preferences',
      'goals',
      'import_metadata',
      'profile_programs',
      'curriculum_scopes',
      'study_day_configs',
    ];
    for (final collection in collections) {
      await profileRef.collection(collection).doc('document-1').set({
        'collection': collection,
        'value': 1,
      });
    }

    final payload = await backupService(source).exportData();
    final target = FakeFirebaseFirestore();
    final service = backupService(target);
    final preview = service.validateAndPreview(payload);
    expect(preview.totalRecords, greaterThanOrEqualTo(collections.length + 2));
    await service.importData(payload);

    for (final collection in collections) {
      final restored = await profileRefFor(
        target,
      ).collection(collection).doc('document-1').get();
      expect(restored.exists, isTrue, reason: collection);
      expect(restored.data()!['collection'], collection);
    }
  });

  test('import is idempotent for an identical backup', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, uid: testUid, profileId: testProfileId);
    final service = backupService(firestore);
    final payload = await service.exportData();

    await service.importData(payload);
    await service.importData(payload);
    final after = await exportedMap(service);
    expect(after['profiles'], hasLength(1));
  });
}

DocumentReference<Map<String, dynamic>> profileRefFor(
  FakeFirebaseFirestore firestore,
) => firestore
    .collection('users')
    .doc(testUid)
    .collection('learner_profiles')
    .doc(testProfileId);
