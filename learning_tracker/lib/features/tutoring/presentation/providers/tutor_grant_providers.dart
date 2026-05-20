// Tutor grant Riverpod providers — W6.7, W6.9, W6.10, V2-R3 C3
//
// Exposes use-case instances for the tutor invite + grant lifecycle.
// The concrete [FirestoreTutorGrantRepository] delegates all mutations to
// Cloud Functions callables and reads grant lists via the listTutorGrants CF.

import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart';
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
