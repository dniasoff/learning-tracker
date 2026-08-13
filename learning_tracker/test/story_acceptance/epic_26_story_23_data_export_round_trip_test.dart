/// Story acceptance tests for Epic 26, Story 23 — same-user Firestore backup.
@Tags(['epic_26', 'story_26_23'])
library;

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';
import 'package:test/test.dart';

import '../helpers/data_export_firestore_test_support.dart';
import '../helpers/firestore_fixtures.dart';

void main() {
  group('Story 26.23 — Firestore backup/restore', () {
    test('export uses an explicit version and injected app version', () async {
      final firestore = FakeFirebaseFirestore();
      final payload = await exportedMap(
        backupService(firestore, appVersion: '3.4.5'),
      );

      expect(payload['version'], 1);
      expect(payload['appVersion'], '3.4.5');
    });

    test(
      'same-user export preserves the account document as raw data',
      () async {
        final firestore = FakeFirebaseFirestore();
        await seedAccount(
          firestore,
          uid: testUid,
          email: 'user@example.com',
          displayName: 'Alice',
        );
        final payload = await exportedMap(backupService(firestore));
        final accountData = (payload['account'] as Map)['data'] as Map;

        expect(accountData['display_name'], 'Alice');
        expect(accountData['email'], 'user@example.com');
      },
    );

    test('profile identity is a valid 26-character Crockford ULID', () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      final payload = await exportedMap(backupService(firestore));
      final profile = (payload['profiles'] as List).single as Map;
      final profileId = profile['id'] as String;

      expect(profileId.length, 26);
      expect(RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(profileId), isTrue);
    });

    test(
      'export includes every user-owned Firestore collection and no transit data',
      () async {
        final firestore = FakeFirebaseFirestore();
        await seedProfile(firestore, uid: testUid, profileId: testProfileId);
        final payload = await exportedMap(backupService(firestore));
        final profile = profileFrom(payload, testProfileId);
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
          expect(collections, contains(collection));
        }
        expect(payload, isNot(contains('syncQueue')));
        expect(payload, isNot(contains('outbox')));
      },
    );

    test('each profile keeps its own nested data after export', () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      await seedProfile(
        firestore,
        uid: testUid,
        profileId: secondTestProfileId,
      );
      for (final entry in {
        testProfileId: 'Alice',
        secondTestProfileId: 'Bob',
      }.entries) {
        await firestore
            .collection('users')
            .doc(testUid)
            .collection('learner_profiles')
            .doc(entry.key)
            .collection('preferences')
            .doc('marker')
            .set({'owner': entry.value});
      }
      final payload = await exportedMap(backupService(firestore));
      expect(
        documentData(
          collectionDocuments(
            profileFrom(payload, testProfileId),
            'preferences',
          ).single,
        )['owner'],
        'Alice',
      );
      expect(
        documentData(
          collectionDocuments(
            profileFrom(payload, secondTestProfileId),
            'preferences',
          ).single,
        )['owner'],
        'Bob',
      );
    });

    test(
      'round-trip preserves two profiles and their curriculum-scoped data',
      () async {
        final source = FakeFirebaseFirestore();
        await seedAccount(source, uid: testUid, displayName: 'Owner');
        await seedProfile(
          source,
          uid: testUid,
          profileId: testProfileId,
          displayName: 'Alice',
        );
        await seedProfile(
          source,
          uid: testUid,
          profileId: secondTestProfileId,
          displayName: 'Bob',
        );
        await seedTrack(
          source,
          uid: testUid,
          profileId: testProfileId,
          curriculumId: CurriculumId.mishnayos,
        );
        await seedTrack(
          source,
          uid: testUid,
          profileId: secondTestProfileId,
          curriculumId: CurriculumId.bavli,
        );
        await seedGoal(
          source,
          uid: testUid,
          profileId: testProfileId,
          curriculumId: CurriculumId.mishnayos,
        );
        await seedCompletion(
          source,
          uid: testUid,
          profileId: secondTestProfileId,
          curriculumId: CurriculumId.bavli,
          sefariaRef: 'Berakhot.2a',
        );
        await seedLedgerEntry(
          source,
          uid: testUid,
          profileId: testProfileId,
          ulid: '01ARZ3NDEKTSV4RRFFQ69G5BB0',
        );
        await seedBookmark(
          source,
          uid: testUid,
          profileId: secondTestProfileId,
          curriculumId: CurriculumId.bavli,
        );
        await seedStageDefinitions(
          source,
          uid: testUid,
          profileId: testProfileId,
          curriculumId: CurriculumId.mishnayos,
        );

        final exported = await backupService(source).exportData();
        final restored = FakeFirebaseFirestore();
        await backupService(restored).importData(exported);
        final restoredExport = await backupService(restored).exportData();

        final before = jsonDecode(exported) as Map<String, dynamic>;
        final after = jsonDecode(restoredExport) as Map<String, dynamic>;
        before.remove('exportedAt');
        after.remove('exportedAt');
        expect(after, before);
      },
    );

    test(
      'import rejects malformed JSON and missing required sections',
      () async {
        final service = backupService(FakeFirebaseFirestore());
        expect(
          () => service.importData('not json'),
          throwsA(isA<ImportValidationException>()),
        );
        expect(
          () => service.importData(
            jsonEncode({
              'version': 1,
              'uid': testUid,
              'account': {'id': testUid, 'data': null},
              'profiles': <dynamic>[],
            }),
          ),
          throwsA(isA<ImportValidationException>()),
        );
      },
    );

    test('C3 purged_at tombstone survives export/import', () async {
      final source = FakeFirebaseFirestore();
      await seedProfile(source, uid: testUid, profileId: testProfileId);
      final purgedAt = DateTime.utc(2026, 3, 1, 12);
      await seedCompletion(
        source,
        uid: testUid,
        profileId: testProfileId,
        sefariaRef: 'Berakhot.3a',
        purgedAt: purgedAt,
      );
      final target = FakeFirebaseFirestore();
      await backupService(
        target,
      ).importData(await backupService(source).exportData());
      final docs = await target
          .collection('users')
          .doc(testUid)
          .collection('learner_profiles')
          .doc(testProfileId)
          .collection('completions')
          .get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.single.data()['purged_at'], isNotNull);
    });
  });
}
