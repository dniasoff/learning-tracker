// Tutor invite lifecycle use cases — W4.31
//
// Four use cases covering the pending-invite half of the grant lifecycle:
//   InviteTutorUseCase        — parent sends invite
//   AcceptTutorInviteUseCase  — tutor accepts
//   DeclineTutorInviteUseCase — tutor declines
//   RescindTutorInviteUseCase — parent rescinds before acceptance
//
// All mutations go through Cloud Functions (Admin SDK). These use cases:
//   1. Validate preconditions against the local [TutorGrant] aggregate.
//   2. Dispatch a request to the tutor grant repository.
//   3. Return a sealed result.
//
// The repository interface is defined in this file to avoid a separate file
// per tiny interface. The concrete implementation (data layer) calls Firebase
// Cloud Functions.

import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';

// ── Repository interface ────────────────────────────────────────────────────

/// Repository for tutor grant lifecycle operations.
///
/// All writes delegate to Cloud Functions (Admin SDK). The repository
/// implementation handles the HTTP/callable layer.
abstract interface class TutorGrantRepository {
  /// Send a tutor invite to [tutorEmail] for [childProfileId].
  Future<TutorGrantResult> inviteTutor({
    required String tutorEmail,
    required String childProfileId,
    required TutorPermissions permissions,
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

  /// List all grants issued by the caller (as parent) for [childProfileId].
  Future<List<TutorGrant>> listOutgoingGrants({required String childProfileId});
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

final class TutorGrantPreconditionError extends TutorGrantResult {
  const TutorGrantPreconditionError({required this.message});
  final String message;
}

// ── Use cases ───────────────────────────────────────────────────────────────

/// Parent sends a tutor invite for a child profile.
class InviteTutorUseCase {
  const InviteTutorUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<TutorGrantResult> call({
    required String tutorEmail,
    required String childProfileId,
    TutorPermissions? permissions,
  }) async {
    final email = tutorEmail.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      return const TutorGrantPreconditionError(
        message: 'A valid tutor email address is required.',
      );
    }
    return _repository.inviteTutor(
      tutorEmail: email,
      childProfileId: childProfileId,
      permissions: permissions ?? TutorPermissions.defaults(),
    );
  }
}

/// Tutor accepts an incoming invite.
class AcceptTutorInviteUseCase {
  const AcceptTutorInviteUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<TutorGrantResult> call({
    required TutorGrant grant,
  }) async {
    if (!grant.canAccept) {
      return TutorGrantPreconditionError(
        message: 'Grant ${grant.grantId} is not in a state that can be accepted '
            '(current state: ${grant.grantState.rawState.toJson()}).',
      );
    }
    return _repository.acceptInvite(grantId: grant.grantId);
  }
}

/// Tutor declines an incoming invite.
class DeclineTutorInviteUseCase {
  const DeclineTutorInviteUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<TutorGrantResult> call({
    required TutorGrant grant,
  }) async {
    if (!grant.canDecline) {
      return TutorGrantPreconditionError(
        message: 'Grant ${grant.grantId} is not in a state that can be declined '
            '(current state: ${grant.grantState.rawState.toJson()}).',
      );
    }
    return _repository.declineInvite(grantId: grant.grantId);
  }
}

/// Parent rescinds an invite before the tutor has accepted.
class RescindTutorInviteUseCase {
  const RescindTutorInviteUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<TutorGrantResult> call({
    required TutorGrant grant,
  }) async {
    if (!grant.canRescind) {
      return TutorGrantPreconditionError(
        message: 'Grant ${grant.grantId} cannot be rescinded '
            '(current state: ${grant.grantState.rawState.toJson()}). '
            'Only pending grants can be rescinded. '
            'Use revokeGrant for active grants.',
      );
    }
    return _repository.rescindInvite(grantId: grant.grantId);
  }
}
