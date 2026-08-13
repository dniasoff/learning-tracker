/// Story acceptance tests for Story 25.22 — Firestore cutover onboarding.
@Tags(['epic_25', 'story_25_22'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:test/test.dart';

import '../helpers/firestore_fixtures.dart';

const _uid = 'uid_firewall_001';
const _profileId = '01J00000000000000000000004';

void main() {
  group('Story 25.22 — AC2: Onboarding flow integration', () {
    test(
      'account, profile, and curriculum track round-trip in Firestore',
      () async {
        final firestore = FakeFirebaseFirestore();
        await seedAccount(firestore, uid: _uid, email: 'new-user@example.com');
        await seedProfile(
          firestore,
          uid: _uid,
          profileId: _profileId,
          displayName: 'My Profile',
        );
        await seedTrack(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos,
        );

        final account = await FirestoreAccountRepository(
          firestore: firestore,
          uid: _uid,
        ).getAccount();
        final profile = await FirestoreLearnerProfileRepository(
          firestore: firestore,
          uid: _uid,
        ).getProfile(_profileId);
        final track = await FirestoreCurriculumTrackRepository(
          firestore: firestore,
          uid: _uid,
          profileId: _profileId,
        ).getTrack(CurriculumId.mishnayos);

        expect(account?.uid, _uid);
        expect(profile?.profileId, _profileId);
        expect(profile?.displayName, 'My Profile');
        expect(track?.curriculumId, CurriculumId.mishnayos);
        expect(track?.state, 'active');
      },
    );
  });
}
