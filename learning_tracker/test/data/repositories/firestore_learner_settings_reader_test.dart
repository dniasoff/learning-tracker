/// DNI-470 AC-7: the Firestore settings reader projects the profile doc's
/// settings and fails closed on a missing doc or zone.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_settings_reader.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

void main() {
  const path = 'users/owner-uid/learner_profiles/$profileUlid';

  test('projects only the settings keys of the profile doc', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc(path).set({
      'display_name': 'Avi',
      'time_zone': 'Asia/Jerusalem',
      'latitude': 31,
      'longitude': 35.2,
      'in_israel': true,
      'last_change_id': ulidA,
    });
    final reader = FirestoreLearnerSettingsReader(firestore: firestore);
    expect(
      await reader.watch(c0Scope()).first,
      const LearnerSettings(
        profileId: profileUlid,
        timeZone: 'Asia/Jerusalem',
        latitude: 31,
        longitude: 35.2,
        inIsrael: true,
        lastChangeId: ulidA,
      ),
    );
  });

  test('a missing profile doc or time zone is an error, never a '
      'fallback', () async {
    final firestore = FakeFirebaseFirestore();
    final reader = FirestoreLearnerSettingsReader(firestore: firestore);
    await expectLater(
      reader.watch(c0Scope()).first,
      throwsA(isA<LearnerProfileMissingException>()),
    );
    await firestore.doc(path).set({'display_name': 'Avi'});
    await expectLater(
      reader.watch(c0Scope()).first,
      throwsA(isA<StorageFormatException>()),
    );
  });
}
