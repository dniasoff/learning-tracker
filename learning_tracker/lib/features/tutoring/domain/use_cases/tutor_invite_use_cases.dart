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
// AUD-tutoring-10: the [TutorGrantRepository] interface and [TutorGrantResult]
// result type moved to domain/repositories/tutor_grant_repository.dart
// (placement guide). Re-exported here so existing importers of this file
// keep resolving both without churn.

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/repositories/tutor_grant_repository.dart';

export 'package:learning_tracker/features/tutoring/domain/repositories/tutor_grant_repository.dart';

// ── Use cases ───────────────────────────────────────────────────────────────

/// Parent sends a tutor invite for a child profile.
class InviteTutorUseCase {
  const InviteTutorUseCase(this._repository, {AnalyticsService? analytics})
    : _analytics = analytics;
  final TutorGrantRepository _repository;
  final AnalyticsService? _analytics;

  Future<TutorGrantResult> call({
    required String tutorEmail,
    required String childProfileId,
    TutorPermissions? permissions,
    String? childName,
    String? parentName,
  }) async {
    final email = tutorEmail.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      return const TutorGrantPreconditionError(
        code: TutorGrantPreconditionCode.invalidTutorEmail,
      );
    }
    final result = await _repository.inviteTutor(
      tutorEmail: email,
      childProfileId: childProfileId,
      permissions: permissions ?? TutorPermissions.defaults(),
      childName: childName,
      parentName: parentName,
    );
    // W7.11: fire tutor_invite_sent on success.
    // AUD-core-analytics-01 (PV-1): no childProfileId — a per-child
    // identifier has no place in an uncatalogued analytics event; this
    // event may only signal THAT an invite was sent, never for WHICH child
    // (mirrors AnalyticsService.logPinLockedOut / logParentModeEntered).
    if (result is TutorGrantSuccess) {
      await _analytics?.logEvent(AnalyticsEvent.tutorInviteSent);
    }
    return result;
  }
}

/// Tutor accepts an incoming invite.
class AcceptTutorInviteUseCase {
  const AcceptTutorInviteUseCase(
    this._repository, {
    AnalyticsService? analytics,
  }) : _analytics = analytics;
  final TutorGrantRepository _repository;
  final AnalyticsService? _analytics;

  Future<TutorGrantResult> call({required TutorGrant grant}) async {
    if (!grant.canAccept) {
      return const TutorGrantPreconditionError(
        code: TutorGrantPreconditionCode.cannotAccept,
      );
    }
    final result = await _repository.acceptInvite(grantId: grant.grantId);
    // W7.11: fire tutor_invite_accepted on success.
    if (result is TutorGrantSuccess) {
      await _analytics?.logEvent(
        AnalyticsEvent.tutorInviteAccepted,
        parameters: {'grant_id': grant.grantId},
      );
    }
    return result;
  }
}

/// Tutor declines an incoming invite.
class DeclineTutorInviteUseCase {
  const DeclineTutorInviteUseCase(
    this._repository, {
    AnalyticsService? analytics,
  }) : _analytics = analytics;
  final TutorGrantRepository _repository;
  final AnalyticsService? _analytics;

  Future<TutorGrantResult> call({required TutorGrant grant}) async {
    if (!grant.canDecline) {
      return const TutorGrantPreconditionError(
        code: TutorGrantPreconditionCode.cannotDecline,
      );
    }
    final result = await _repository.declineInvite(grantId: grant.grantId);
    // W7.11: fire tutor_invite_declined on success.
    if (result is TutorGrantSuccess) {
      await _analytics?.logEvent(
        AnalyticsEvent.tutorInviteDeclined,
        parameters: {'grant_id': grant.grantId},
      );
    }
    return result;
  }
}

/// Parent rescinds an invite before the tutor has accepted.
class RescindTutorInviteUseCase {
  const RescindTutorInviteUseCase(
    this._repository, {
    AnalyticsService? analytics,
  }) : _analytics = analytics;
  final TutorGrantRepository _repository;
  final AnalyticsService? _analytics;

  Future<TutorGrantResult> call({required TutorGrant grant}) async {
    if (!grant.canRescind) {
      return const TutorGrantPreconditionError(
        code: TutorGrantPreconditionCode.cannotRescind,
      );
    }
    final result = await _repository.rescindInvite(grantId: grant.grantId);
    // W7.11: fire tutor_grant_rescinded on success.
    if (result is TutorGrantSuccess) {
      await _analytics?.logEvent(
        AnalyticsEvent.tutorGrantRescinded,
        parameters: {'grant_id': grant.grantId},
      );
    }
    return result;
  }
}
