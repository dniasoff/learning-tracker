import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/parent_session_state.dart';

String? _missing() => null;

void main() {
  test('parent actor source can explicitly bootstrap without a lease', () {
    const source = ParentSessionActorSource(
      sessionId: _missing,
      profileId: _missing,
    );

    final actor = source.actor(
      uid: 'uid',
      targetProfileId: 'profile',
      allowMissing: true,
    );

    expect(actor.sessionId, isNull);
  });

  test('parent actor source rejects a missing lease by default', () {
    const source = ParentSessionActorSource(
      sessionId: _missing,
      profileId: _missing,
    );

    expect(() => source.actor(uid: 'uid'), throwsA(isA<StateError>()));
  });
}
