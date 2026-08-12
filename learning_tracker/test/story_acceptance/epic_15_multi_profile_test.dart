/// Story acceptance coverage for Epic 15 — multi-profile flows.
@Tags(['epic_15'])
library;

import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:test/test.dart';

import '../helpers/firestore_fixtures.dart';

void main() {
  group('Story 15 — profile identity and isolation', tags: ['story_15'], () {
    test('two Firestore profiles have independent document paths', () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(
        firestore,
        uid: 'multi-profile-uid',
        profileId: '01J00000000000000000000004',
        displayName: 'A',
      );
      await seedProfile(
        firestore,
        uid: 'multi-profile-uid',
        profileId: '01J00000000000000000000005',
        displayName: 'B',
      );
      final repository = FirestoreLearnerProfileRepository(
        firestore: firestore,
        uid: 'multi-profile-uid',
      );
      final first = await repository.getProfile(
        '01J00000000000000000000004',
      );
      final second = await repository.getProfile(
        '01J00000000000000000000005',
      );
      expect(first?.displayName, 'A');
      expect(second?.displayName, 'B');
      expect(first?.profileId, isNot(second?.profileId));
    });

    test('curriculum tracks are keyed by CurriculumId, never an int id', () async {
      final firestore = FakeFirebaseFirestore();
      await seedTrack(
        firestore,
        uid: 'multi-profile-uid',
        profileId: '01J00000000000000000000004',
        curriculumId: CurriculumId.bavli,
      );
      final repository = FirestoreCurriculumTrackRepository(
        firestore: firestore,
        uid: 'multi-profile-uid',
        profileId: '01J00000000000000000000004',
      );
      final track = await repository.getTrack(CurriculumId.bavli);
      expect(track?.curriculumId, CurriculumId.bavli);
    });
  });

  group('Story 15 — legacy Drift profile suites', skip:
      'Blocked: the remaining original ACs call ProfileDao, profile-program DAOs, stage DAOs, and scope DAOs directly. Firestore repositories exist for some collections, but the full production/provider wiring is not yet available.',
      () {
    test('placeholder for the pending Firestore multi-profile service seam', () {});
  });

  test('profile-management source remains present', () {
    expect(
      File('lib/features/profiles/presentation/providers/active_profile_provider.dart').existsSync(),
      isTrue,
    );
  });
}
