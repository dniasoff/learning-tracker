import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/parent_session_client.dart';

void main() {
  test(
    'create returns the server-issued lease and sends only profile + PIN',
    () async {
      String? calledName;
      Map<String, Object?>? calledData;
      final client = ParentSessionClient((name, data) async {
        calledName = name;
        calledData = data;
        return <String, Object?>{
          'sessionId': 'a' * 64,
          'expiresAt': DateTime.utc(2026, 11, 5, 17),
        };
      });

      final lease = await client.create(profileId: 'profile', pin: '1234');

      expect(calledName, 'createParentSession');
      expect(calledData, {'profileId': 'profile', 'pin': '1234'});
      expect(lease.sessionId, 'a' * 64);
      expect(lease.expiresAt, DateTime.utc(2026, 11, 5, 17));
    },
  );

  test('revoke is idempotent at the client boundary', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final client = ParentSessionClient((name, data) async {
      calls.add((name, data));
      return <String, Object?>{};
    });

    await client.revoke('a' * 64);

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'revokeParentSession');
    expect(calls.single.$2, <String, Object?>{'parentSessionId': 'a' * 64});
  });
}
