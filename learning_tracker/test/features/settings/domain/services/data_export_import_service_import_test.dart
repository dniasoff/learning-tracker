import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  test('import restores the raw profile collections under their ids, the '
      'governed ones as logged updates, and the non-event records as new '
      'records (DNI-482, AD-49)', () async {
    final source = FakeFirebaseFirestore();
    await seedAccount(source, uid: testUid);
    await seedProfile(source, uid: testUid, profileId: testProfileId);
    final profileRef = profileRefFor(source);
    const raw = [
      'settings',
      'point_configs',
      'bookmarks',
      'preferences',
      'import_metadata',
    ];
    for (final collection in raw) {
      await profileRef.collection(collection).doc('document-1').set({
        'collection': collection,
        'value': 1,
      });
    }
    const governed = [
      'stage_definitions',
      'curriculum_tracks',
      'track_learning_order',
      'goals',
      'profile_programs',
      'curriculum_scopes',
      'study_day_configs',
    ];
    for (final collection in governed) {
      await profileRef.collection(collection).doc('mishnayos').set({
        'curriculum_id': 'mishnayos',
        'collection': collection,
      });
    }
    await profileRef.collection('points_ledger').doc('adjustment-1').set({
      'entry_kind': 'parent_add',
      'delta': 4,
    });
    await profileRef.collection('reward_redemptions').doc('redemption-1').set({
      'status': 'pending_fulfilment',
    });

    final payload = await backupService(source).exportData();
    final target = FakeFirebaseFirestore();
    final service = backupService(target);
    final preview = service.validateAndPreview(payload);
    expect(preview.totalRecords, greaterThanOrEqualTo(raw.length + 9));
    final report = await service.importData(payload);
    expect(report.saved, isTrue);

    final restoredProfile = profileRefFor(target);
    for (final collection in raw) {
      final restored = await restoredProfile
          .collection(collection)
          .doc('document-1')
          .get();
      expect(restored.exists, isTrue, reason: collection);
      expect(restored.data()!['collection'], collection);
    }
    final log = await restoredProfile.collection('change_log').get();
    for (final collection in governed) {
      final restored = await restoredProfile
          .collection(collection)
          .doc('mishnayos')
          .get();
      expect(restored.data()!['collection'], collection);
      final entryId = restored.data()!['last_change_id'] as String;
      final entry = log.docs.singleWhere((d) => d.id == entryId).data();
      expect(
        (entry['before'] as Map).values,
        everyElement(isNull),
        reason: '$collection: a logged update against an absent doc',
      );
    }
    final points = await restoredProfile.collection('points_ledger').get();
    expect(points.docs.single.id, isNot('adjustment-1'));
    expect(points.docs.single.data()['delta'], 4);
    final redemptions = await restoredProfile
        .collection('reward_redemptions')
        .get();
    expect(redemptions.docs.single.id, isNot('redemption-1'));
  });

  test(
    'a re-import of an identical backup re-writes no governed field',
    () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      await profileRefFor(firestore)
          .collection('curriculum_tracks')
          .doc('mishnayos')
          .set({'curriculum_id': 'mishnayos', 'state': 'active'});
      final service = backupService(firestore);
      final payload = await service.exportData();

      await service.importData(payload);
      final logAfterFirst = await profileRefFor(
        firestore,
      ).collection('change_log').get();
      await service.importData(payload);
      final logAfterSecond = await profileRefFor(
        firestore,
      ).collection('change_log').get();
      expect(logAfterSecond.docs, hasLength(logAfterFirst.docs.length));
      final after = await exportedMap(service);
      expect(after['profiles'], hasLength(1));
    },
  );
}

DocumentReference<Map<String, dynamic>> profileRefFor(
  FakeFirebaseFirestore firestore,
) => firestore
    .collection('users')
    .doc(testUid)
    .collection('learner_profiles')
    .doc(testProfileId);
