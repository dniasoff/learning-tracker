// Mirror test for
// `lib/features/sacred_time/data/repositories/legacy_learner_settings_seeder.dart`
// (stuck Sacred-Time lock hotfix, 1.0.74).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/data/repositories/creating_device_settings_source.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/legacy_learner_settings_seeder.dart';

import '../../../../helpers/creating_device_settings_fakes.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _uid = 'owner-uid';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.doc('users/$_uid/learner_profiles/$profileUlid').set({
      'display_name': 'Daniel',
      'mode': 'adult',
      'avatar': '',
      'created_at': '2026-08-25T09:11:23.505175Z',
      'updated_at': '2026-08-25T09:11:23.505176Z',
    });
  });

  LegacyLearnerSettingsSeeder seeder({String? deviceZone = 'Europe/London'}) {
    final c = ProviderContainer.test(
      overrides: [
        firestoreLearnerProfileRepositoryProvider.overrideWith(
          (ref) async => FirestoreLearnerProfileRepository(
            firestore: firestore,
            uid: _uid,
            authUid: 'auth-uid',
          ),
        ),
        creatingDeviceSettingsOverride(
          FakeCreatingDeviceSettingsSource(
            CreatingDeviceSettings(timeZone: deviceZone, inIsrael: false),
          ),
        ),
      ],
    );
    return c.read(legacyLearnerSettingsSeederProvider);
  }

  Future<Map<String, Object?>> profileDoc() async => fromFirestoreMap(
    (await firestore.doc('users/$_uid/learner_profiles/$profileUlid').get())
        .data()!,
  );

  test('seeds a legacy profile of the signed-in account with the device '
      'zone, diaspora and no location, so its settings decode', () async {
    final scope = LearnerScope(ownerUid: _uid, profileId: profileUlid);
    expect(await seeder().seedIfLegacy(scope), isTrue);
    final settings = LearnerSettings.fromProfileDoc(
      profileUlid,
      await profileDoc(),
    );
    expect(settings.timeZone, 'Europe/London');
    expect(settings.inIsrael, isFalse);
    expect(settings.hasLocation, isFalse);
    expect(settings.lastChangeId, isNotNull);
    // Idempotent: a seeded profile is never seeded again.
    expect(await seeder().seedIfLegacy(scope), isFalse);
  });

  test(
    'another account\'s learner (a tutored talmid) is never seeded',
    () async {
      final scope = LearnerScope(
        ownerUid: 'parent-uid',
        profileId: profileUlid,
      );
      expect(await seeder().seedIfLegacy(scope), isFalse);
      expect(await profileDoc(), isNot(contains('time_zone')));
    },
  );

  test('a device zone that cannot be read seeds nothing', () async {
    final scope = LearnerScope(ownerUid: _uid, profileId: profileUlid);
    expect(await seeder(deviceZone: null).seedIfLegacy(scope), isFalse);
    expect(await profileDoc(), isNot(contains('time_zone')));
  });
}
