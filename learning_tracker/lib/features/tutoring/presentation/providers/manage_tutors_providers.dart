// Providers for tutor management screens (W6.11, W6.12, V2-R3 C3).
//
// Uses the real [FirestoreTutorGrantRepository] backed by Cloud Functions
// callables. All mutations are server-side via Admin SDK (V2-R3 C3).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/email/transactional_email_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_notification_service.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';

// ── Repository provider ──────────────────────────────────────────────────────
//
// WS3.3h: The duplicate `tutorGrantRepositoryProvider` that previously existed
// here (a manual Provider<TutorGrantRepository>) has been removed. The canonical
// provider is now the @riverpod-generated `tutorGrantRepositoryProvider` in
// `tutor_grant_providers.dart`. All use cases in this file now use that one.

// ── Use case providers ───────────────────────────────────────────────────────

final revokeTutorGrantUseCaseProvider = Provider<RevokeTutorGrantUseCase>(
  (ref) => RevokeTutorGrantUseCase(ref.watch(tutorGrantRepositoryProvider)),
);

final rescindTutorInviteUseCaseProvider = Provider<RescindTutorInviteUseCase>(
  (ref) => RescindTutorInviteUseCase(ref.watch(tutorGrantRepositoryProvider)),
);

final resignTutorGrantUseCaseProvider = Provider<ResignTutorGrantUseCase>(
  (ref) => ResignTutorGrantUseCase(ref.watch(tutorGrantRepositoryProvider)),
);

final listOutgoingGrantsUseCaseProvider =
    Provider<ListOutgoingTutorGrantsUseCase>(
      (ref) => ListOutgoingTutorGrantsUseCase(
        ref.watch(tutorGrantRepositoryProvider),
      ),
    );

final listIncomingGrantsUseCaseProvider =
    Provider<ListIncomingTutorAccessUseCase>(
      (ref) => ListIncomingTutorAccessUseCase(
        ref.watch(tutorGrantRepositoryProvider),
      ),
    );

// ── Async data providers ─────────────────────────────────────────────────────

/// List of outgoing grants for a specific child profile (parent view).
///
/// Parameterised by [childProfileId]. Cached until invalidated.
final outgoingTutorGrantsProvider =
    FutureProvider.family<List<TutorGrant>, String>((ref, childProfileId) {
      final useCase = ref.watch(listOutgoingGrantsUseCaseProvider);
      return useCase(childProfileId: childProfileId);
    });

/// List of incoming grants for the current tutor (tutor view).
///
/// Returns all grants where the caller is the tutor (active + pending).
final incomingTutorGrantsProvider = FutureProvider<List<TutorGrant>>((ref) {
  // Re-resolve when the active login changes. Incoming grants are scoped to
  // the signed-in tutor; this keepAlive cache must not survive an account
  // switch, otherwise the previous account's talmidim leak through (e.g. a
  // parent who is not a tutor would see the prior tutor account's talmid).
  // Keyed on Firebase uid because the per-account DB `accounts.id` collides.
  ref.watch(authStateProvider.select((s) => s.currentUser?.firebaseUid));
  final useCase = ref.watch(listIncomingGrantsUseCaseProvider);
  return useCase();
});

// ── Notification gateway ──────────────────────────────────────────────────────

/// WS3.3g: Provider for [TutorNotificationGateway].
///
/// Fire-and-forget lifecycle notifications for:
///   • Tutor declines invite → parent notified ([notifyParentOfDecline])
///   • Tutor resigns grant   → parent notified ([notifyParentOfResignation])
///   • Parent revokes grant  → tutor notified ([notifyTutorOfRevocation])
///
/// Backed by [transactionalEmailServiceProvider] (currently LoggingTransactionalEmailService
/// — no real email sent until an email provider is provisioned).
final tutorNotificationGatewayProvider = Provider<TutorNotificationGateway>(
  (ref) =>
      TutorNotificationGateway(ref.watch(transactionalEmailServiceProvider)),
);
