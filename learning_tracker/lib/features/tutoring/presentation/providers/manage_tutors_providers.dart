// Providers for tutor management screens (W6.11, W6.12, V2-R3 C3).
//
// Uses the real [FirestoreTutorGrantRepository] backed by Cloud Functions
// callables. All mutations are server-side via Admin SDK (V2-R3 C3).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/email/transactional_email_service.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show currentAccountIdProvider;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
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
///
/// OFFLINE-FIRST: the canonical source is the `listTutorGrants` Cloud Function,
/// but that is network-only and returns `[]` when offline. A returning tutor
/// must still see the talmidim they have already entered, so when the CF yields
/// nothing AND the device is offline we reconstruct the ACTIVE grants from the
/// locally-mirrored tutored profiles (Drift). When online, the CF result is
/// authoritative (it carries real permissions, denormalised names, and the
/// true grant state) and reconciles the optimistic local view.
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
  // Resolve provider dependencies synchronously (before any await) so Riverpod
  // tracks them correctly.
  final accountId = ref.watch(currentAccountIdProvider);
  final db = ref.watch(userDatabaseProvider);

  final cfGrants = await useCase();

  // OFFLINE-FIRST: always union the CF result with the locally-mirrored active
  // talmidim. The CF is network-only and returns [] whenever it can't reach the
  // server — and `connectivity.isOnline` is unreliable on some networks (e.g. a
  // VPN interface is "up" while DNS to Firestore fails), so we do NOT gate on
  // it. The CF result is authoritative for any grant it returns (real state +
  // permissions + denormalised names); the mirror only fills in active talmidim
  // the CF did not return, so a cached talmid is never hidden by a transient or
  // offline CF failure. A revoked grant's mirror is wiped on revoke, so it does
  // not resurrect here.
  final cfGrantIds = cfGrants.map((g) => g.grantId).toSet();
  final mirrors = await db.profileDao.getTutoredMirrorsForAccount(accountId);
  final fromMirror = mirrors
      .where(
        (m) =>
            m.tutorGrantId != null &&
            m.tutorParentUid != null &&
            m.tutorRemoteProfileId != null &&
            !cfGrantIds.contains(m.tutorGrantId),
      )
      .map(_reconstructActiveGrantFromMirror);
  return [...cfGrants, ...fromMirror];
});

/// Reconstruct an ACTIVE [TutorGrant] from a locally-mirrored tutored profile
/// row so the tutor can see and re-enter the talmid while offline. Permissions
/// are not persisted on the mirror, so we use the optimistic defaults; the next
/// online CF refresh replaces this with the authoritative grant.
TutorGrant _reconstructActiveGrantFromMirror(LearnerProfile m) {
  final doc = TutorGrantDoc(
    grantId: m.tutorGrantId!,
    parentUid: m.tutorParentUid!,
    childProfileId: m.tutorRemoteProfileId!,
    tutorEmail: '',
    state: TutorGrantState.active,
    invitedAt: m.createdAt,
    updatedAt: m.updatedAt,
    acceptedAt: m.createdAt,
    childName: m.displayName,
  );
  return TutorGrant.fromDoc(doc, permissions: TutorPermissions.defaults());
}

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
