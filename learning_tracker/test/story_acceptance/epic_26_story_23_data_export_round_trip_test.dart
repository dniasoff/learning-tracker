/// Story acceptance tests for Epic 26, Story 23 — same-user Firestore backup.
@Tags(['epic_26', 'story_26_23'])
library;

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';
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

      expect(payload['version'], DataExportImportService.formatVersion);
      expect(payload['version'], 2);
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
        // The AD-49 learning record plus the current raw profile collections.
        const expected = [
          'learning_events',
          'sub_tracks',
          'change_log',
          'points_ledger',
          'reward_redemptions',
          'settings',
          'stage_definitions',
          'point_configs',
          'curriculum_tracks',
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

        // Governed docs restore as logged updates (AD-49): each gains a
        // `last_change_id` and a change-log entry, so the record is
        // compared by identity rather than byte for byte.
        final before = jsonDecode(exported) as Map<String, dynamic>;
        final after = jsonDecode(restoredExport) as Map<String, dynamic>;
        expect(after['account'], before['account']);
        for (final profileId in [testProfileId, secondTestProfileId]) {
          final was = profileFrom(before, profileId);
          final now = profileFrom(after, profileId);
          expect(
            (now['data'] as Map)['display_name'],
            (was['data'] as Map)['display_name'],
          );
          for (final name in [
            'curriculum_tracks',
            'goals',
            'stage_definitions',
          ]) {
            expect(
              collectionDocuments(now, name).map((d) => d['id']),
              collectionDocuments(was, name).map((d) => d['id']),
              reason: '$profileId $name',
            );
          }
        }
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
  });
}
