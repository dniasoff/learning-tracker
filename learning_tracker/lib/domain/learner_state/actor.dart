/// AD-52 `actor` map — who made a learning event or governed change.
library;

import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// `actor.role` storage enum: `parent` | `child` | `tutor`.
///
/// Owners' `parent`/`child` is accepted as asserted (spine Roles
/// convention); `tutor` is only ever written by Admin-SDK callables (AD-46).
enum ActorRole {
  /// The parent-PIN session on an owner device.
  parent('parent'),

  /// The child session on an owner device.
  child('child'),

  /// A tutor acting through an active grant (server-written only).
  tutor('tutor');

  const ActorRole(this.storage);

  /// The exact storage string.
  final String storage;

  /// Storage string → value.
  static final Map<String, ActorRole> byStorage = {
    for (final r in values) r.storage: r,
  };
}

/// `{uid, role, display_name}`.
final class Actor {
  /// Creates an actor.
  const Actor({
    required this.uid,
    required this.role,
    required this.displayName,
  });

  /// Strict decode: exactly the three keys, valid role.
  factory Actor.fromStorage(Map<String, Object?> map) {
    final r = StorageReader(_type, map)..requireOnly(storageKeys);
    return Actor(
      uid: r.requiredString(kUid),
      role: r.requiredEnum(kRole, ActorRole.byStorage),
      displayName: r.required<String>(kDisplayName),
    );
  }

  static const _type = 'Actor';

  /// Storage key `uid`.
  static const kUid = 'uid';

  /// Storage key `role`.
  static const kRole = 'role';

  /// Storage key `display_name`.
  static const kDisplayName = 'display_name';

  /// The AD-52 key set — the only keys [toStorage] ever emits.
  static const Set<String> storageKeys = {kUid, kRole, kDisplayName};

  /// Firebase uid of the writer.
  final String uid;

  /// Asserted (owner) or server-derived (tutor) role.
  final ActorRole role;

  /// Display name at write time (may be empty, never null).
  final String displayName;

  /// Encodes exactly [storageKeys].
  Map<String, Object?> toStorage() {
    if (uid.isEmpty) throw const StorageFormatException(_type, kUid, 'empty');
    return {kUid: uid, kRole: role.storage, kDisplayName: displayName};
  }

  @override
  bool operator ==(Object other) =>
      other is Actor &&
      other.uid == uid &&
      other.role == role &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uid, role, displayName);

  @override
  String toString() => 'Actor($uid, ${role.storage})';
}
