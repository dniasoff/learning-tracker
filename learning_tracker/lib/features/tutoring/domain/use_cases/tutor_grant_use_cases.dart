// Tutor grant active-lifecycle use cases — W4.32
//
// Four use cases covering active-grant operations:
//   RevokeTutorGrantUseCase       — parent revokes an active grant
//   ResignTutorGrantUseCase       — tutor resigns from an active grant
//   ListIncomingTutorAccessUseCase — tutor lists their own incoming grants
//   ListOutgoingTutorGrantsUseCase — parent lists grants they have issued

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';

/// Parent revokes an active tutor grant immediately.
///
/// Revocation is immediate — the tutor loses access on the next read cycle.
/// This uses Cloud Functions (Admin SDK) to set state = revoked_by_parent
/// and stamp revoked_at.
class RevokeTutorGrantUseCase {
  const RevokeTutorGrantUseCase(this._repository, {AnalyticsService? analytics})
    : _analytics = analytics;
  final TutorGrantRepository _repository;
  final AnalyticsService? _analytics;

  Future<TutorGrantResult> call({required TutorGrant grant}) async {
    if (!grant.canRevoke) {
      return TutorGrantPreconditionError(
        message:
            'Grant ${grant.grantId} cannot be revoked '
            '(current state: ${grant.grantState.rawState.toJson()}). '
            'Only active grants can be revoked by the parent.',
      );
    }
    final result = await _repository.revokeGrant(grantId: grant.grantId);
    // W7.11: fire tutor_grant_revoked on success.
    if (result is TutorGrantSuccess) {
      await _analytics?.logEvent(
        AnalyticsEvent.tutorGrantRevoked,
        parameters: {'grant_id': grant.grantId},
      );
    }
    return result;
  }
}

/// Tutor resigns from an active grant (self-initiated revocation).
class ResignTutorGrantUseCase {
  const ResignTutorGrantUseCase(this._repository, {AnalyticsService? analytics})
    : _analytics = analytics;
  final TutorGrantRepository _repository;
  final AnalyticsService? _analytics;

  Future<TutorGrantResult> call({required TutorGrant grant}) async {
    if (!grant.canResign) {
      return TutorGrantPreconditionError(
        message:
            'Grant ${grant.grantId} cannot be resigned '
            '(current state: ${grant.grantState.rawState.toJson()}). '
            'Only active grants can be resigned by the tutor.',
      );
    }
    final result = await _repository.resignGrant(grantId: grant.grantId);
    // W7.11: fire tutor_resigned on success.
    if (result is TutorGrantSuccess) {
      await _analytics?.logEvent(
        AnalyticsEvent.tutorResigned,
        parameters: {'grant_id': grant.grantId},
      );
    }
    return result;
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

  /// D18: variant that reports CF success vs offline failure so the caller can
  /// reconcile locally-mirrored talmidim (wipe revoked ones on a real success,
  /// retain them on an offline failure).
  Future<({List<TutorGrant> grants, bool ok})> callWithStatus() =>
      _repository.listIncomingGrantsWithStatus();
}

/// List all grants issued by the authenticated parent for a child profile.
class ListOutgoingTutorGrantsUseCase {
  const ListOutgoingTutorGrantsUseCase(this._repository);
  final TutorGrantRepository _repository;

  Future<List<TutorGrant>> call({required String childProfileId}) =>
      _repository.listOutgoingGrants(childProfileId: childProfileId);
}
