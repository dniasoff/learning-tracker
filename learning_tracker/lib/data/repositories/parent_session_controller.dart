import 'package:learning_tracker/data/repositories/parent_session_client.dart';

enum ParentSessionLockState { unlocked, locking, locked, lockFailed }

/// All account-specific handles needed to finish one parent-session lifecycle.
/// The binding is captured when the lease is minted so account teardown cannot
/// accidentally revoke through whichever account happens to be active later.
final class ParentSessionBinding {
  const ParentSessionBinding({
    required this.client,
    required this.disableNetwork,
    required this.enableNetwork,
    this.persistSessionId,
    this.clearPersistedSessionId,
  });

  final ParentSessionClient client;
  final Future<void> Function() disableNetwork;
  final Future<void> Function() enableNetwork;
  final Future<void> Function(String sessionId)? persistSessionId;
  final Future<void> Function(String sessionId)? clearPersistedSessionId;
}

/// Coordinates the short-lived server session with the local Firestore
/// network. The network is stopped before revocation so queued writes cannot
/// race a lock; it is restored only after the revoke callable completes.
final class ParentSessionController {
  ParentSessionController({
    required ParentSessionClient client,
    required String? Function() currentSessionId,
    required void Function(String sessionId) setSessionId,
    required void Function() clearSessionId,
    void Function(String profileId)? setSessionProfileId,
    void Function()? clearSessionProfileId,
    required Future<void> Function() disableNetwork,
    required Future<void> Function() enableNetwork,
    Future<ParentSessionBinding> Function()? resolveBinding,
    Future<void> Function(String sessionId)? persistSessionId,
    Future<void> Function()? clearPersistedSessionId,
  }) : _client = client,
       _currentSessionId = currentSessionId,
       _setSessionId = setSessionId,
       _clearSessionId = clearSessionId,
       _setSessionProfileId = setSessionProfileId,
       _clearSessionProfileId = clearSessionProfileId,
       _disableNetwork = disableNetwork,
       _enableNetwork = enableNetwork,
       _resolveBinding = resolveBinding,
       _persistSessionId = persistSessionId,
       _clearPersistedSessionId = clearPersistedSessionId;

  final ParentSessionClient _client;
  final String? Function() _currentSessionId;
  final void Function(String sessionId) _setSessionId;
  final void Function() _clearSessionId;
  final void Function(String profileId)? _setSessionProfileId;
  final void Function()? _clearSessionProfileId;
  final Future<void> Function() _disableNetwork;
  final Future<void> Function() _enableNetwork;
  final Future<ParentSessionBinding> Function()? _resolveBinding;
  final Future<void> Function(String sessionId)? _persistSessionId;
  final Future<void> Function()? _clearPersistedSessionId;

  ParentSessionBinding? _sessionBinding;
  Future<void>? _lockFuture;
  String? _pendingSessionId;
  bool _networkDisabled = false;
  bool _sessionRevoked = false;
  bool _persistenceCleared = false;
  ParentSessionLockState _lockState = ParentSessionLockState.unlocked;

  ParentSessionLockState get lockState => _lockState;

  Future<ParentSessionBinding> _binding() async {
    final resolved = await _resolveBinding?.call();
    return resolved ??
        ParentSessionBinding(
          client: _client,
          disableNetwork: _disableNetwork,
          enableNetwork: _enableNetwork,
          persistSessionId: _persistSessionId,
          clearPersistedSessionId: _clearPersistedSessionId == null
              ? null
              : (_) => _clearPersistedSessionId(),
        );
  }

  /// Mints a lease only after the PIN gate has accepted the entered PIN.
  Future<ParentSessionLease> authenticate({
    required String profileId,
    String? pin,
  }) async {
    // A profile change must not mint a second live lease beside the first.
    if (_currentSessionId() != null) await lock();
    await _finishPendingLockBeforeUnlock();
    final binding = await _binding();
    final lease = await binding.client.create(profileId: profileId, pin: pin);
    await binding.persistSessionId?.call(lease.sessionId);
    _sessionBinding = binding;
    _pendingSessionId = null;
    _networkDisabled = false;
    _sessionRevoked = false;
    _persistenceCleared = false;
    _lockState = ParentSessionLockState.unlocked;
    _setSessionId(lease.sessionId);
    _setSessionProfileId?.call(profileId);
    return lease;
  }

  /// Revokes the current lease using the lock ordering required by the
  /// offline policy. Clearing the in-memory id happens immediately so new
  /// writes cannot capture a lease that is being revoked.
  Future<void> lock() {
    final current = _lockFuture;
    if (current != null) return current;
    final operation = _runLock();
    _lockFuture = operation;
    return operation.whenComplete(() {
      if (identical(_lockFuture, operation)) _lockFuture = null;
    });
  }

  Future<void> _runLock() async {
    final sessionId = _pendingSessionId ?? _currentSessionId();
    _pendingSessionId = sessionId;
    _clearSessionId();
    _clearSessionProfileId?.call();
    if (sessionId == null && _sessionBinding == null) {
      _lockState = ParentSessionLockState.locked;
      return;
    }

    _lockState = ParentSessionLockState.locking;
    final binding = _sessionBinding ?? await _binding();
    _sessionBinding = binding;
    try {
      if (!_networkDisabled) {
        await binding.disableNetwork();
        _networkDisabled = true;
      }
      if (!_sessionRevoked && sessionId != null) {
        await binding.client.revoke(sessionId);
        _sessionRevoked = true;
      }
      if (!_persistenceCleared && sessionId != null) {
        await binding.clearPersistedSessionId?.call(sessionId);
        _persistenceCleared = true;
      }
      if (_networkDisabled) {
        await binding.enableNetwork();
        _networkDisabled = false;
      }
      _pendingSessionId = null;
      _sessionBinding = null;
      _lockState = ParentSessionLockState.locked;
    } catch (_) {
      _lockState = ParentSessionLockState.lockFailed;
      rethrow;
    }
  }

  /// Retries a failed revoke/restore operation with bounded exponential backoff.
  Future<void> retryLock({int maxAttempts = 3}) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 100 * (1 << (attempt - 1))),
        );
      }
      try {
        await lock();
        return;
      } catch (_) {
        if (attempt == maxAttempts - 1) rethrow;
      }
    }
  }

  Future<void> _finishPendingLockBeforeUnlock() async {
    final current = _lockFuture;
    if (current != null) {
      try {
        await current;
      } catch (_) {
        // retryLock below performs the bounded recovery attempt.
      }
    }
    if (_lockState == ParentSessionLockState.lockFailed ||
        _pendingSessionId != null ||
        _networkDisabled) {
      await retryLock();
    }
  }
}
