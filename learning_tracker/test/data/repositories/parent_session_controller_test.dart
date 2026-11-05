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

  test('concurrent locks share one in-flight revoke', () async {
    String? sessionId = 'c' * 64;
    var revokes = 0;
    final controller = ParentSessionController(
      client: ParentSessionClient((name, data) async {
        if (name == 'revokeParentSession') {
          revokes++;
          await Future<void>.delayed(Duration.zero);
        }
        return <String, Object?>{};
      }),
      currentSessionId: () => sessionId,
      setSessionId: (value) => sessionId = value,
      clearSessionId: () => sessionId = null,
      disableNetwork: () async {},
      enableNetwork: () async {},
    );

    await Future.wait([controller.lock(), controller.lock()]);

    expect(revokes, 1);
    expect(controller.lockState, ParentSessionLockState.locked);
  });

  test('failed revoke leaves a retryable lock state', () async {
    String? sessionId = 'd' * 64;
    var shouldFail = true;
    var revokes = 0;
    final controller = ParentSessionController(
      client: ParentSessionClient((name, data) async {
        if (name == 'revokeParentSession') {
          revokes++;
          if (shouldFail) throw StateError('offline');
        }
        return <String, Object?>{};
      }),
      currentSessionId: () => sessionId,
      setSessionId: (value) => sessionId = value,
      clearSessionId: () => sessionId = null,
      disableNetwork: () async {},
      enableNetwork: () async {},
    );

    await expectLater(controller.lock(), throwsStateError);
    expect(controller.lockState, ParentSessionLockState.lockFailed);
    shouldFail = false;
    await controller.retryLock();

    expect(revokes, 2);
    expect(controller.lockState, ParentSessionLockState.locked);
  });

  test('enable failure retries enable without revoking twice', () async {
    String? sessionId = 'e' * 64;
    var enableAttempts = 0;
    var revokes = 0;
    final controller = ParentSessionController(
      client: ParentSessionClient((name, data) async {
        if (name == 'revokeParentSession') revokes++;
        return <String, Object?>{};
      }),
      currentSessionId: () => sessionId,
      setSessionId: (value) => sessionId = value,
      clearSessionId: () => sessionId = null,
      disableNetwork: () async {},
      enableNetwork: () async {
        enableAttempts++;
        if (enableAttempts == 1) throw StateError('enable failed');
      },
    );

    await expectLater(controller.lock(), throwsStateError);
    await controller.retryLock();

    expect(revokes, 1);
    expect(enableAttempts, 2);
    expect(controller.lockState, ParentSessionLockState.locked);
  });

  test('lock uses the account binding captured at authenticate time', () async {
    final leaseId = 'f' * 64;
    String? sessionId;
    var resolverCalls = 0;
    final oldAccountEvents = <String>[];
    final newAccountEvents = <String>[];
    ParentSessionBinding binding(List<String> events) => ParentSessionBinding(
      client: ParentSessionClient((name, data) async {
        events.add(name);
        return <String, Object?>{
          'sessionId': leaseId,
          'expiresAt': DateTime.utc(2026, 11, 5),
        };
      }),
      disableNetwork: () async => events.add('disable'),
      enableNetwork: () async => events.add('enable'),
    );

    final controller = ParentSessionController(
      client: binding(oldAccountEvents).client,
      resolveBinding: () async => ++resolverCalls == 1
          ? binding(oldAccountEvents)
          : binding(newAccountEvents),
      currentSessionId: () => sessionId,
      setSessionId: (value) => sessionId = value,
      clearSessionId: () => sessionId = null,
      disableNetwork: () async {},
      enableNetwork: () async {},
    );

    await controller.authenticate(profileId: 'profile', pin: '1234');
    await controller.lock();

    expect(oldAccountEvents, contains('revokeParentSession'));
    expect(newAccountEvents, isEmpty);
  });
}
