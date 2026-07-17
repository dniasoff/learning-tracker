import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_session.freezed.dart';

/// Represents the currently active learner profile session.
///
/// Aggregates the raw profile-id selection into a named domain concept so
/// callers talk about "a session" rather than a nullable integer, and so the
/// type can grow (e.g. include [SessionRole] once W4.29 lands) without
/// changing callsites.
///
/// **Usage:** obtain via `selectedProfileIdProvider` (Riverpod) through the
/// `profileSessionProvider` convenience alias defined in `profile_providers.dart`.
@freezed
abstract class ProfileSession with _$ProfileSession {
  // Private const constructor required for custom getters on freezed
  // classes (matches ProfileModel's pattern in the same directory).
  const ProfileSession._();

  const factory ProfileSession({required int? profileId}) = _ProfileSession;

  /// Constructs an empty session (no profile selected).
  factory ProfileSession.none() => const ProfileSession(profileId: null);

  /// Whether a profile has been selected.
  bool get isActive => profileId != null;
}
