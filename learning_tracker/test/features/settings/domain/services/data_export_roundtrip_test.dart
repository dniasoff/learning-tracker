import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

Future<FakeFirebaseFirestore> profileStore() async {
  final firestore = FakeFirebaseFirestore();
  await seedProfile(firestore, uid: testUid, profileId: testProfileId);
  return firestore;
}

CollectionReference<Map<String, dynamic>> profileCollection(
  FakeFirebaseFirestore firestore,
  String collection,
) => firestore
    .collection('users')
    .doc(testUid)
    .collection('learner_profiles')
    .doc(testProfileId)
    .collection(collection);

Future<Map<String, dynamic>> roundTripPayload(
  Map<String, dynamic> payload,
) async {
  final restored = FakeFirebaseFirestore();
  await backupService(restored).importData(jsonEncode(payload));
  final result = await exportedMap(backupService(restored));
  payload.remove('exportedAt');
  result.remove('exportedAt');
  return result;
}

void main() {
  test('exports curriculum track with all fields serialized', () async {
    final firestore = await profileStore();
    await seedTrack(
      firestore,
      uid: testUid,
      profileId: testProfileId,
      curriculumId: CurriculumId.mishnayos,
      state: 'retired',
    );
    final profile = profileFrom(
      await exportedMap(backupService(firestore)),
      testProfileId,
    );
    final track = collectionDocuments(profile, 'curriculum_tracks');
    expect(track, hasLength(1));
    expect(documentData(track.single)['state'], 'retired');
    expect(documentData(track.single)['activated_at'], isNotNull);
  });

  test('exports goal with all fields serialized', () async {
    final firestore = await profileStore();
    await seedGoal(
      firestore,
      uid: testUid,
      profileId: testProfileId,
      curriculumId: CurriculumId.mishnayos,
      description: 'Finish the tract',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final profile = profileFrom(
      await exportedMap(backupService(firestore)),
      testProfileId,
    );
    final goals = collectionDocuments(profile, 'goals');
    expect(goals, hasLength(1));
    expect(documentData(goals.single), isNot(contains('target_percent')));
    expect(documentData(goals.single)['description'], 'Finish the tract');
  });

  test('exports main-track order rows (track_learning_order; the retired '
      'learning_order collection is merged into it, DNI-476)', () async {
    final firestore = await profileStore();
    await profileCollection(
      firestore,
      'track_learning_order',
    ).doc('mishnayos_seder_Zeraim').set({
      'curriculum_id': 'mishnayos',
      'level': 'seder',
      'ref': 'Zeraim',
      'user_sort_order': 0,
    });
    final profile = profileFrom(
      await exportedMap(backupService(firestore)),
      testProfileId,
    );
    final rows = collectionDocuments(profile, 'track_learning_order');
    expect(rows, hasLength(1));
    expect(documentData(rows.single)['ref'], 'Zeraim');
  });

  test('exports streak_events rows', () async {
    final firestore = await profileStore();
    await profileCollection(
      firestore,
      'streak_events',
    ).doc('event-1').set({'event_type': 'completion', 'day_utc': '2026-01-01'});
    final profile = profileFrom(
      await exportedMap(backupService(firestore)),
      testProfileId,
    );
    final rows = collectionDocuments(profile, 'streak_events');
    expect(rows, hasLength(1));
    expect(documentData(rows.single)['event_type'], 'completion');
  });

  test(
    'importData on an empty backup leaves a fresh Firestore instance empty',
    () async {
      final source = FakeFirebaseFirestore();
      final payload = await backupService(source).exportData();
      final target = FakeFirebaseFirestore();
      await backupService(target).importData(payload);
      expect((await target.collection('users').get()).docs, isEmpty);
    },
  );

  test('importData imports curriculum tracks', () async {
    final source = await profileStore();
    await seedTrack(
      source,
      uid: testUid,
      profileId: testProfileId,
      curriculumId: CurriculumId.mishnayos,
    );
    final target = FakeFirebaseFirestore();
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final restored = await profileCollection(target, 'curriculum_tracks').get();
    expect(restored.docs, hasLength(1));
    expect(restored.docs.single.data()['state'], 'active');
  });

  test('importData imports goals', () async {
    final source = await profileStore();
    await seedGoal(
      source,
      uid: testUid,
      profileId: testProfileId,
      curriculumId: CurriculumId.mishnayos,
    );
    final target = FakeFirebaseFirestore();
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final restored = await profileCollection(target, 'goals').get();
    expect(restored.docs, hasLength(1));
    expect(restored.docs.single.data()['curriculum_id'], 'mishnayos');
  });

  test('importData imports the main-track order', () async {
    final source = await profileStore();
    await profileCollection(source, 'track_learning_order')
        .doc('mishnayos_seder_Zeraim')
        .set({'ref': 'Zeraim', 'user_sort_order': 0});
    final target = FakeFirebaseFirestore();
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final restored = await profileCollection(
      target,
      'track_learning_order',
    ).get();
    expect(restored.docs, hasLength(1));
    expect(restored.docs.single.data()['ref'], 'Zeraim');
  });

  test('importData imports streak_events', () async {
    final source = await profileStore();
    await profileCollection(
      source,
      'streak_events',
    ).doc('event-1').set({'event_type': 'completion'});
    final target = FakeFirebaseFirestore();
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final restored = await profileCollection(target, 'streak_events').get();
    expect(restored.docs, hasLength(1));
    expect(restored.docs.single.data()['event_type'], 'completion');
  });

  test(
    'importData rejects malformed JSON with ImportValidationException',
    () async {
      expect(
        () => backupService(FakeFirebaseFirestore()).importData('not json'),
        throwsA(isA<ImportValidationException>()),
      );
    },
  );

  test('round-trip: exportData → importData preserves track count', () async {
    final source = await profileStore();
    await seedTrack(
      source,
      uid: testUid,
      profileId: testProfileId,
      curriculumId: CurriculumId.mishnayos,
    );
    final payload = await exportedMap(backupService(source));
    final restored = await roundTripPayload(payload);
    final profile = profileFrom(restored, testProfileId);
    expect(collectionDocuments(profile, 'curriculum_tracks'), hasLength(1));
  });

  test(
    'idempotent re-import does not duplicate or corrupt documents',
    () async {
      final source = await profileStore();
      await seedTrack(
        source,
        uid: testUid,
        profileId: testProfileId,
        curriculumId: CurriculumId.mishnayos,
      );
      final payload = await backupService(source).exportData();
      final target = FakeFirebaseFirestore();
      final service = backupService(target);
      await service.importData(payload);
      await service.importData(payload);
      expect(
        (await profileCollection(target, 'curriculum_tracks').get()).docs,
        hasLength(1),
      );
    },
  );

  test(
    'round-trip preserves Timestamp, GeoPoint, bytes, and nested maps',
    () async {
      final source = await profileStore();
      final timestamp = Timestamp.fromDate(DateTime.utc(2026, 4, 5, 6, 7));
      await profileCollection(source, 'preferences').doc('unusual').set({
        'timestamp': timestamp,
        'location': const GeoPoint(31.7683, 35.2137),
        'bytes': Blob(Uint8List.fromList([1, 2, 3, 255])),
        'nested': {
          'list': [
            1,
            true,
            {'label': 'kept'},
          ],
        },
      });
      final payload = await exportedMap(backupService(source));
      final restored = await roundTripPayload(payload);
      final profile = profileFrom(restored, testProfileId);
      final preferences = collectionDocuments(profile, 'preferences');
      final data = documentData(preferences.single);
      expect(data['timestamp'], containsPair('__firestore_type', 'timestamp'));
      expect(data['location'], containsPair('__firestore_type', 'geopoint'));
      expect(data['bytes'], containsPair('__firestore_type', 'bytes'));
      expect(
        data['nested'] as Map<String, dynamic>,
        containsPair('list', isA<List<Object?>>()),
      );
    },
  );
}
