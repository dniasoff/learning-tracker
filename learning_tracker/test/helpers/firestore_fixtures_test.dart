import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import 'firestore_fake.dart';
import 'firestore_fixtures.dart';

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

  test('seeds track, completion, and learning-ledger documents', () async {
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
      activatedAt: _time,
    );
    final completionId = await seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
      sefariaRef: 'Daf 2a',
      stageId: 2,
      completedAt: _time,
      points: 7,
    );
    const ledgerUlid = 'FIXTURELEDGER000000000001';
    await seedLedgerEntry(
      firestore,
      uid: _uid,
      profileId: _profileId,
      ulid: ledgerUlid,
      curriculumId: CurriculumId.bavli,
      unitIdentifier: 'daf-2a',
      completedAt: _time,
      markedBy: _profileId,
      completionNumber: 2,
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
      'state_changed_at': _time.toIso8601String(),
      'activated_at': _time.toIso8601String(),
    });

    final completion = await profilePath
        .collection('completions')
        .doc(completionId)
        .get();
    expect(completion.data(), containsPair('curriculum_id', 'bavli'));
    expect(completion.data(), containsPair('sefaria_ref', 'Daf 2a'));
    expect(completion.data()!['completed_at'], isA<Timestamp>());

    final ledger = await profilePath
        .collection('learning_ledger')
        .doc(ledgerUlid)
        .get();
    expect(ledger.data(), containsPair('ulid', ledgerUlid));
    expect(ledger.data(), containsPair('curriculum_id', 'bavli'));
    expect(ledger.data(), containsPair('completion_number', 2));
    expect(ledger.data()!['completed_at'], isA<Timestamp>());
  });

  test('seeds goal and bookmark documents', () async {
    final goalId = await seedGoal(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      targetPercent: 80,
      description: 'Finish the tractate',
      createdAt: _time,
      updatedAt: _time,
    );
    await seedBookmark(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      sefariaRef: 'Mishnah 3',
      updatedAt: _time,
    );

    final profilePath = firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId);
    final goal = await profilePath.collection('goals').doc(goalId).get();
    expect(goal.data(), containsPair('curriculum_id', 'mishnayos'));
    expect(goal.data(), containsPair('target_percent', 80));
    expect(goal.data(), containsPair('description', 'Finish the tractate'));

    final bookmark = await profilePath
        .collection('bookmarks')
        .doc(CurriculumId.mishnayos.storageKey)
        .get();
    expect(bookmark.data(), {
      'curriculum_id': 'mishnayos',
      'sefaria_ref': 'Mishnah 3',
      'updated_at': _time.toIso8601String(),
    });
  });

  test('seeds the three default stage definitions as one batch', () async {
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      updatedAt: _time,
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
    expect(byOrder[1]!['updated_at'], _time.toIso8601String());
    expect(byOrder[1], isNot(contains('track_id')));
  });
}
