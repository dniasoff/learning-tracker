// Tutor grant active-lifecycle use cases — W4.32
//
// Four use cases covering active-grant operations:
//   RevokeTutorGrantUseCase       — parent revokes an active grant
//   ResignTutorGrantUseCase       — tutor resigns from an active grant
//   ListIncomingTutorAccessUseCase — tutor lists their own incoming grants
//   ListOutgoingTutorGrantsUseCase — parent lists grants they have issued

import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';

/// Parent revokes an active tutor grant immediately.
///
/// Revocation is immediate — the tutor loses access on the next read cycle.
/// This uses Cloud Functions (Admin SDK) to set state = revoked_by_parent
/// and stamp revoked_at.
class RevokeTutorGrantUseCase {
  const RevokeTutorGrantUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<TutorGrantResult> call({required TutorGrant grant}) async {
    if (!grant.canRevoke) {
      return TutorGrantPreconditionError(
        message:
            'Grant ${grant.grantId} cannot be revoked '
            '(current state: ${grant.grantState.rawState.toJson()}). '
            'Only active grants can be revoked by the parent.',
      );
    }
    return _repository.revokeGrant(grantId: grant.grantId);
  }
}

/// Tutor resigns from an active grant (self-initiated revocation).
class ResignTutorGrantUseCase {
  const ResignTutorGrantUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<TutorGrantResult> call({required TutorGrant grant}) async {
    if (!grant.canResign) {
      return TutorGrantPreconditionError(
        message:
            'Grant ${grant.grantId} cannot be resigned '
            '(current state: ${grant.grantState.rawState.toJson()}). '
            'Only active grants can be resigned by the tutor.',
      );
    }
    return _repository.resignGrant(grantId: grant.grantId);
  }
}

/// List all incoming tutor grants for the authenticated tutor.
///
/// Returns all grants where tutor_uid == caller, regardless of state.
/// The caller can filter by [TutorGrantState] to show only pending or active.
class ListIncomingTutorAccessUseCase {
  const ListIncomingTutorAccessUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<List<TutorGrant>> call() => _repository.listIncomingGrants();
}

/// List all grants issued by the authenticated parent for a child profile.
class ListOutgoingTutorGrantsUseCase {
  const ListOutgoingTutorGrantsUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<List<TutorGrant>> call({required String childProfileId}) =>
      _repository.listOutgoingGrants(childProfileId: childProfileId);
}
