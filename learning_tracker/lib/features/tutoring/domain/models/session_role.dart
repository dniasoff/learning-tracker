// SessionRole / ProfileSelection — W4.29
//
// Sealed unions that discriminate the two ways a session can be scoped:
//   1. The authenticated user owns the profile (parent or self-learner).
//   2. The authenticated user is a tutor with an active grant on the profile.
//
// [ProfileSelection] is used at the navigation layer to carry the context
// of which profile is being viewed and in what role.
//
// [SessionRole] is the discriminator used to resolve the effective
// [TutorPermissions] or owner-level permissions (see [ResolvedSession]).

import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';

// ── ProfileSelection ────────────────────────────────────────────────────────

/// Sealed union describing how the current session relates to the selected
/// learner profile.
sealed class ProfileSelection {
  const ProfileSelection({required this.profileId});

  /// The Firestore string form of the learner profile ID.
  final String profileId;
}

/// The authenticated user owns the profile (parent viewing their child's
/// profile, or a single-user account viewing their own).
final class OwnProfileSelection extends ProfileSelection {
  const OwnProfileSelection({required super.profileId, required this.ownerUid});

  /// UID of the authenticated owner.
  final String ownerUid;
}

/// The authenticated user is a tutor with an active grant on the profile.
final class TutoredProfileSelection extends ProfileSelection {
  const TutoredProfileSelection({
    required super.profileId,
    required this.ownerUid,
    required this.grantId,
    required this.permissions,
    this.tutorOwnProfileId = 0,
  });

  /// UID of the profile owner (parent).
  final String ownerUid;

  /// The active tutor grant ID (deterministic doc-id).
  final String grantId;

  /// The permissions granted to this tutor by the parent.
  final TutorPermissions permissions;

  /// C1: the tutor's OWN local learner-profile ID — the namespace under
  /// which the Tutor PIN is stored/verified (`profile_{tutorOwnProfileId}_
  /// tutor_pin_hash`). The Tutor PIN is per-tutor (one PIN across all
  /// talmidim), so the PIN scope keys on this id, NOT on [profileId] (the
  /// talmid's id). The entry gate and the route guard MUST agree on this
  /// single namespace. Falls back to `0` for a profile-less tutor.
  final int tutorOwnProfileId;
}

// ── SessionRole ─────────────────────────────────────────────────────────────

/// Discriminator for the authenticated user's role in the current session.
///
/// Used by [ResolvedSession] to resolve UI affordances.
enum SessionRole {
  /// Parent viewing and managing their own child's profile.
  parentOfOwn,

  /// Learner viewing their own profile in child mode (self-learner or child).
  childSelf,

  /// External tutor with an active grant on the profile.
  tutor,
}

/// Resolved session context — pairs the [SessionRole] with the effective
/// [TutorPermissions] (only non-null when role is [SessionRole.tutor]).
class ResolvedSession {
  const ResolvedSession({
    required this.role,
    required this.profileSelection,
    this.permissions,
  });

  final SessionRole role;
  final ProfileSelection profileSelection;

  /// Non-null only when [role] is [SessionRole.tutor].
  final TutorPermissions? permissions;

  /// True when the session is in tutor mode.
  bool get isTutorSession => role == SessionRole.tutor;

  /// Effective permissions — owner has unrestricted permissions (all true except
  /// live completion which is owner-only and always true for owner roles);
  /// tutors get their grant-scoped permissions.
  TutorPermissions get effectivePermissions =>
      permissions ?? _ownerPermissions();

  static TutorPermissions _ownerPermissions() => const TutorPermissions(
    canViewProgress: true,
    canViewContent: true,
    canBulkPriorCompletion: true,
    canResetCompletion: true,
    canEditGoals: true,
    canEditStages: true,
    canEditRewards: true,
    canEditStudyDays: true,
    canEditPoints: true,
  );

  factory ResolvedSession.forOwner({
    required ProfileSelection selection,
    required bool isChildMode,
  }) => ResolvedSession(
    role: isChildMode ? SessionRole.childSelf : SessionRole.parentOfOwn,
    profileSelection: selection,
  );

  factory ResolvedSession.forTutor({
    required TutoredProfileSelection selection,
  }) => ResolvedSession(
    role: SessionRole.tutor,
    profileSelection: selection,
    permissions: selection.permissions,
  );
}
