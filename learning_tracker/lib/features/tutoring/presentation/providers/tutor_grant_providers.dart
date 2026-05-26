// Tutor grant Riverpod providers — W6.7, W6.9, W6.10, V2-R3 C3
//
// Exposes use-case instances for the tutor invite + grant lifecycle.
// The concrete [FirestoreTutorGrantRepository] delegates all mutations to
// Cloud Functions callables and reads grant lists via the listTutorGrants CF.

import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tutor_grant_providers.g.dart';

// ── Repository provider ──────────────────────────────────────────────────────

@riverpod
TutorGrantRepository tutorGrantRepository(Ref ref) {
  return FirestoreTutorGrantRepository();
}

// ── Use case providers ──────────────────────────────────────────────────────

@riverpod
InviteTutorUseCase inviteTutorUseCase(Ref ref) {
  return InviteTutorUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

@riverpod
AcceptTutorInviteUseCase acceptTutorInviteUseCase(Ref ref) {
  return AcceptTutorInviteUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

@riverpod
DeclineTutorInviteUseCase declineTutorInviteUseCase(Ref ref) {
  return DeclineTutorInviteUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

@riverpod
RevokeTutorGrantUseCase revokeTutorGrantUseCase(Ref ref) {
  return RevokeTutorGrantUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

@riverpod
ResignTutorGrantUseCase resignTutorGrantUseCase(Ref ref) {
  return ResignTutorGrantUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

/// Lists active/pending grants where the current user is the tutor.
@riverpod
Future<List<TutorGrant>> incomingTutorGrants(Ref ref) {
  final repo = ref.watch(tutorGrantRepositoryProvider);
  return repo.listIncomingGrants();
}

/// Lists PENDING invites addressed to the current user's email so a tutor can
/// discover + accept them in-app — without the emailed deep link and without
/// being forced to create a learner profile first.
@riverpod
Future<List<TutorGrant>> pendingTutorInvites(Ref ref) {
  final repo = ref.watch(tutorGrantRepositoryProvider);
  return repo.listPendingInvitesForMe();
}

// ── S4 — Tutor write-path service provider ────────────────────────────────────

/// Provides the [TutorWriteService] that routes permitted tutor edits to the
/// S4 Cloud Functions (Admin SDK write proxy to the parent's namespace).
///
/// Use when `activeTutoredProfileSelectionProvider != null` to route an edit
/// through the CF instead of the local outbox.
@riverpod
TutorWriteService tutorWriteService(Ref ref) {
  return TutorWriteService();
}
