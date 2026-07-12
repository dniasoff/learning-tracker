// TransactionalEmailService — W6.8
//
// Abstraction for sending transactional emails (tutor invite, invite accepted,
// grant revoked, etc.). Implemented against this interface so the concrete
// provider (Firebase Extensions / SendGrid / any SMTP relay) can be swapped
// without changing callers.
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  INFRASTRUCTURE WAKE-UP NOTICE                                          │
// │                                                                         │
// │  No transactional email service is currently provisioned for the        │
// │  `torah-study-tracker` Firebase project.                                │
// │                                                                         │
// │  The [LoggingTransactionalEmailService] (the default implementation) is │
// │  wired in production. It prints every email payload to the app log so   │
// │  you can verify the call paths work, but NO EMAIL IS SENT.              │
// │                                                                         │
// │  To activate real email delivery, provision one of:                     │
// │    (A) Firebase Extension — "Trigger Email from Firestore"              │
// │        (https://extensions.dev/extensions/firebase/firestore-send-email)│
// │    (B) SendGrid — add SENDGRID_API_KEY to Cloud Function env vars and   │
// │        swap in SendGridTransactionalEmailService (not yet implemented).  │
// │    (C) Any SMTP relay — implement TransactionalEmailService and bind it  │
// │        in the Riverpod provider below.                                   │
// │                                                                         │
// │  GATE (AUD-core-email-02 / DNI-400): subject/body below are hardcoded   │
// │  English string literals, not ARB keys — `make arb-parity` cannot catch │
// │  them. Localize via lookupAppLocalizations(recipient locale) and add    │
// │  ARB keys to app_en.arb/app_he.arb before activating a real provider.   │
// │  Tracked by DNI-400 (see TransactionalEmail.subject/plaintextBody).     │
// │                                                                         │
// │  Once a provider is provisioned, delete the wake-up comment and swap    │
// │  [LoggingTransactionalEmailService] for the real implementation.        │
// └─────────────────────────────────────────────────────────────────────────┘

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transactional_email_service.g.dart';

// ── Email payload types ─────────────────────────────────────────────────────

/// A typed transactional email payload.
sealed class TransactionalEmail {
  const TransactionalEmail({required this.toAddress});

  /// Recipient email address.
  final String toAddress;

  /// Subject line.
  ///
  /// Currently hardcoded English — not yet routed through ARB/
  /// AppLocalizations. See the GATE paragraph in the WAKE-UP NOTICE above.
  // TODO(DNI-400): localize via lookupAppLocalizations(recipient locale) +
  // ARB keys before a real email provider is wired (AUD-core-email-02).
  String get subject;

  /// Plaintext body fallback (for email clients that do not render HTML).
  ///
  /// Currently hardcoded English — not yet routed through ARB/
  /// AppLocalizations. See the GATE paragraph in the WAKE-UP NOTICE above.
  // TODO(DNI-400): localize via lookupAppLocalizations(recipient locale) +
  // ARB keys before a real email provider is wired (AUD-core-email-02).
  String get plaintextBody;
}

/// Sent to a tutor when the parent issues an invite.
final class TutorInviteEmail extends TransactionalEmail {
  const TutorInviteEmail({
    required super.toAddress,
    required this.parentName,
    required this.childName,
    required this.inviteDeepLink,
    required this.expiresAt,
  });

  final String parentName;
  final String childName;
  final String inviteDeepLink;
  final DateTime expiresAt;

  @override
  String get subject =>
      '$parentName invited you to tutor $childName on Learning Tracker';

  @override
  String get plaintextBody =>
      '$parentName has invited you to become a tutor for $childName.\n\n'
      'Accept or decline here: $inviteDeepLink\n\n'
      'This invitation expires on ${expiresAt.toLocal().toIso8601String()}.';
}

/// Sent to the parent when a tutor accepts an invite.
final class TutorAcceptedEmail extends TransactionalEmail {
  const TutorAcceptedEmail({
    required super.toAddress,
    required this.tutorName,
    required this.childName,
  });

  final String tutorName;
  final String childName;

  @override
  String get subject => '$tutorName accepted your tutor invite for $childName';

  @override
  String get plaintextBody =>
      '$tutorName has accepted your invitation to tutor $childName.\n\n'
      'They now have access to view and manage $childName\'s learning progress.';
}

/// Sent to the parent when a tutor declines an invite.
final class TutorDeclinedEmail extends TransactionalEmail {
  const TutorDeclinedEmail({
    required super.toAddress,
    required this.tutorEmail,
    required this.childName,
  });

  final String tutorEmail;
  final String childName;

  @override
  String get subject => 'Tutor invite for $childName was declined';

  @override
  String get plaintextBody =>
      '$tutorEmail has declined your invitation to tutor $childName.\n\n'
      'You can send a new invitation from the Manage Tutors screen.';
}

/// Sent to the tutor when the parent revokes an active grant.
final class TutorGrantRevokedEmail extends TransactionalEmail {
  const TutorGrantRevokedEmail({
    required super.toAddress,
    required this.parentName,
    required this.childName,
  });

  final String parentName;
  final String childName;

  @override
  String get subject => 'Your tutor access for $childName has been revoked';

  @override
  String get plaintextBody =>
      '$parentName has revoked your tutor access for $childName.\n\n'
      'You can no longer view or manage $childName\'s learning progress.';
}

/// Sent to the parent when a tutor resigns.
final class TutorResignedEmail extends TransactionalEmail {
  const TutorResignedEmail({
    required super.toAddress,
    required this.tutorName,
    required this.childName,
  });

  final String tutorName;
  final String childName;

  @override
  String get subject => '$tutorName has resigned as tutor for $childName';

  @override
  String get plaintextBody =>
      '$tutorName has stepped down as tutor for $childName.\n\n'
      'Their access has been removed. You can invite a new tutor from the '
      'Manage Tutors screen.';
}

// ── Service abstraction ─────────────────────────────────────────────────────

/// Abstract service for sending transactional emails.
///
/// Implementations:
///   [LoggingTransactionalEmailService] — current default; logs but does NOT
///     send. Active until a real email provider is provisioned.
abstract interface class TransactionalEmailService {
  /// Send [email] and return when the delivery attempt completes.
  ///
  /// Implementations MUST NOT throw — they should handle delivery failures
  /// internally (log + fire-and-forget or enqueue for retry). The caller
  /// cannot reasonably recover from an email delivery failure.
  Future<void> send(TransactionalEmail email);
}

// ── Logging fallback implementation ─────────────────────────────────────────

/// Fallback implementation that logs every email to [AppLogger] but does NOT
/// send any actual email.
///
/// This is active in production until a real email provider is provisioned.
/// See the INFRASTRUCTURE WAKE-UP NOTICE at the top of this file.
class LoggingTransactionalEmailService implements TransactionalEmailService {
  const LoggingTransactionalEmailService();

  @override
  Future<void> send(TransactionalEmail email) async {
    // WAKE-UP NOTICE: No email provider is configured. The payload below
    // would be delivered if a real TransactionalEmailService were bound.
    // See core/email/transactional_email_service.dart for instructions.
    AppLogger.instance.warning(
      event: '[TransactionalEmail] NO PROVIDER CONFIGURED — email NOT sent.',
      fields: {'to': email.toAddress, 'subject': email.subject},
    );
    AppLogger.instance.debug(
      event: '[TransactionalEmail] Payload',
      fields: {'body': email.plaintextBody},
    );
  }
}

// ── Riverpod provider ───────────────────────────────────────────────────────

/// Provider for the transactional email service.
///
/// Swap this binding once a real email provider is provisioned:
///   return SendGridTransactionalEmailService(apiKey: env.sendgridApiKey);
///   return FirestoreEmailExtensionService(firestore: ref.watch(...));
@riverpod
TransactionalEmailService transactionalEmailService(Ref ref) {
  // WAKE-UP: Replace with a real implementation when email is provisioned.
  return const LoggingTransactionalEmailService();
}
