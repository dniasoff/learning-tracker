/// Typed client boundary for the parent-session callables.
library;

typedef ParentSessionCallable =
    Future<Map<String, Object?>> Function(
      String name,
      Map<String, Object?> data,
    );

final class ParentSessionLease {
  const ParentSessionLease({required this.sessionId, required this.expiresAt});

  final String sessionId;
  final DateTime expiresAt;
}

final class ParentSessionClient {
  ParentSessionClient(this._call);

  final ParentSessionCallable _call;

  Future<ParentSessionLease> create({
    required String profileId,
    required String pin,
  }) async {
    final result = await _call('createParentSession', {
      'profileId': profileId,
      'pin': pin,
    });
    final sessionId = result['sessionId'];
    final expiresAt = result['expiresAt'];
    if (sessionId is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sessionId)) {
      throw const FormatException(
        'createParentSession returned an invalid session id',
      );
    }
    if (expiresAt is! DateTime) {
      throw const FormatException(
        'createParentSession returned an invalid expiry',
      );
    }
    return ParentSessionLease(
      sessionId: sessionId,
      expiresAt: expiresAt.toUtc(),
    );
  }

  Future<void> setPin({required String profileId, required String pin}) async {
    await _call('setParentPin', {'profileId': profileId, 'pin': pin});
  }

  Future<void> revoke(String sessionId) async {
    await _call('revokeParentSession', {'parentSessionId': sessionId});
  }
}
