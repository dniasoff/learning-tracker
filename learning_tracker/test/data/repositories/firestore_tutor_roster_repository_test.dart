// Story 4.3 (DNI-511) T1: the roster over the incoming-grants callable keeps
// only ACTIVE grants, carries `can_edit_learning` alone as the edit
// permission, and never turns a failed read into an empty roster (AC-1,
// AC-3, AC-6).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../features/sub_tracks/talmidim_fixtures.dart';

void main() {
  FirestoreTutorRosterRepository repo(
    List<TutorGrant> grants, {
    bool ok = true,
  }) => FirestoreTutorRosterRepository(() async => (grants: grants, ok: ok));

  test('keeps only active grants: three active and a pending invite', () async {
    final roster = await repo([
      talmidGrant(1, name: 'Yehuda K.'),
      talmidGrant(2, name: 'Moshe L.', owner: 2),
      talmidGrant(3, state: TutorGrantState.pending, name: 'Pending P.'),
      talmidGrant(4, name: 'Avraham S.'),
    ]).loadActiveTalmidim();

    expect(roster.map((e) => e.grantId), ['grant-4', 'grant-2', 'grant-1']);
    final moshe = roster[1];
    expect(moshe.ownerUid, talmidOwner(2));
    expect(moshe.profileId, talmidProfile(2));
    expect(moshe.displayName, 'Moshe L.');
    expect(moshe.scope?.profilePath, contains(talmidProfile(2)));
  });

  test(
    'a revoked, resigned or expired grant never reaches the roster',
    () async {
      final roster = await repo([
        talmidGrant(1, name: 'A'),
        talmidGrant(2, state: TutorGrantState.revokedByParent, name: 'B'),
        talmidGrant(3, state: TutorGrantState.revokedByTutor, name: 'C'),
        talmidGrant(4, state: TutorGrantState.expired, name: 'D'),
      ]).loadActiveTalmidim();
      expect(roster.map((e) => e.grantId), ['grant-1']);
    },
  );

  test('an authoritative empty result is an empty roster', () async {
    expect(await repo(const []).loadActiveTalmidim(), isEmpty);
  });

  test('a failed call is an error, never an empty roster (AC-6)', () async {
    await expectLater(
      repo(const [], ok: false).loadActiveTalmidim(),
      throwsA(isA<TutorRosterLoadException>()),
    );
    await expectLater(
      FirestoreTutorRosterRepository(
        () async => throw StateError('plugin'),
      ).loadActiveTalmidim(),
      throwsA(isA<TutorRosterLoadException>()),
    );
  });

  test('the edit permission is can_edit_learning only (AD-53)', () async {
    final roster = await repo([
      talmidGrant(1, name: 'A', canEditLearning: false),
      talmidGrant(2, name: 'B'),
    ]).loadActiveTalmidim();
    expect(roster[0].canEditLearning, isFalse);
    expect(roster[1].canEditLearning, isTrue);
  });

  test('an unnamed learner keeps a null name, never the profile id', () async {
    final roster = await repo([
      talmidGrant(1, name: '   '),
    ]).loadActiveTalmidim();
    expect(roster.single.displayName, isNull);
  });

  test('a grant naming a non-ULID profile has no learner scope', () {
    const entry = TalmidRosterEntry(
      grantId: 'g',
      ownerUid: 'owner',
      profileId: 'legacy-id',
      permissions: TutorPermissions(),
    );
    expect(entry.scope, isNull);
  });
}
