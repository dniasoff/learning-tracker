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
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
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
/// Parameterised by [childProfileId].
///
/// autoDispose: evicted from cache when the ManageTutors screen is
/// unmounted (no active subscriber). On re-entry the provider re-runs its
/// future and calls the listTutorGrants CF again — so the parent always
/// sees the current grant state rather than a stale cached result from a
/// previous visit (DG-TUT-STALE-01: tutor acceptance not reflected on parent).
final outgoingTutorGrantsProvider = FutureProvider.autoDispose
    .family<List<TutorGrant>, String>((ref, childProfileId) {
      final useCase = ref.watch(listOutgoingGrantsUseCaseProvider);
      return useCase(childProfileId: childProfileId);
    });

/// List of incoming grants for the current tutor (tutor view).
///
/// Returns all grants where the caller is the tutor (active + pending).
///
/// The canonical source is the `listTutorGrants` Cloud Function. There is no
/// local tutored-profile mirror to reconstruct from during the Firestore
/// migration.
final incomingTutorGrantsProvider = FutureProvider<List<TutorGrant>>((
  ref,
) async {
  // Re-resolve when the active login changes. Incoming grants are scoped to
  // the signed-in tutor; this keepAlive cache must not survive an account
  // switch, otherwise the previous account's talmidim leak through (e.g. a
  // parent who is not a tutor would see the prior tutor account's talmid).
  // Keyed on Firebase uid because the per-account DB `accounts.id` collides.
  ref.watch(authStateProvider.select((s) => s.currentUser?.firebaseUid));
  final useCase = ref.watch(listIncomingGrantsUseCaseProvider);
  // D18: distinguish an authoritative online success from an offline/transient
  // failure. `listTutorGrants` returns only active/pending grants, so a grant
  // revoked by the parent is ABSENT from a successful result.
  final cfResult = await useCase.callWithStatus();
  final cfGrants = cfResult.grants;
  final cfGrantIds = cfGrants.map((g) => g.grantId).toSet();

  if (cfResult.ok) {
    // Authoritative: if the currently open grant is no longer active/pending,
    // leave the tutored session immediately.
    final activeGrantId = ref
        .read(activeTutoredProfileSelectionProvider)
        ?.grantId;
    if (activeGrantId != null && !cfGrantIds.contains(activeGrantId)) {
      ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
    }
    return cfGrants;
  }

  // On CF failure return its (possibly empty) result. Firestore's own offline
  // persistence may still provide cached data, but there is no local mirror
  // union fallback during this migration.
  return cfGrants;
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
