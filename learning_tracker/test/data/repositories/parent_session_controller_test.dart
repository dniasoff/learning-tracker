import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/parent_session_client.dart';
import 'package:learning_tracker/data/repositories/parent_session_controller.dart';

void main() {
  test('lock disables network, revokes, then enables network', () async {
    final activeSessionId = 'a' * 64;
    final events = <String>[];
    var sessionId = activeSessionId;
    final controller = ParentSessionController(
      client: ParentSessionClient((name, data) async {
        events.add('$name:${data['parentSessionId']}');
        return <String, Object?>{};
      }),
      currentSessionId: () => sessionId,
      setSessionId: (value) => sessionId = value,
      clearSessionId: () {
        events.add('clear');
        sessionId = '';
      },
      disableNetwork: () async => events.add('disable'),
      enableNetwork: () async => events.add('enable'),
    );

    await controller.lock();

    expect(events, [
      'clear',
      'disable',
      'revokeParentSession:$activeSessionId',
      'enable',
    ]);
  });

  test('authenticate stores only a server-issued session id', () async {
    String? stored;
    final controller = ParentSessionController(
      client: ParentSessionClient((name, data) async {
        expect(name, 'createParentSession');
        expect(data, {'profileId': 'profile', 'pin': '1234'});
        return <String, Object?>{
          'sessionId': 'b' * 64,
          'expiresAt': DateTime.utc(2026, 11, 5, 17),
        };
      }),
      currentSessionId: () => stored,
      setSessionId: (value) => stored = value,
      clearSessionId: () => stored = null,
      disableNetwork: () async {},
      enableNetwork: () async {},
    );

    final lease = await controller.authenticate(
      profileId: 'profile',
      pin: '1234',
    );

    expect(lease.sessionId, 'b' * 64);
    expect(stored, 'b' * 64);
  });
}
