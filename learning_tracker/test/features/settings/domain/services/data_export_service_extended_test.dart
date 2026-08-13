import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  test(
    'export includes version, same-user identity, and app metadata',
    () async {
      final firestore = FakeFirebaseFirestore();
      await seedAccount(firestore, uid: testUid, email: 'owner@example.com');
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);

      final payload = await exportedMap(
        backupService(firestore, appVersion: '3.4.5'),
      );

      expect(payload['version'], 1);
      expect(payload['uid'], testUid);
      expect(payload['appVersion'], '3.4.5');
      expect(payload['exportedAt'], isA<String>());
      expect(
        (payload['account'] as Map<String, dynamic>)['data'],
        isA<Map<String, dynamic>>(),
      );
      // This is a same-user backup, so the raw account document is preserved.
      expect(
        ((payload['account'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>)['email'],
        'owner@example.com',
      );
    },
  );

  test(
    'export includes every owner-scoped collection, even when empty',
    () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      final profile = profileFrom(
        await exportedMap(backupService(firestore)),
        testProfileId,
      );
      final collections = profile['collections'] as Map<String, dynamic>;

      const expected = [
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
      for (final collection in expected) {
        expect(collections.containsKey(collection), isTrue);
        expect(collections[collection], isEmpty);
      }
    },
  );
}
