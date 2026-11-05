import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists only the opaque server session id, namespaced by account uid.
/// A persisted id is deliberately treated as stale on the next startup and
/// revoked before Firestore network access is restored.
final class ParentSessionPersistence {
  ParentSessionPersistence(this._storage);

  static const _prefix = 'learning_tracker.parent_session.';
  final FlutterSecureStorage _storage;

  String _key(String uid) => '$_prefix$uid';

  Future<String?> read(String uid) => _storage.read(key: _key(uid));

  Future<void> write(String uid, String sessionId) =>
      _storage.write(key: _key(uid), value: sessionId);

  Future<void> clear(String uid) => _storage.delete(key: _key(uid));
}
