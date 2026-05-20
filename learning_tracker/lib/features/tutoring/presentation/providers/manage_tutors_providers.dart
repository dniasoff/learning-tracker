// Providers for tutor management screens (W6.11, W6.12, V2-R3 C3).
//
// Uses the real [FirestoreTutorGrantRepository] backed by Cloud Functions
// callables. All mutations are server-side via Admin SDK (V2-R3 C3).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';

// ── Repository provider ──────────────────────────────────────────────────────

/// The TutorGrantRepository instance used by all tutor grant use cases.
///
/// Backed by [FirestoreTutorGrantRepository] (V2-R3 C3).
final tutorGrantRepositoryProvider = Provider<TutorGrantRepository>(
  (_) => FirestoreTutorGrantRepository(),
);

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
  final useCase = ref.watch(listIncomingGrantsUseCaseProvider);
  return useCase();
});
