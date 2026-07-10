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
// TutorGrantRepository resolves from domain/repositories/tutor_grant_repository.dart
// (AUD-tutoring-10) via the export in tutor_invite_use_cases.dart below — a
// direct import here is flagged `unnecessary_import` by the analyzer since
// InviteTutorUseCase etc. from that same import already pull it in.
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

/// Lists PENDING invites addressed to the current user's email so a tutor can
/// discover + accept them in-app — without the emailed deep link and without
/// being forced to create a learner profile first.
@riverpod
Future<List<TutorGrant>> pendingTutorInvites(Ref ref) {
  final repo = ref.watch(tutorGrantRepositoryProvider);
  return repo.listPendingInvitesForMe();
}

// AUD-tutoring-03: there is intentionally NO `incomingTutorGrants` provider
// in this file. A network-only @riverpod codegen version used to live here
// alongside the offline-first `incomingTutorGrantsProvider` in
// manage_tutors_providers.dart — two top-level providers with the identical
// name (AG-4 violation), forcing every consumer that needed both files to
// `show`/`hide`/alias-import around the collision. The offline-first one in
// manage_tutors_providers.dart (reconciles the CF result against the locally
// mirrored tutored profiles — see D18) is the one every tutoring/profile
// screen actually watches; it is canonical. Do not reintroduce a duplicate
// here — add new incoming-grants logic to manage_tutors_providers.dart.

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
