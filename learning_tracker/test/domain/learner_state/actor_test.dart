/// Unit tests for [Actor].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('round-trips exactly uid / role / display_name', () {
    expect(parentActor.toStorage(), parentActorMap);
    expect(Actor.fromStorage(parentActorMap), parentActor);
  });

  test('role storage enum is exactly parent | child | tutor', () {
    expect(ActorRole.byStorage.keys.toSet(), {'parent', 'child', 'tutor'});
  });

  test('rejects an unknown role, missing key, empty uid, null name', () {
    for (final bad in <Map<String, Object?>>[
      {...parentActorMap, 'role': 'admin'},
      {'uid': 'u', 'role': 'child'},
      {...parentActorMap, 'uid': ''},
      {...parentActorMap, 'display_name': null},
    ]) {
      expect(
        () => Actor.fromStorage(bad),
        throwsA(isA<StorageFormatException>()),
        reason: '$bad',
      );
    }
    expect(
      const Actor(uid: '', role: ActorRole.child, displayName: '').toStorage,
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('value equality', () {
    expect(
      const Actor(uid: 'a', role: ActorRole.tutor, displayName: 'R'),
      const Actor(uid: 'a', role: ActorRole.tutor, displayName: 'R'),
    );
    expect(
      parentActor,
      isNot(
        const Actor(
          uid: 'owner-uid',
          role: ActorRole.child,
          displayName: 'Abba',
        ),
      ),
    );
  });
}
