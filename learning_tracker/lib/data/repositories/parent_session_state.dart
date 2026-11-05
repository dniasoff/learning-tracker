import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/repositories/parent_session_controller.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';

final parentSessionLockStateProvider =
    NotifierProvider<ParentSessionLockStateNotifier, ParentSessionLockState>(
      ParentSessionLockStateNotifier.new,
    );

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
