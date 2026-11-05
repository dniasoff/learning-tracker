import 'package:learning_tracker/data/repositories/parent_session_client.dart';

/// Coordinates the short-lived server session with the local Firestore
/// network. The network is stopped before revocation so queued writes cannot
/// race a lock; it is restored only after the revoke callable completes.
final class ParentSessionController {
  ParentSessionController({
    required ParentSessionClient client,
    required String? Function() currentSessionId,
    required void Function(String sessionId) setSessionId,
    required void Function() clearSessionId,
    required Future<void> Function() disableNetwork,
    required Future<void> Function() enableNetwork,
    Future<void> Function(String sessionId)? persistSessionId,
    Future<void> Function()? clearPersistedSessionId,
  }) : _client = client,
       _currentSessionId = currentSessionId,
       _setSessionId = setSessionId,
       _clearSessionId = clearSessionId,
       _disableNetwork = disableNetwork,
       _enableNetwork = enableNetwork,
       _persistSessionId = persistSessionId,
       _clearPersistedSessionId = clearPersistedSessionId;

  final ParentSessionClient _client;
  final String? Function() _currentSessionId;
  final void Function(String sessionId) _setSessionId;
  final void Function() _clearSessionId;
  final Future<void> Function() _disableNetwork;
  final Future<void> Function() _enableNetwork;
  final Future<void> Function(String sessionId)? _persistSessionId;
  final Future<void> Function()? _clearPersistedSessionId;

  /// Mints a lease only after the PIN gate has accepted the entered PIN.
  Future<ParentSessionLease> authenticate({
    required String profileId,
    required String pin,
  }) async {
    final lease = await _client.create(profileId: profileId, pin: pin);
    await _persistSessionId?.call(lease.sessionId);
    _setSessionId(lease.sessionId);
    return lease;
  }

  /// Revokes the current lease using the lock ordering required by the
  /// offline policy. Clearing the in-memory id happens immediately so new
  /// writes cannot capture a lease that is being revoked.
  Future<void> lock() async {
    final sessionId = _currentSessionId();
    _clearSessionId();
    await _disableNetwork();
    if (sessionId != null) await _client.revoke(sessionId);
    if (sessionId != null) await _clearPersistedSessionId?.call();
    await _enableNetwork();
  }
}
