import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  test(
    'export contains canonical track, stage, completion, ledger, and bookmark docs',
    () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      await seedTrack(
        firestore,
        uid: testUid,
        profileId: testProfileId,
        curriculumId: CurriculumId.bavli,
      );
      await seedStageDefinitions(
        firestore,
        uid: testUid,
        profileId: testProfileId,
        curriculumId: CurriculumId.bavli,
      );
      await seedCompletion(
        firestore,
        uid: testUid,
        profileId: testProfileId,
        curriculumId: CurriculumId.bavli,
      );
      await seedLedgerEntry(
        firestore,
        uid: testUid,
        profileId: testProfileId,
        ulid: '01ARZ3NDEKTSV4RRFFQ69G5FBB',
        curriculumId: CurriculumId.bavli,
      );
      await seedBookmark(
        firestore,
        uid: testUid,
        profileId: testProfileId,
        curriculumId: CurriculumId.bavli,
      );

      final profile = profileFrom(
        await exportedMap(backupService(firestore)),
        testProfileId,
      );
      final collections = profile['collections'] as Map<String, dynamic>;
      expect(collections['curriculum_tracks'], hasLength(1));
      expect(collections['stage_definitions'], hasLength(3));
      expect(collections['completions'], hasLength(1));
      expect(collections['learning_ledger'], hasLength(1));
      expect(collections['bookmarks'], hasLength(1));
    },
  );

  test('import writes the same nested document ids and values', () async {
    final source = FakeFirebaseFirestore();
    await seedProfile(source, uid: testUid, profileId: testProfileId);
    await source
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('track_learning_order')
        .doc('order-1')
        .set({'sefaria_ref': 'Berakhot', 'sort_order': 2});
    final payload = await backupService(source).exportData();

    final target = FakeFirebaseFirestore();
    await backupService(target).importData(payload);
    final restored = await target
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('track_learning_order')
        .doc('order-1')
        .get();
    expect(restored.exists, isTrue);
    expect(restored.data()!['sort_order'], 2);
  });

  test('exports curriculum scopes', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, uid: testUid, profileId: testProfileId);
    await firestore
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('curriculum_scopes')
        .doc('scope-1')
        .set({
          'curriculum_id': 'mishnayos',
          'scope_level': 2,
          'scope_value': 'Nashim',
        });
    final profile = profileFrom(
      await exportedMap(backupService(firestore)),
      testProfileId,
    );
    final rows = collectionDocuments(profile, 'curriculum_scopes');
    expect(rows, hasLength(1));
    expect(documentData(rows.single)['scope_value'], 'Nashim');
  });

  test('exports profile program assignments', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, uid: testUid, profileId: testProfileId);
    await firestore
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('profile_programs')
        .doc('mishnayos')
        .set({'program_id': 'daf-yomi', 'curriculum_id': 'mishnayos'});
    final profile = profileFrom(
      await exportedMap(backupService(firestore)),
      testProfileId,
    );
    final rows = collectionDocuments(profile, 'profile_programs');
    expect(rows, hasLength(1));
    expect(documentData(rows.single)['program_id'], 'daf-yomi');
  });

  test('exports study day config rows', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, uid: testUid, profileId: testProfileId);
    await firestore
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('study_day_configs')
        .doc('monday')
        .set({'day_of_week': 1, 'day_type': 'study'});
    final profile = profileFrom(
      await exportedMap(backupService(firestore)),
      testProfileId,
    );
    final rows = collectionDocuments(profile, 'study_day_configs');
    expect(rows, hasLength(1));
    expect(documentData(rows.single)['day_of_week'], 1);
  });

  test('exports streak event rows', () async {
    final firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, uid: testUid, profileId: testProfileId);
    await firestore
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('streak_events')
        .doc('event-1')
        .set({'event_type': 'completion'});
    final profile = profileFrom(
      await exportedMap(backupService(firestore)),
      testProfileId,
    );
    final rows = collectionDocuments(profile, 'streak_events');
    expect(rows, hasLength(1));
    expect(documentData(rows.single)['event_type'], 'completion');
  });

  test('imports curriculum scopes', () async {
    final source = FakeFirebaseFirestore();
    await seedProfile(source, uid: testUid, profileId: testProfileId);
    await source
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('curriculum_scopes')
        .doc('scope-1')
        .set({'scope_value': 'Nashim'});
    final target = FakeFirebaseFirestore();
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final doc = await target
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('curriculum_scopes')
        .doc('scope-1')
        .get();
    expect(doc.exists, isTrue);
  });

  test('imports study day configs', () async {
    final source = FakeFirebaseFirestore();
    await seedProfile(source, uid: testUid, profileId: testProfileId);
    await source
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('study_day_configs')
        .doc('monday')
        .set({'day_of_week': 1});
    final target = FakeFirebaseFirestore();
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final doc = await target
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('study_day_configs')
        .doc('monday')
        .get();
    expect(doc.data()!['day_of_week'], 1);
  });

  test('imports streak events', () async {
    final source = FakeFirebaseFirestore();
    await seedProfile(source, uid: testUid, profileId: testProfileId);
    await source
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('streak_events')
        .doc('event-1')
        .set({'event_type': 'completion'});
    final target = FakeFirebaseFirestore();
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final doc = await target
        .collection('users')
        .doc(testUid)
        .collection('learner_profiles')
        .doc(testProfileId)
        .collection('streak_events')
        .doc('event-1')
        .get();
    expect(doc.data()!['event_type'], 'completion');
  });

  test('imports learning ledger entries', () async {
    final source = FakeFirebaseFirestore();
    await seedProfile(source, uid: testUid, profileId: testProfileId);
    await seedLedgerEntry(
      source,
      uid: testUid,
      profileId: testProfileId,
      ulid: '01ARZ3NDEKTSV4RRFFQ69G5FBB',
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
        .collection('learning_ledger')
        .get();
    expect(docs.docs, hasLength(1));
    expect(docs.docs.single.data()['unit_identifier'], 'unit-1');
  });
}
