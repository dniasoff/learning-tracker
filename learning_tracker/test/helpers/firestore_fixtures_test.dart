import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import 'firestore_fake.dart';
import 'firestore_fixtures.dart';
import 'retired_inventory.dart';

const _uid = 'fixture-uid';
const _profileId = 'fixture-profile-ulid';
final _time = DateTime.utc(2026, 2, 3, 4, 5, 6);

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  test('seeds account and learner profile documents', () async {
    await seedAccount(
      firestore,
      uid: _uid,
      email: 'fixture@example.com',
      displayName: 'Fixture Account',
      createdAt: _time,
      updatedAt: _time,
    );
    await seedProfile(
      firestore,
      uid: _uid,
      profileId: _profileId,
      displayName: 'Fixture Learner',
      mode: ProfileMode.child,
      avatar: 'avatar-1',
      createdAt: _time,
      updatedAt: _time,
    );

    final account = await firestore.collection('users').doc(_uid).get();
    expect(account.data(), {
      'email': 'fixture@example.com',
      'display_name': 'Fixture Account',
      'created_at': _time.toIso8601String(),
      'updated_at': _time.toIso8601String(),
    });

    final profile = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .get();
    expect(profile.data(), {
      'display_name': 'Fixture Learner',
      'mode': 'child',
      'avatar': 'avatar-1',
      'created_at': _time.toIso8601String(),
      'updated_at': _time.toIso8601String(),
    });
  });

  test('seeds track documents', () async {
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
      activatedAt: _time,
    );
    final profilePath = firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId);
    final track = await profilePath
        .collection('curriculum_tracks')
        .doc(CurriculumId.bavli.storageKey)
        .get();
    expect(track.data(), {
      'curriculum_id': 'bavli',
      'state': 'active',
      'activated_at': _time.toIso8601String(),
    });
  });

  test('seeds goal documents', () async {
    final goalId = await seedGoal(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      description: 'Finish the tractate',
      createdAt: _time,
    );

    final profilePath = firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId);
    final goal = await profilePath.collection('goals').doc(goalId).get();
    expect(goal.data(), containsPair('curriculum_id', 'mishnayos'));
    for (final key in retiredKeysOf(
      'lib/data/repositories/firestore_goal_repository.dart',
    )) {
      expect(goal.data(), isNot(contains(key)), reason: key);
    }
    expect(goal.data(), containsPair('description', 'Finish the tractate'));
  });

  test('seeds the three default stage definitions as one batch', () async {
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );

    final stages = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .collection('stage_definitions')
        .get();
    expect(stages.docs, hasLength(3));
    final byOrder = {
      for (final doc in stages.docs)
        doc.data()['stage_order'] as int: doc.data(),
    };
    expect(byOrder.keys.toList()..sort(), [1, 2, 3]);
    // Must match FirestoreStageDefinitionRepository's real _defaultStages
    // exactly — a scheduler/due-date test relying on these built-in
    // defaults is only meaningful if delayDays matches production.
    expect(byOrder[1], containsPair('delay_days', 0));
    expect(byOrder[2], containsPair('delay_days', 1));
    expect(byOrder[3], containsPair('delay_days', 7));
    expect(byOrder[2], containsPair('stage_name', 'חזרה א׳'));
    expect(byOrder[3], containsPair('stage_name', 'חזרה ב׳'));
    expect(byOrder[1], containsPair('curriculum_id', 'mishnayos'));
    expect(byOrder[1], isNot(contains('updated_at')));
    expect(byOrder[1], isNot(contains('track_id')));
  });
}
