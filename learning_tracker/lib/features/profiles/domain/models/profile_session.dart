/// Represents the currently active learner profile session.
///
/// Aggregates the raw profile-id selection into a named domain concept so
/// callers talk about "a session" rather than a nullable integer, and so the
/// type can grow (e.g. include [SessionRole] once W4.29 lands) without
/// changing callsites.
///
/// **Usage:** obtain via `selectedProfileIdProvider` (Riverpod) through the
/// `profileSessionProvider` convenience alias defined in `profile_providers.dart`.
class ProfileSession {
  const ProfileSession({required this.profileId});

  /// Constructs an empty session (no profile selected).
  const ProfileSession.none() : profileId = null;

  /// The selected learner-profile id, or `null` when no profile is active.
  final int? profileId;

  /// Whether a profile has been selected.
  bool get isActive => profileId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileSession &&
          runtimeType == other.runtimeType &&
          profileId == other.profileId;

  @override
  int get hashCode => profileId.hashCode;

  @override
  String toString() => isActive
      ? 'ProfileSession(profileId: $profileId)'
      : 'ProfileSession.none';
}
