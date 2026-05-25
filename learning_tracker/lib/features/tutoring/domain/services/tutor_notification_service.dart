// TutorNotificationGateway — W6.25
//
// Domain service that sends transactional email notifications for tutor grant
// lifecycle events. Three scenarios are covered:
//
//   1. Tutor declines an invite  → notify the parent.
//   2. Tutor resigns a grant     → notify the parent.
//   3. Parent revokes a grant    → notify the tutor.
//
// This service wraps [TransactionalEmailService] (W6.8) with typed,
// intent-named methods so callers don't have to assemble email payload
// objects directly.
//
// Call sites (use cases or Riverpod notifiers) pass the relevant email
// address(es). The parent email MUST be obtained by the caller from
// Firebase Auth (the parent is the authenticated user, so
// `FirebaseAuth.instance.currentUser?.email` is always available at
// the point of call). The tutor email is carried on the [TutorGrantDoc].
//
// W6.25 delivery note:
//   Emails currently go through [LoggingTransactionalEmailService]
//   (the fallback) and are NOT sent until a real email provider is
//   provisioned. See the INFRASTRUCTURE WAKE-UP NOTICE in
//   core/email/transactional_email_service.dart.

import 'package:learning_tracker/core/email/transactional_email_service.dart';

/// Domain service for lifecycle-event notifications in the tutor grant flow.
///
/// All methods are fire-and-forget: they call
/// [TransactionalEmailService.send] and return immediately. The email
/// service contract guarantees it MUST NOT throw, so errors are absorbed
/// and logged internally.
class TutorNotificationGateway {
  const TutorNotificationGateway(this._email);

  final TransactionalEmailService _email;

  // ── W6.25 notification entry points ────────────────────────────────────────

  /// M1: build a deliverable recipient address.
  ///
  /// The tutor-side flows (decline / resign) only have the parent's UID on the
  /// grant doc — the parent's email is not readable cross-uid client-side. When
  /// no email is available we route by UID (`uid:{parentUid}`) so the
  /// notification still identifies a real recipient and the server-side mail
  /// pipeline (or the logging fallback) can resolve the address from the UID,
  /// rather than dropping the notification on an empty string.
  static String _recipient({required String email, required String uid}) {
    if (email.trim().isNotEmpty) return email.trim();
    if (uid.trim().isNotEmpty) return 'uid:${uid.trim()}';
    return '';
  }

  /// Notify the parent that a tutor declined their invite.
  ///
  /// Call this after [DeclineTutorInviteUseCase] succeeds.
  ///
  /// [parentEmail] — the parent's email address (empty when unavailable).
  /// [parentUid]   — the parent's UID (from [TutorGrantDoc.parentUid]); used to
  ///                 route the notification by UID when [parentEmail] is empty.
  /// [tutorEmail]  — the tutor who declined (from [TutorGrantDoc.tutorEmail]).
  /// [childName]   — display name of the child profile (for the email body).
  Future<void> notifyParentOfDecline({
    required String parentEmail,
    required String tutorEmail,
    required String childName,
    String parentUid = '',
  }) => _email.send(
    TutorDeclinedEmail(
      toAddress: _recipient(email: parentEmail, uid: parentUid),
      tutorEmail: tutorEmail,
      childName: childName,
    ),
  );

  /// Notify the parent that their tutor resigned from an active grant.
  ///
  /// Call this after [ResignTutorGrantUseCase] succeeds.
  ///
  /// [parentEmail] — the parent's email address (empty when unavailable).
  /// [parentUid]   — the parent's UID (from [TutorGrantDoc.parentUid]); used to
  ///                 route the notification by UID when [parentEmail] is empty.
  /// [tutorName]   — display name of the tutor (from Firebase Auth
  ///                 [User.displayName], falls back to [tutorEmail] if null).
  /// [childName]   — display name of the child profile.
  Future<void> notifyParentOfResignation({
    required String parentEmail,
    required String tutorName,
    required String childName,
    String parentUid = '',
  }) => _email.send(
    TutorResignedEmail(
      toAddress: _recipient(email: parentEmail, uid: parentUid),
      tutorName: tutorName,
      childName: childName,
    ),
  );

  /// Notify the tutor that the parent revoked their grant.
  ///
  /// Call this after [RevokeTutorGrantUseCase] succeeds.
  ///
  /// [tutorEmail]  — the tutor's email (from [TutorGrantDoc.tutorEmail]).
  /// [parentName]  — display name of the parent (from Firebase Auth
  ///                 [User.displayName], falls back to "Parent" if null).
  /// [childName]   — display name of the child profile.
  Future<void> notifyTutorOfRevocation({
    required String tutorEmail,
    required String parentName,
    required String childName,
  }) => _email.send(
    TutorGrantRevokedEmail(
      toAddress: tutorEmail,
      parentName: parentName,
      childName: childName,
    ),
  );
}
