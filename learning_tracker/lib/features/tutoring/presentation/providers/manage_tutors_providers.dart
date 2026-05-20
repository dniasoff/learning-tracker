// Providers for tutor management screens (W6.11, W6.12).
//
// These are simple Riverpod providers that instantiate the use cases
// from the domain layer. Since TutorGrantRepository has no concrete
// implementation yet (gated on data layer work), we provide a
// stub/in-memory implementation that returns empty lists.
//
// When the Firestore data layer lands, replace _StubTutorGrantRepository
// with the real implementation wired to tutorGrantRepositoryProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';

// ── Stub repository ──────────────────────────────────────────────────────────

/// Stub implementation used until the Firestore data layer lands.
///
/// TODO(data-layer): Replace with the real Firestore-backed implementation.
/// The real provider should read from the Firestore `tutor_grants` collection
/// using the composite indexes added in W3.39.
class _StubTutorGrantRepository implements TutorGrantRepository {
  const _StubTutorGrantRepository();

  @override
  Future<TutorGrantResult> inviteTutor({
    required String tutorEmail,
    required String childProfileId,
    required TutorPermissions permissions,
  }) async => const TutorGrantFailure(
    message: 'Not yet implemented — data layer pending',
  );

  @override
  Future<TutorGrantResult> acceptInvite({required String grantId}) async =>
      const TutorGrantFailure(
        message: 'Not yet implemented — data layer pending',
      );

  @override
  Future<TutorGrantResult> declineInvite({required String grantId}) async =>
      const TutorGrantFailure(
        message: 'Not yet implemented — data layer pending',
      );

  @override
  Future<TutorGrantResult> rescindInvite({required String grantId}) async =>
      const TutorGrantFailure(
        message: 'Not yet implemented — data layer pending',
      );

  @override
  Future<TutorGrantResult> revokeGrant({required String grantId}) async =>
      const TutorGrantFailure(
        message: 'Not yet implemented — data layer pending',
      );

  @override
  Future<TutorGrantResult> resignGrant({required String grantId}) async =>
      const TutorGrantFailure(
        message: 'Not yet implemented — data layer pending',
      );

  @override
  Future<List<TutorGrant>> listIncomingGrants() async => const [];

  @override
  Future<List<TutorGrant>> listOutgoingGrants({
    required String childProfileId,
  }) async => const [];
}

// ── Repository provider ──────────────────────────────────────────────────────

/// The TutorGrantRepository instance used by all tutor grant use cases.
///
/// Replace the stub with the real implementation when the data layer lands.
final tutorGrantRepositoryProvider = Provider<TutorGrantRepository>(
  (_) => const _StubTutorGrantRepository(),
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
