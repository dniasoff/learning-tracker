// TutorGrantRepository — domain repository interface (moved by
// AUD-tutoring-10 from domain/use_cases/tutor_invite_use_cases.dart).
//
// Relocated per the placement guide in docs/coding-standards.md ("New
// repository interface -> domain/repositories/<name>_repository.dart").
// [TutorGrantResult] (and its variants) travels with the interface here
// rather than staying in tutor_invite_use_cases.dart, since every method on
// the interface returns it — keeping the two apart would have forced this
// file to import back into domain/use_cases/ for the result type, creating a
// circular import between the two domain files.

import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';

// ── Repository interface ────────────────────────────────────────────────────

/// Repository for tutor grant lifecycle operations.
///
/// All writes delegate to Cloud Functions (Admin SDK). The repository
/// implementation handles the HTTP/callable layer.
abstract interface class TutorGrantRepository {
  /// Send a tutor invite to [tutorEmail] for [childProfileId].
  ///
  /// [childName]/[parentName] are snapshotted onto the grant so the tutor sees
  /// human-readable names rather than a raw profile id / generic label.
  Future<TutorGrantResult> inviteTutor({
    required String tutorEmail,
    required String childProfileId,
    required TutorPermissions permissions,
    String? childName,
    String? parentName,
  });

  /// Accept the invite for [grantId].
  Future<TutorGrantResult> acceptInvite({required String grantId});

  /// Decline the invite for [grantId].
  Future<TutorGrantResult> declineInvite({required String grantId});

  /// Rescind the invite for [grantId] (parent cancels before acceptance).
  Future<TutorGrantResult> rescindInvite({required String grantId});

  /// Revoke an active grant (parent revokes).
  Future<TutorGrantResult> revokeGrant({required String grantId});

  /// Resign from an active grant (tutor resigns).
  Future<TutorGrantResult> resignGrant({required String grantId});

  /// List active/pending grants where caller is the tutor.
  Future<List<TutorGrant>> listIncomingGrants();

  /// Like [listIncomingGrants] but reports whether the underlying Cloud
  /// Function call genuinely SUCCEEDED (online, authoritative) versus failed
  /// (offline / transient / permission-denied — `grants` empty, `ok` false).
  ///
  /// D18: callers need this distinction to safely reconcile locally-mirrored
  /// talmidim. On a confirmed success an empty/absent grant is authoritative
  /// (the grant was revoked) and the mirror must be wiped; on a failure the
  /// mirror must be retained so a cached talmid is not hidden offline.
  Future<({List<TutorGrant> grants, bool ok})> listIncomingGrantsWithStatus();

  /// List all grants issued by the caller (as parent) for [childProfileId].
  Future<List<TutorGrant>> listOutgoingGrants({required String childProfileId});

  /// List PENDING invites addressed to the caller's email (tutor_uid is still
  /// null until acceptance). Lets a freshly signed-in tutor discover and
  /// accept invitations in-app without the emailed deep link.
  Future<List<TutorGrant>> listPendingInvitesForMe();
}

// ── Result type ─────────────────────────────────────────────────────────────

sealed class TutorGrantResult {
  const TutorGrantResult();
}

final class TutorGrantSuccess extends TutorGrantResult {
  const TutorGrantSuccess({this.grantId});
  final String? grantId;
}

final class TutorGrantFailure extends TutorGrantResult {
  const TutorGrantFailure({required this.message, this.code});
  final String message;
  final String? code;
}

/// AUD-tutoring-02 (EH-5): stable failure category for
/// [TutorGrantPreconditionError]. A local precondition guard must never carry
/// a pre-formatted human-readable message baked with the grant id/state — an
/// English sentence renders raw and un-RTL-shaped to Hebrew-locale users.
/// Presentation resolves the user-facing string for each code through
/// `AppLocalizations`/ARB.
enum TutorGrantPreconditionCode {
  /// [InviteTutorUseCase]: the supplied tutor email is not validly shaped.
  invalidTutorEmail,

  /// [AcceptTutorInviteUseCase]: the grant is not in a state that can be
  /// accepted (e.g. expired, already accepted/declined/revoked).
  cannotAccept,

  /// [DeclineTutorInviteUseCase]: the grant is not in a state that can be
  /// declined.
  cannotDecline,

  /// [RescindTutorInviteUseCase]: the grant is not pending, so the parent
  /// cannot rescind it.
  cannotRescind,

  /// [RevokeTutorGrantUseCase]: the grant is not active, so the parent
  /// cannot revoke it.
  cannotRevoke,

  /// [ResignTutorGrantUseCase]: the grant is not active, so the tutor
  /// cannot resign from it.
  cannotResign,
}

final class TutorGrantPreconditionError extends TutorGrantResult {
  const TutorGrantPreconditionError({required this.code});
  final TutorGrantPreconditionCode code;
}
