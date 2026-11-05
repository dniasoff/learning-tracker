import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/repositories/parent_session_client.dart';
import 'package:learning_tracker/data/repositories/parent_session_controller.dart';
import 'package:learning_tracker/data/repositories/parent_session_persistence.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';

final parentSessionLockStateProvider =
    NotifierProvider<ParentSessionLockStateNotifier, ParentSessionLockState>(
      ParentSessionLockStateNotifier.new,
    );

Map<String, Object?> decodeParentSessionCallableResult(Object? data) {
  final raw = Map<String, Object?>.from(data as Map);
  final expiry = raw['expiresAt'];
  if (expiry is Timestamp) raw['expiresAt'] = expiry.toDate().toUtc();
  return raw;
}

final class ParentSessionLockStateNotifier
    extends Notifier<ParentSessionLockState> {
  @override
  ParentSessionLockState build() => ParentSessionLockState.unlocked;

  void set(ParentSessionLockState value) => state = value;
}

/// The in-memory proof shared by every parent actor factory.
final parentSessionIdProvider =
    NotifierProvider<ParentSessionIdNotifier, String?>(
      ParentSessionIdNotifier.new,
    );

final class ParentSessionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String sessionId) => state = sessionId;

  void clear() => state = null;
}

/// Profile to which the current server lease was issued.
final parentSessionProfileIdProvider =
    NotifierProvider<ParentSessionProfileIdNotifier, String?>(
      ParentSessionProfileIdNotifier.new,
    );

final class ParentSessionProfileIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String profileId) => state = profileId;

  void clear() => state = null;
}

/// Single account/profile-bound factory for owner parent actors.
final parentSessionActorSourceProvider = Provider<ParentSessionActorSource>(
  (ref) => ParentSessionActorSource(
    sessionId: () => ref.read(parentSessionIdProvider),
    profileId: () => ref.read(parentSessionProfileIdProvider),
  ),
);

typedef ParentSessionAccountBindingResolver =
    Future<ParentSessionBinding> Function(ParentSessionPersistence persistence);

typedef ParentSessionPersistedLeaseResolver =
    Future<String?> Function(ParentSessionPersistence persistence);

/// Resolves account-specific Firebase handles in the data layer. Presentation
/// providers consume this boundary instead of importing Firebase directly.
final parentSessionAccountBindingResolverProvider =
    Provider<ParentSessionAccountBindingResolver>((ref) {
      return (persistence) async {
        final handles = await ref.read(activeAccountFirebaseProvider.future);
        if (handles == null) throw StateError('No active account');
        final functions = FirebaseFunctions.instanceFor(app: handles.app);
        final client = ParentSessionClient((name, data) async {
          final result = await functions
              .httpsCallable(name)
              .call<Map<String, dynamic>>(data);
          return decodeParentSessionCallableResult(result.data);
        });
        return ParentSessionBinding(
          client: client,
          disableNetwork: handles.firestore.disableNetwork,
          enableNetwork: handles.firestore.enableNetwork,
          persistSessionId: (sessionId) =>
              persistence.write(handles.uid, sessionId),
          clearPersistedSessionId: (sessionId) =>
              persistence.clear(handles.uid),
        );
      };
    });

final parentSessionPersistedLeaseResolverProvider =
    Provider<ParentSessionPersistedLeaseResolver>((ref) {
      return (persistence) async {
        final handles = await ref.read(activeAccountFirebaseProvider.future);
        if (handles == null) return null;
        return persistence.read(handles.uid);
      };
    });

final parentSessionAccountAvailableProvider = FutureProvider<bool>((ref) async {
  return await ref.read(activeAccountFirebaseProvider.future) != null;
});

final class ParentSessionActorSource {
  const ParentSessionActorSource({
    required this.sessionId,
    required this.profileId,
  });

  final String? Function() sessionId;
  final String? Function() profileId;

  Actor actor({
    required String uid,
    String displayName = '',
    String? targetProfileId,
    bool allowMissing = false,
  }) {
    final id = sessionId();
    if (id == null && !allowMissing) {
      throw StateError('A parent session is required before creating an actor');
    }
    final boundProfile = profileId();
    if (targetProfileId != null &&
        boundProfile != null &&
        targetProfileId != boundProfile) {
      throw StateError('Parent session is bound to a different profile');
    }
    return Actor(
      uid: uid,
      role: ActorRole.parent,
      displayName: displayName,
      sessionId: id,
    );
  }
}
